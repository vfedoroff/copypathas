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

    @Test func storesAndRetrievesFeedbackPreferences() {
        let store = SharedPreferenceStore.shared
        
        let initialSound = store.object(forKey: "soundFeedbackEnabled") as? Bool
        let initialNotification = store.object(forKey: "notificationFeedbackEnabled") as? Bool
        let initialHaptic = store.object(forKey: "hapticFeedbackEnabled") as? Bool

        store.set(true, forKey: "soundFeedbackEnabled")
        store.set(false, forKey: "notificationFeedbackEnabled")
        store.set(true, forKey: "hapticFeedbackEnabled")

        #expect(store.object(forKey: "soundFeedbackEnabled") as? Bool == true)
        #expect(store.object(forKey: "notificationFeedbackEnabled") as? Bool == false)
        #expect(store.object(forKey: "hapticFeedbackEnabled") as? Bool == true)

        // Restore initial values
        store.set(initialSound, forKey: "soundFeedbackEnabled")
        store.set(initialNotification, forKey: "notificationFeedbackEnabled")
        store.set(initialHaptic, forKey: "hapticFeedbackEnabled")
    }
}
