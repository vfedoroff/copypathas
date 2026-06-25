import SwiftUI

@main
struct CopyPathAs: App {
    @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            SettingsView(demoState: .current)
        }
        .windowResizability(.contentSize)
    }
}
