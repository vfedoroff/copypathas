import AppKit
import FinderSync
import Foundation
import OSLog

protocol MountedVolumeProviding: AnyObject {
    func mountedVolumeURLs() -> [URL]?
}

protocol MonitoredDirectoryApplying: AnyObject {
    func replaceMonitoredDirectories(with urls: Set<URL>)
}

final class FileManagerMountedVolumeProvider: MountedVolumeProviding {
    func mountedVolumeURLs() -> [URL]? {
        FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: nil,
            options: [.skipHiddenVolumes]
        )
    }
}

final class FinderSyncDirectoryApplier: MonitoredDirectoryApplying {
    func replaceMonitoredDirectories(with urls: Set<URL>) {
        FIFinderSyncController.default().directoryURLs = urls
    }
}

final class MonitoredDirectoryRegistry: NSObject {
    private let volumeProvider: MountedVolumeProviding
    private let applier: MonitoredDirectoryApplying
    private let logger: Logger
    private weak var notificationCenter: NotificationCenter?

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

    func startObserving(_ center: NotificationCenter) {
        notificationCenter?.removeObserver(self)
        notificationCenter = center
        center.addObserver(
            self,
            selector: #selector(volumeConfigurationDidChange(_:)),
            name: NSWorkspace.didMountNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(volumeConfigurationDidChange(_:)),
            name: NSWorkspace.didUnmountNotification,
            object: nil
        )
        refresh()
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

    @objc private func volumeConfigurationDidChange(_ notification: Notification) {
        logger.info("Volume configuration changed; refreshing monitored directories")
        refresh()
    }

    deinit {
        notificationCenter?.removeObserver(self)
    }
}
