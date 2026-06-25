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
}
