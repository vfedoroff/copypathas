import AppKit
import Foundation

struct AppInstallationWarning: Equatable {
    let title: String
    let detail: String
}

struct AppInstallationStatus {
    static let preferredAppPath = "/Applications/CopyPathAs.app"
    static let demoHealthy = AppInstallationStatus(
        currentAppURL: URL(fileURLWithPath: preferredAppPath),
        runningAppURLs: [URL(fileURLWithPath: preferredAppPath)],
        runningExtensionURL: nil
    )

    let currentAppURL: URL
    let runningAppURLs: [URL]
    let runningExtensionURL: URL?

    var warning: AppInstallationWarning? {
        if !isInstalledInApplications {
            return AppInstallationWarning(
                title: "Install Copy Path As in Applications",
                detail: "Finder extensions are most reliable when the app is installed at /Applications/CopyPathAs.app. Reinstall with Homebrew Cask or move the app there."
            )
        }

        if !duplicateAppURLs.isEmpty {
            return AppInstallationWarning(
                title: "Multiple Copy Path As apps found",
                detail: "Remove older copies from Downloads, Desktop, or other folders, then restart Finder so macOS uses the Homebrew Cask installation."
            )
        }

        return nil
    }

    var isInstalledInApplications: Bool {
        normalizedPath(currentAppURL) == Self.preferredAppPath
    }

    var duplicateAppURLs: [URL] {
        let currentPath = normalizedPath(currentAppURL)
        var duplicates: [URL] = []
        var seenPaths: Set<String> = []

        // 1. Check running apps
        for appURL in runningAppURLs {
            let path = normalizedPath(appURL)
            if path != currentPath && isUserInstalledAppCopy(path) {
                if seenPaths.insert(path).inserted {
                    duplicates.append(appURL)
                }
            }
        }

        // 2. Check running extension's containing app
        if let extensionURL = runningExtensionURL {
            let containingAppURL = extensionURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            let path = normalizedPath(containingAppURL)
            if path != currentPath && isUserInstalledAppCopy(path) {
                if seenPaths.insert(path).inserted {
                    duplicates.append(containingAppURL)
                }
            }
        }

        return duplicates
    }

    private func normalizedPath(_ url: URL) -> String {
        url.standardizedFileURL.path
    }

    private func isUserInstalledAppCopy(_ path: String) -> Bool {
        if path.contains("/DerivedData/") && path.contains("/Build/Products/") {
            return false
        }

        if path.contains(".xcarchive/Products/Applications/") {
            return false
        }

        if path.contains("/build/signed-export/") {
            return false
        }

        return true
    }
}

protocol AppInstallationStatusProviding {
    func currentStatus() -> AppInstallationStatus
}

struct WorkspaceAppInstallationStatusProvider: AppInstallationStatusProviding {
    let bundleIdentifier: String
    let currentAppURL: URL

    init(
        bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "com.vfedoroff.CopyPathAs",
        currentAppURL: URL = Bundle.main.bundleURL
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.currentAppURL = currentAppURL
    }

    func currentStatus() -> AppInstallationStatus {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .compactMap { $0.bundleURL }

        let runningExtensionPath = FinderExtensionManager.readExtensionPreference(forKey: "extensionBundlePath") as? String
        let runningExtensionURL = FinderExtensionManager.isRecentlyActive && runningExtensionPath != nil
            ? URL(fileURLWithPath: runningExtensionPath!)
            : nil

        return AppInstallationStatus(
            currentAppURL: currentAppURL,
            runningAppURLs: runningApps,
            runningExtensionURL: runningExtensionURL
        )
    }
}
