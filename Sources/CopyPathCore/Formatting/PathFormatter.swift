import Foundation

public struct PathFormatter: PathFormatting, Sendable {
    public init() {}

    public func format(_ urls: [URL], as format: PathFormat) -> String {
        let paths = urls.map { $0.path(percentEncoded: false) }

        switch format {
        case .path:
            return paths.joined(separator: "\n")
        case .quotedPath:
            return paths.map(quoted).joined(separator: "\n")
        case .shellEscapedPath:
            return paths.map(shellEscaped).joined(separator: "\n")
        case .fileURL:
            return urls.map(\.absoluteString).joined(separator: "\n")
        case .filename:
            return urls.map(\.lastPathComponent).joined(separator: "\n")
        case .filenameWithoutExtension:
            return urls.map { $0.deletingPathExtension().lastPathComponent }.joined(separator: "\n")
        case .parentFolder:
            return urls.map { $0.deletingLastPathComponent().path }.joined(separator: "\n")
        case .jsonArray:
            return json(paths)
        case .markdownLink:
            return urls.map(markdownLink).joined(separator: "\n")
        }
    }

    private func quoted(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(escaped)\""
    }

    private func shellEscaped(_ value: String) -> String {
        if value.contains("\n") || value.contains("\r") {
            return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
        }

        let safeASCII = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-./:")
        return value.unicodeScalars.map { scalar in
            if safeASCII.contains(scalar) || (scalar.value > 127 && CharacterSet.alphanumerics.contains(scalar)) {
                return String(scalar)
            }
            return "\\" + String(scalar)
        }.joined()
    }

    private func json(_ paths: [String]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(paths), let value = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return value
    }

    private func markdownLink(_ url: URL) -> String {
        let text = url.lastPathComponent
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
        let destination = url.absoluteString
            .replacingOccurrences(of: "(", with: "%28")
            .replacingOccurrences(of: ")", with: "%29")
        return "[\(text)](\(destination))"
    }
}
