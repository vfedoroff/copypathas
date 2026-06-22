import FinderSync
import Foundation
import OSLog

@MainActor
protocol MountedVolumeProviding: AnyObject {
    func mountedVolumeURLs() -> [URL]?
}

@MainActor
protocol MonitoredDirectoryApplying: AnyObject {
    func replaceMonitoredDirectories(with urls: Set<URL>)
}

@MainActor
final class FileManagerMountedVolumeProvider: MountedVolumeProviding {
    func mountedVolumeURLs() -> [URL]? {
        FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: nil,
            options: [.skipHiddenVolumes]
        )
    }
}

@MainActor
final class FinderSyncDirectoryApplier: MonitoredDirectoryApplying {
    func replaceMonitoredDirectories(with urls: Set<URL>) {
        FIFinderSyncController.default().directoryURLs = urls
    }
}

@MainActor
final class MonitoredDirectoryRegistry: NSObject {
    private let volumeProvider: MountedVolumeProviding
    private let applier: MonitoredDirectoryApplying
    private let logger: Logger

    init(
        volumeProvider: MountedVolumeProviding = FileManagerMountedVolumeProvider(),
        applier: MonitoredDirectoryApplying = FinderSyncDirectoryApplier(),
        logger: Logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "com.vfedoroff.CopyPathAs.FinderExtension",
            category: "lifecycle"
        )
    ) {
        self.volumeProvider = volumeProvider
        self.applier = applier
        self.logger = logger
    }

    func refresh() {
        var urls: Set<URL> = [URL(fileURLWithPath: "/", isDirectory: true)]
        if let mountedURLs = volumeProvider.mountedVolumeURLs() {
            urls.formUnion(mountedURLs)
        } else {
            logger.error("Mounted volume enumeration failed; monitoring root only")
        }

        applier.replaceMonitoredDirectories(with: urls)
        logger.info("Refreshed monitored directories; root count: \(urls.count, privacy: .public)")
    }
}
