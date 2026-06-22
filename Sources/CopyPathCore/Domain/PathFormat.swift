import Foundation

public enum PathFormat: String, CaseIterable, Sendable {
    case path
    case quotedPath
    case shellEscapedPath
    case fileURL
    case filename
    case filenameWithoutExtension
    case parentFolder
    case jsonArray
    case markdownLink

    public var displayName: String {
        switch self {
        case .path: "Path"
        case .quotedPath: "Quoted Path"
        case .shellEscapedPath: "Shell-Escaped Path"
        case .fileURL: "File URL"
        case .filename: "Filename"
        case .filenameWithoutExtension: "Filename Without Extension"
        case .parentFolder: "Parent Folder"
        case .jsonArray: "JSON Array"
        case .markdownLink: "Markdown Link"
        }
    }
}

