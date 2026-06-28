import AppKit
import Testing

@Suite("App lifecycle")
struct AppLifecycleDelegateTests {
    @Test("terminates after the final settings window closes")
    @MainActor
    func terminatesAfterLastWindowCloses() {
        let delegate = AppLifecycleDelegate()

        #expect(delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared))
    }

    @Test("parses valid demo launch arguments")
    func parsesValidDemoLaunchArguments() {
        #expect(AppDemoState.parse(arguments: ["CopyPathAs", "--demo", "overview"]) == .overview)
        #expect(AppDemoState.parse(arguments: ["CopyPathAs", "--demo", "formats"]) == .formats)
        #expect(AppDemoState.parse(arguments: ["CopyPathAs", "--demo", "setup"]) == .setup)
        #expect(AppDemoState.parse(arguments: ["CopyPathAs", "--demo", "copied"]) == .copied)
    }

    @Test("ignores missing and invalid demo launch arguments")
    func ignoresMissingAndInvalidDemoLaunchArguments() {
        #expect(AppDemoState.parse(arguments: ["CopyPathAs"]) == nil)
        #expect(AppDemoState.parse(arguments: ["CopyPathAs", "--demo"]) == nil)
        #expect(AppDemoState.parse(arguments: ["CopyPathAs", "--demo", "unknown"]) == nil)
    }

    @Test("formats version build and source hash for display")
    func formatsBuildIdentity() {
        let identity = BuildIdentity(version: "0.3.0", build: "3", sourceHash: "abc1234")

        #expect(identity.displayString == "Version 0.3.0 · Source abc1234")
    }

    @Test("omits source hash when bundle metadata is missing")
    func omitsMissingSourceHash() {
        let identity = BuildIdentity(version: "0.3.0", build: "3", sourceHash: nil)

        #expect(identity.displayString == "Version 0.3.0")
    }

    @Test("activates an already running app instance")
    func activatesExistingInstance() {
        let provider = RecordingRunningApplicationProvider(
            applications: [
                RunningApplicationInstance(processIdentifier: 111, activate: {}),
                RunningApplicationInstance(processIdentifier: 222, activate: {})
            ]
        )
        let coordinator = AppInstanceCoordinator(
            bundleIdentifier: "com.vfedoroff.CopyPathAs",
            currentProcessIdentifier: 111,
            runningApplicationProvider: provider
        )

        #expect(coordinator.activateExistingInstanceIfNeeded())
        #expect(provider.activatedProcessIdentifiers == [222])
    }

    @Test("continues launch when no other app instance is running")
    func continuesWhenNoOtherInstanceExists() {
        let provider = RecordingRunningApplicationProvider(
            applications: [
                RunningApplicationInstance(processIdentifier: 111, activate: {})
            ]
        )
        let coordinator = AppInstanceCoordinator(
            bundleIdentifier: "com.vfedoroff.CopyPathAs",
            currentProcessIdentifier: 111,
            runningApplicationProvider: provider
        )

        #expect(!coordinator.activateExistingInstanceIfNeeded())
        #expect(provider.activatedProcessIdentifiers.isEmpty)
    }

    @Test("skips duplicate launch guard for XCTest launched app processes")
    func skipsDuplicateGuardDuringUITests() {
        #expect(
            AppLifecycleDelegate.shouldBypassDuplicateLaunchGuard(
                environment: ["XCTestConfigurationFilePath": "/tmp/ui-test.xctestconfiguration"]
            )
        )
        #expect(!AppLifecycleDelegate.shouldBypassDuplicateLaunchGuard(environment: [:]))
    }

    @Test("reports healthy installation from Applications with no duplicates")
    func reportsHealthyInstallation() {
        let status = AppInstallationStatus(
            currentAppURL: URL(fileURLWithPath: "/Applications/CopyPathAs.app"),
            runningAppURLs: [
                URL(fileURLWithPath: "/Applications/CopyPathAs.app")
            ],
            runningExtensionURL: nil
        )

        #expect(status.warning == nil)
    }

    @Test("warns when app is launched outside Applications")
    func warnsForUnstableInstallLocation() {
        let status = AppInstallationStatus(
            currentAppURL: URL(fileURLWithPath: "/Users/me/Downloads/CopyPathAs.app"),
            runningAppURLs: [
                URL(fileURLWithPath: "/Users/me/Downloads/CopyPathAs.app")
            ],
            runningExtensionURL: nil
        )

        #expect(status.warning?.title == "Install Copy Path As in Applications")
    }

    @Test("warns when duplicate app is running")
    func warnsForDuplicateRunningApplications() {
        let status = AppInstallationStatus(
            currentAppURL: URL(fileURLWithPath: "/Applications/CopyPathAs.app"),
            runningAppURLs: [
                URL(fileURLWithPath: "/Applications/CopyPathAs.app"),
                URL(fileURLWithPath: "/Users/me/Downloads/CopyPathAs.app")
            ],
            runningExtensionURL: nil
        )

        #expect(status.warning?.title == "Multiple Copy Path As apps found")
    }

    @Test("warns when duplicate extension is running")
    func warnsForDuplicateRunningExtension() {
        let status = AppInstallationStatus(
            currentAppURL: URL(fileURLWithPath: "/Applications/CopyPathAs.app"),
            runningAppURLs: [
                URL(fileURLWithPath: "/Applications/CopyPathAs.app")
            ],
            runningExtensionURL: URL(fileURLWithPath: "/Users/me/Downloads/CopyPathAs.app/Contents/PlugIns/CopyPathFinderExtension.appex")
        )

        #expect(status.warning?.title == "Multiple Copy Path As apps found")
    }

    @Test("ignores development build products when checking for duplicate running copies")
    func ignoresDevelopmentBuildProductsForDuplicateWarnings() {
        let status = AppInstallationStatus(
            currentAppURL: URL(fileURLWithPath: "/Applications/CopyPathAs.app"),
            runningAppURLs: [
                URL(fileURLWithPath: "/Applications/CopyPathAs.app"),
                URL(fileURLWithPath: "/Users/me/Library/Developer/Xcode/DerivedData/CopyPath/Build/Products/Debug/CopyPathAs.app"),
                URL(fileURLWithPath: "/Users/me/Projects/copypath/DerivedData/Build/Products/Debug/CopyPathAs.app")
            ],
            runningExtensionURL: URL(fileURLWithPath: "/Users/me/Projects/copypath/build/signed-export/CopyPathAs.app/Contents/PlugIns/CopyPathFinderExtension.appex")
        )

        #expect(status.warning == nil)
        #expect(status.duplicateAppURLs.isEmpty)
    }

    @Test("doctor reports a healthy installation when the app and extension look current")
    func doctorReportsHealthyStatus() {
        let report = AppDoctorReport(
            installationStatus: .demoHealthy,
            extensionRecentlyActive: true
        )

        #expect(report.title == "Doctor checks passed")
        #expect(report.issues.isEmpty)
        #expect(report.recommendedActions.isEmpty)
    }

    @Test("doctor recommends explicit recovery for a stale extension heartbeat")
    func doctorRecommendsExtensionRecovery() {
        let report = AppDoctorReport(
            installationStatus: .demoHealthy,
            extensionRecentlyActive: false
        )

        #expect(report.issues.map(\.title).contains("Finder extension has not checked in"))
        #expect(report.recommendedActions.contains(.openExtensionSettings))
        #expect(report.recommendedActions.contains(.restartFinder))
    }

    @Test("doctor recommends duplicate cleanup when a duplicate copy is running")
    func doctorRecommendsDuplicateCleanup() {
        let status = AppInstallationStatus(
            currentAppURL: URL(fileURLWithPath: "/Applications/CopyPathAs.app"),
            runningAppURLs: [
                URL(fileURLWithPath: "/Applications/CopyPathAs.app"),
                URL(fileURLWithPath: "/Users/me/Downloads/CopyPathAs.app")
            ],
            runningExtensionURL: nil
        )
        let report = AppDoctorReport(
            installationStatus: status,
            extensionRecentlyActive: true
        )

        #expect(report.issues.map(\.title).contains("Multiple Copy Path As apps found"))
        #expect(report.recommendedActions.contains(.revealDuplicateApp))
        #expect(report.recommendedActions.contains(.restartFinder))
    }
}

private final class RecordingRunningApplicationProvider: RunningApplicationProviding {
    private var applications: [RunningApplicationInstance] = []
    private(set) var activatedProcessIdentifiers: [pid_t] = []

    init(applications: [RunningApplicationInstance]) {
        self.applications = applications.map { application in
            RunningApplicationInstance(processIdentifier: application.processIdentifier) { [weak self] in
                self?.activatedProcessIdentifiers.append(application.processIdentifier)
            }
        }
    }

    func runningApplications(withBundleIdentifier bundleIdentifier: String) -> [RunningApplicationInstance] {
        applications
    }
}
