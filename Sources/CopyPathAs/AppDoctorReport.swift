import AppKit
import Foundation

struct AppDoctorIssue: Equatable {
    let title: String
    let detail: String
}

enum AppDoctorAction: CaseIterable {
    case openExtensionSettings
    case restartFinder
    case revealCurrentApp
    case revealDuplicateApp

    var title: String {
        switch self {
        case .openExtensionSettings: "Open Extension Settings"
        case .restartFinder: "Restart Finder"
        case .revealCurrentApp: "Reveal Current App"
        case .revealDuplicateApp: "Reveal Duplicate App"
        }
    }

    var systemImage: String {
        switch self {
        case .openExtensionSettings: "gearshape"
        case .restartFinder: "arrow.clockwise"
        case .revealCurrentApp: "app.badge"
        case .revealDuplicateApp: "doc.on.doc"
        }
    }
}

struct AppDoctorReport {
    let installationStatus: AppInstallationStatus
    let extensionRecentlyActive: Bool

    var title: String {
        issues.isEmpty ? "Doctor checks passed" : "Doctor found issues"
    }

    var summary: String {
        if issues.isEmpty {
            return "The app location, duplicate registration check, and Finder extension heartbeat look healthy."
        }

        return "Use the actions below to repair Finder integration after installs, upgrades, or duplicate app copies."
    }

    var issues: [AppDoctorIssue] {
        var issues: [AppDoctorIssue] = []

        if let warning = installationStatus.warning {
            issues.append(AppDoctorIssue(title: warning.title, detail: warning.detail))
        }

        if !extensionRecentlyActive {
            issues.append(
                AppDoctorIssue(
                    title: "Finder extension has not checked in",
                    detail: "If the Finder menu is missing, enable the extension in System Settings or restart Finder."
                )
            )
        }

        return issues
    }

    var recommendedActions: [AppDoctorAction] {
        var actions: [AppDoctorAction] = []

        if !installationStatus.isInstalledInApplications {
            actions.append(.revealCurrentApp)
        }

        if !installationStatus.duplicateAppURLs.isEmpty {
            actions.append(.revealDuplicateApp)
            actions.append(.restartFinder)
        }

        if !extensionRecentlyActive {
            actions.append(.openExtensionSettings)
            actions.append(.restartFinder)
        }

        var seenActions: Set<AppDoctorAction> = []
        return actions.filter { seenActions.insert($0).inserted }
    }
}

protocol AppDoctorActionPerforming {
    @MainActor func openExtensionSettings()
    @MainActor func restartFinder()
    @MainActor func revealCurrentApp(_ url: URL)
    @MainActor func revealDuplicateApp(_ url: URL)
}

struct WorkspaceAppDoctorActionPerformer: AppDoctorActionPerforming {
    @MainActor
    func openExtensionSettings() {
        FinderExtensionManager.showManagementInterface()
    }

    @MainActor
    func restartFinder() {
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder")
            .forEach { $0.terminate() }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory()))
        }
    }

    @MainActor
    func revealCurrentApp(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @MainActor
    func revealDuplicateApp(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
