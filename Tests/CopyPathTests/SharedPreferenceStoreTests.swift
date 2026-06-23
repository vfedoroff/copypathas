import Foundation
import Testing
@testable import CopyPathCore

@Suite("Shared preference store")
struct SharedPreferenceStoreTests {
    @Test func redactsCopiedPathPreviewToFilenameOnly() {
        let url = URL(fileURLWithPath: "/Users/maintainer/Private/Clients/secret.txt")

        let preview = SharedPreferenceStore.copiedPathPreview(for: [url])

        #expect(preview == "secret.txt")
        #expect(!preview.contains("/Users/maintainer"))
        #expect(!preview.contains("Private/Clients"))
    }

    @Test func redactsMultipleCopiedPathPreviewToItemCount() {
        let urls = [
            URL(fileURLWithPath: "/Users/maintainer/Private/a.txt"),
            URL(fileURLWithPath: "/Users/maintainer/Private/b.txt"),
        ]

        #expect(SharedPreferenceStore.copiedPathPreview(for: urls) == "2 items")
    }
}
