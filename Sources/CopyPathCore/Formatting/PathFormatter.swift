import Foundation

public struct PathFormatter: PathFormatting, Sendable {
    public init() {}

    public func format(_ urls: [URL], as format: PathFormat) -> String {
        let paths = urls.map { url in
            var pathString = url.path(percentEncoded: false)
            if pathString.hasSuffix("/") && pathString != "/" {
                pathString.removeLast()
            }
            return pathString
        }

        switch format {
        case .path:
            return paths.joined(separator: "\n")
        case .quotedPath:
            return paths.map(singleQuoted).joined(separator: "\n")
        case .shellEscapedPath:
            return paths.map(shellEscaped).joined(separator: "\n")
        case .homeRelative:
            return paths.map(homeRelative).joined(separator: "\n")
        case .repoRelative:
            return urls.map { url in
                if let gitRoot = findGitRepositoryRoot(for: url) {
                    return relativePath(from: gitRoot, to: url)
                } else {
                    return homeRelative(url.path)
                }
            }.joined(separator: "\n")
        case .fileURL:
            return urls.map(\.absoluteString).joined(separator: "\n")
        case .jsonString:
            return paths.map(jsonString).joined(separator: "\n")
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

    private func singleQuoted(_ value: String) -> String {
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
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

    private func findGitRepositoryRoot(for url: URL) -> URL? {
        var current = url.standardizedFileURL
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: current.path, isDirectory: &isDir) {
            if !isDir.boolValue {
                current = current.deletingLastPathComponent()
            }
        } else {
            current = current.deletingLastPathComponent()
        }

        while current.path != "/" {
            let gitDir = current.appendingPathComponent(".git")
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: gitDir.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return current
            }
            let parent = current.deletingLastPathComponent()
            if parent == current {
                break
            }
            current = parent
        }
        return nil
    }

    private func relativePath(from base: URL, to target: URL) -> String {
        let basePath = base.standardizedFileURL.path
        let targetPath = target.standardizedFileURL.path
        if targetPath == basePath {
            return "."
        } else if targetPath.hasPrefix(basePath + "/") {
            return String(targetPath.dropFirst(basePath.count + 1))
        } else {
            return targetPath
        }
    }

    private func homeRelative(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path == home {
            return "~"
        } else if path.hasPrefix(home + "/") {
            return "~" + path.dropFirst(home.count)
        } else {
            return path
        }
    }

    private func jsonString(_ value: String) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        guard let data = try? encoder.encode(value),
              let result = String(data: data, encoding: .utf8) else {
            return "\"\(value)\""
        }
        return result
    }
}
