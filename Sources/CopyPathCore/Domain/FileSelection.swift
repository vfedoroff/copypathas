import Foundation

public struct FileSelection: Equatable, Sendable {
    public let urls: [URL]

    public init?(_ urls: [URL]) {
        guard !urls.isEmpty else { return nil }
        self.urls = urls
    }
}

