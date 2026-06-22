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
}
