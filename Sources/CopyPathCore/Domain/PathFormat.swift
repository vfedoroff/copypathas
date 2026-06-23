import Foundation

public enum PathFormat: String, CaseIterable, Sendable {
    case path
    case quotedPath
    case shellEscapedPath
    case homeRelative
    case repoRelative
    case fileURL
    case jsonString
    case jsonArray
    case markdownLink
    case filename
    case filenameWithoutExtension
    case parentFolder

    public var displayName: String {
        switch self {
        case .path: "Absolute Path"
        case .quotedPath: "Single Quoted"
        case .shellEscapedPath: "Shell Escaped"
        case .homeRelative: "Home Relative"
        case .repoRelative: "Git Relative"
        case .fileURL: "File URL"
        case .jsonString: "JSON String"
        case .jsonArray: "JSON Array"
        case .markdownLink: "Markdown Link"
        case .filename: "Filename"
        case .filenameWithoutExtension: "Filename Without Extension"
        case .parentFolder: "Parent Folder"
        }
    }

    public var destinationHint: String {
        switch self {
        case .path: "For tools, scripts, and AI agents"
        case .quotedPath: "Safe for Terminal commands"
        case .shellEscapedPath: "For terminal arguments"
        case .homeRelative: "Shorter paths for docs"
        case .repoRelative: "For code review and AI prompts"
        case .fileURL: "For links and automation"
        case .jsonString: "For JSON configurations"
        case .jsonArray: "For multiple selected files"
        case .markdownLink: "For README/docs"
        case .filename: "For single-file naming"
        case .filenameWithoutExtension: "For naming & scripting"
        case .parentFolder: "For enclosing directories"
        }
    }
}
