import AppKit
import Foundation

struct RunningApplicationInstance {
    let processIdentifier: pid_t
    let activate: () -> Void
}

protocol RunningApplicationProviding: AnyObject {
    func runningApplications(withBundleIdentifier bundleIdentifier: String) -> [RunningApplicationInstance]
}

struct AppInstanceCoordinator {
    let bundleIdentifier: String
    let currentProcessIdentifier: pid_t
    let runningApplicationProvider: RunningApplicationProviding

    func activateExistingInstanceIfNeeded() -> Bool {
        guard let existingApplication = runningApplicationProvider
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .first(where: { $0.processIdentifier != currentProcessIdentifier })
        else {
            return false
        }

        existingApplication.activate()
        return true
    }
}

final class AppKitRunningApplicationProvider: RunningApplicationProviding {
    func runningApplications(withBundleIdentifier bundleIdentifier: String) -> [RunningApplicationInstance] {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).map { application in
            RunningApplicationInstance(processIdentifier: application.processIdentifier) {
                application.activate(options: [.activateAllWindows])
            }
        }
    }
}
