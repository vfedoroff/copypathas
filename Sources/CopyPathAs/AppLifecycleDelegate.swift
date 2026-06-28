import AppKit
import CopyPathCore

final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if !Self.shouldBypassDuplicateLaunchGuard(environment: ProcessInfo.processInfo.environment) {
            let instanceCoordinator = AppInstanceCoordinator(
                bundleIdentifier: Bundle.main.bundleIdentifier ?? "com.vfedoroff.CopyPathAs",
                currentProcessIdentifier: ProcessInfo.processInfo.processIdentifier,
                runningApplicationProvider: AppKitRunningApplicationProvider()
            )

            if instanceCoordinator.activateExistingInstanceIfNeeded() {
                NSApp.terminate(nil)
                return
            }
        }

        NSApp.servicesProvider = self
    }

    static func shouldBypassDuplicateLaunchGuard(environment: [String: String]) -> Bool {
        environment["XCTestConfigurationFilePath"] != nil
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @objc func copyPathAsService(_ pboard: NSPasteboard, userData: String, error: NSErrorPointer) {
        guard let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty else {
            return
        }

        let format = PathFormat.path
        let formattedValue = PathFormatter().format(urls, as: format)

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(formattedValue, forType: .string)

        // Write copy confirmation to the extension container plist for dashboard sync
        FinderExtensionManager.writeExtensionPreference(SharedPreferenceStore.copiedPathPreview(for: urls), forKey: "lastCopiedPath")
        FinderExtensionManager.writeExtensionPreference(format.displayName, forKey: "lastCopiedFormat")
        FinderExtensionManager.writeExtensionPreference(Date().timeIntervalSince1970, forKey: "lastCopiedTimestamp")
    }
}
