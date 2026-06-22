import Foundation

public protocol PathFormatting: Sendable {
    func format(_ urls: [URL], as format: PathFormat) -> String
}

