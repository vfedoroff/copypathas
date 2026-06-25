import Foundation

public final class SharedPreferenceStore: Sendable {
    public static let shared = SharedPreferenceStore()

    private init() {}

    public static func copiedPathPreview(for urls: [URL]) -> String {
        if urls.count == 1, let url = urls.first {
            let name = url.lastPathComponent
            return name.isEmpty ? url.deletingLastPathComponent().lastPathComponent : name
        }
        return "\(urls.count) items"
    }

    public var appGroupID: String {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.vfedoroff.CopyPathAs"
        let baseID = bundleID
            .replacingOccurrences(of: ".FinderExtension", with: "")
            .replacingOccurrences(of: ".Core", with: "")
            .replacingOccurrences(of: ".Tests", with: "")
        return "group.\(baseID)"
    }

    private var fallbackPlistName: String {
        return "\(appGroupID).plist"
    }

    // Check if App Group is available
    public var hasAppGroup: Bool {
        // Only use App Group if the process is sandboxed.
        // Unsandboxed processes (like local contributor builds of the host app)
        // should fall back to the plist reader to stay in sync with the extension.
        guard ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil else {
            return false
        }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil
    }

    private var fallbackPlistURL: URL? {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.vfedoroff.CopyPathAs"
        let isExtension = bundleID.hasSuffix(".FinderExtension")
        let extensionBundleID = isExtension ? bundleID : "\(bundleID).FinderExtension"

        if isExtension {
            guard let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else {
                return nil
            }
            return libraryURL.appendingPathComponent("Preferences/\(fallbackPlistName)")
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            return home.appendingPathComponent("Library/Containers/\(extensionBundleID)/Data/Library/Preferences/\(fallbackPlistName)")
        }
    }

    public func set(_ value: Any?, forKey key: String) {
        if hasAppGroup, let defaults = UserDefaults(suiteName: appGroupID) {
            if let value = value {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
            defaults.synchronize()
            return
        }

        guard let plistURL = fallbackPlistURL else { return }

        var plist: [String: Any] = [:]
        if let data = try? Data(contentsOf: plistURL),
           let existingPlist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
            plist = existingPlist
        }

        if let value = value {
            plist[key] = value
        } else {
            plist.removeValue(forKey: key)
        }

        if let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
            try? FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: plistURL)
        }
    }

    public func object(forKey key: String) -> Any? {
        if hasAppGroup, let defaults = UserDefaults(suiteName: appGroupID) {
            return defaults.object(forKey: key)
        }

        guard let plistURL = fallbackPlistURL,
              let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }

        return plist[key]
    }
}
