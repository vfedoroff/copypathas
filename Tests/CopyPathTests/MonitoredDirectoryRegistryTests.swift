import Foundation
import Testing

@Suite("Monitored directory registry")
@MainActor
struct MonitoredDirectoryRegistryTests {
    private let root = URL(fileURLWithPath: "/", isDirectory: true)

    @Test("registers the root and every mounted visible volume")
    func registersCurrentSnapshot() {
        let external = URL(fileURLWithPath: "/Volumes/External", isDirectory: true)
        let provider = FakeMountedVolumeProvider(urls: [external, external])
        let applier = RecordingDirectoryApplier()
        let registry = MonitoredDirectoryRegistry(volumeProvider: provider, applier: applier)

        registry.refresh()

        #expect(applier.snapshots == [[root, external]])
    }

    @Test("falls back to the root when mounted volumes are unavailable")
    func fallsBackToRoot() {
        let applier = RecordingDirectoryApplier()
        let registry = MonitoredDirectoryRegistry(
            volumeProvider: FakeMountedVolumeProvider(urls: nil),
            applier: applier
        )

        registry.refresh()

        #expect(applier.snapshots == [[root]])
    }

    @Test("replaces stale directories on every refresh")
    func replacesSnapshots() {
        let first = URL(fileURLWithPath: "/Volumes/First", isDirectory: true)
        let second = URL(fileURLWithPath: "/Volumes/Second", isDirectory: true)
        let provider = FakeMountedVolumeProvider(urls: [first])
        let applier = RecordingDirectoryApplier()
        let registry = MonitoredDirectoryRegistry(volumeProvider: provider, applier: applier)

        registry.refresh()
        provider.urls = [second]
        registry.refresh()

        #expect(applier.snapshots.last == [root, second])
        #expect(applier.snapshots.last?.contains(first) == false)
    }
}

@MainActor
private final class FakeMountedVolumeProvider: MountedVolumeProviding {
    var urls: [URL]?

    init(urls: [URL]?) {
        self.urls = urls
    }

    func mountedVolumeURLs() -> [URL]? {
        urls
    }
}

@MainActor
private final class RecordingDirectoryApplier: MonitoredDirectoryApplying {
    private(set) var snapshots: [Set<URL>] = []

    func replaceMonitoredDirectories(with urls: Set<URL>) {
        snapshots.append(urls)
    }
}
