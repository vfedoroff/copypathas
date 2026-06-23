import AppKit
import CopyPathCore

final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = self
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
