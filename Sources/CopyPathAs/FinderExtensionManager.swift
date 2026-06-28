import CopyPathCore
import FinderSync
import Foundation

enum FinderExtensionManager {
    static func readExtensionPreference(forKey key: String) -> Any? {
        return SharedPreferenceStore.shared.object(forKey: key)
    }

    static func writeExtensionPreference(_ value: Any, forKey key: String) {
        SharedPreferenceStore.shared.set(value, forKey: key)
    }

    static var isEnabled: Bool {
        isRecentlyActive
    }

    static var isRecentlyActive: Bool {
        if let lastActive = readExtensionPreference(forKey: "extensionLastActiveTimestamp") as? Double {
            let now = Date().timeIntervalSince1970
            // Consider the extension enabled if it was active within the last 10 minutes (600 seconds)
            if now - lastActive < 600 {
                return true
            }
        }

        return false
    }

    static func showManagementInterface() {
        FIFinderSyncController.showExtensionManagementInterface()
    }
}
