# Finder Extension Lifecycle Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Finder extension reconstruct monitored-directory state after login, Finder restarts, process recreation, and volume changes without running the containing app.

**Architecture:** Extract snapshot-based directory registration into `MonitoredDirectoryRegistry`, backed by narrow volume-provider and Finder-controller protocols. Perform a complete idempotent refresh at startup and for mount/unmount notifications. Keep disruptive recovery verification opt-in and split user documentation from contributor documentation.

**Tech Stack:** Swift 6, FinderSync, AppKit, OSLog, Swift Testing, Bash, XcodeGen, Xcode 26/macOS 15+ SDK.

---

## File Map

- Create `Sources/CopyPathFinderExtension/MonitoredDirectoryRegistry.swift` for volume discovery, complete directory replacement, and notification observation.
- Modify `Sources/CopyPathFinderExtension/FinderSync.swift` to delegate lifecycle registration to the registry.
- Create `Tests/CopyPathTests/MonitoredDirectoryRegistryTests.swift` for isolated registry tests.
- Modify `scripts/verify_lifecycle.sh` for Finder restart and process recovery checks.
- Rewrite `README.md` for users and create `CONTRIBUTING.md` for developers.
- Regenerate `CopyPath.xcodeproj/project.pbxproj` from `project.yml`.

### Task 1: Snapshot-Based Directory Registration

**Files:**
- Create: `Tests/CopyPathTests/MonitoredDirectoryRegistryTests.swift`
- Create: `Sources/CopyPathFinderExtension/MonitoredDirectoryRegistry.swift`
- Regenerate: `CopyPath.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write failing tests**

Add `@MainActor` Swift Testing cases using these fakes:

```swift
@MainActor
private final class FakeMountedVolumeProvider: MountedVolumeProviding {
    var urls: [URL]?
    init(urls: [URL]?) { self.urls = urls }
    func mountedVolumeURLs() -> [URL]? { urls }
}

@MainActor
private final class RecordingDirectoryApplier: MonitoredDirectoryApplying {
    private(set) var snapshots: [Set<URL>] = []
    func replaceMonitoredDirectories(with urls: Set<URL>) { snapshots.append(urls) }
}
```

Test that `refresh()` includes `/`, includes mounted volumes, deduplicates repeated URLs, falls back to `/` when enumeration returns `nil`, and replaces an old snapshot after `provider.urls` changes.

- [ ] **Step 2: Regenerate and verify RED**

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project CopyPath.xcodeproj -scheme CopyPathUnitTests \
  -destination 'platform=macOS' test
```

Expected: compile failure because the registry protocols and type do not exist.

- [ ] **Step 3: Implement the minimal registry**

```swift
@MainActor
protocol MountedVolumeProviding: AnyObject {
    func mountedVolumeURLs() -> [URL]?
}

@MainActor
protocol MonitoredDirectoryApplying: AnyObject {
    func replaceMonitoredDirectories(with urls: Set<URL>)
}

@MainActor
final class MonitoredDirectoryRegistry: NSObject {
    private let volumeProvider: MountedVolumeProviding
    private let applier: MonitoredDirectoryApplying
    private let logger: Logger

    init(volumeProvider: MountedVolumeProviding,
         applier: MonitoredDirectoryApplying,
         logger: Logger = Logger(subsystem: Bundle.main.bundleIdentifier ??
             "com.vfedoroff.CopyPathAs.FinderExtension", category: "lifecycle")) {
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
```

Add concrete `FileManagerMountedVolumeProvider` and `FinderSyncDirectoryApplier` adapters in the same file. The provider uses `.skipHiddenVolumes`; the applier assigns `FIFinderSyncController.default().directoryURLs`.

- [ ] **Step 4: Verify GREEN and commit**

Run the Task 1 test command; expect `** TEST SUCCEEDED **`.

```bash
git add Sources/CopyPathFinderExtension/MonitoredDirectoryRegistry.swift \
  Tests/CopyPathTests/MonitoredDirectoryRegistryTests.swift \
  CopyPath.xcodeproj/project.pbxproj
git commit -m "refactor: make Finder directory registration idempotent"
```

### Task 2: Defensive Mount and Unmount Refresh

**Files:**
- Modify: `Tests/CopyPathTests/MonitoredDirectoryRegistryTests.swift`
- Modify: `Sources/CopyPathFinderExtension/MonitoredDirectoryRegistry.swift`
- Modify: `Sources/CopyPathFinderExtension/FinderSync.swift`

- [ ] **Step 1: Write a failing notification test**

Use an isolated `NotificationCenter`. Call `registry.startObserving(center)`, change the fake provider snapshot, then post both `NSWorkspace.didMountNotification` and `.didUnmountNotification` with empty or malformed `userInfo`. Expect three complete snapshots: startup plus one for each event, with the latest volume set and `/` in both event snapshots.

- [ ] **Step 2: Verify RED**

Run the Task 1 test command. Expected: compile failure because `startObserving(_:)` is missing.

- [ ] **Step 3: Add selector-based observation**

```swift
private weak var notificationCenter: NotificationCenter?

func startObserving(_ center: NotificationCenter) {
    notificationCenter?.removeObserver(self)
    notificationCenter = center
    center.addObserver(self, selector: #selector(volumeConfigurationDidChange(_:)),
                       name: NSWorkspace.didMountNotification, object: nil)
    center.addObserver(self, selector: #selector(volumeConfigurationDidChange(_:)),
                       name: NSWorkspace.didUnmountNotification, object: nil)
    refresh()
}

@objc private func volumeConfigurationDidChange(_ notification: Notification) {
    logger.info("Volume configuration changed; refreshing monitored directories")
    refresh()
}

deinit { notificationCenter?.removeObserver(self) }
```

Modify `FinderSync` to retain a registry, log initialization, and call `startObserving(NSWorkspace.shared.notificationCenter)`. Remove incremental `registerAvailableVolumes`, `volumeDidMount`, and `volumeDidUnmount` methods.

- [ ] **Step 4: Verify GREEN and commit**

Run the Task 1 test command; expect all tests to pass without concurrency warnings.

```bash
git add Sources/CopyPathFinderExtension/FinderSync.swift \
  Sources/CopyPathFinderExtension/MonitoredDirectoryRegistry.swift \
  Tests/CopyPathTests/MonitoredDirectoryRegistryTests.swift
git commit -m "feat: refresh Finder roots from volume snapshots"
```

### Task 3: Opt-In Desktop Lifecycle Verification

**Files:**
- Modify: `scripts/verify_lifecycle.sh`

- [ ] **Step 1: Verify the shell baseline**

Run `bash -n scripts/verify_lifecycle.sh`; expect exit 0.

- [ ] **Step 2: Add bounded wait helpers and cleanup**

Add `wait_for_process` and `wait_for_process_exit` functions that poll `pgrep -x` 40 times at 0.25-second intervals and print the supplied lifecycle stage on timeout. Add:

```bash
restore_finder() {
  /usr/bin/open -a Finder / >/dev/null 2>&1 || true
}
trap restore_finder EXIT
```

After the existing host-exit and `pluginkit` checks, restart Finder, open `/`, require `CopyPathFinderExtension` to appear, and assert `CopyPathAs` remains absent. Then terminate only `CopyPathFinderExtension`, require it to disappear, reopen `/` in Finder, and require a new extension process to appear.

- [ ] **Step 3: Verify syntax and commit**

Run `bash -n scripts/verify_lifecycle.sh`; expect exit 0. Do not execute the disruptive script without separate user authorization.

```bash
git add scripts/verify_lifecycle.sh
git commit -m "test: verify Finder extension process recovery"
```

### Task 4: Split User and Contributor Documentation

**Files:**
- Modify: `README.md`
- Create: `CONTRIBUTING.md`

- [ ] **Step 1: Rewrite README for users**

Keep purpose, format examples, supported macOS versions, release installation, first-run enabling, usage, and concise troubleshooting. Add a compact Shields.io row for latest GitHub release, macOS 15+, Swift 6, and MIT license, linking each badge to its relevant destination. Do not add build or coverage badges because this repository does not publish those results. State exactly that macOS loads the enabled extension when Finder starts and Copy Path As need not remain open or be a login item. Replace developer details with a link to `CONTRIBUTING.md`.

Use these badge sources:

```markdown
[![Latest release](https://img.shields.io/github/v/release/vfedoroff/copypathas)](https://github.com/vfedoroff/copypathas/releases/latest)
[![macOS 15+](https://img.shields.io/badge/macOS-15%2B-black?logo=apple)](#requirements)
[![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
```

- [ ] **Step 2: Create the contributor guide**

Use sections for prerequisites, project generation, architecture, coding guidelines, build/test commands, signing, lifecycle verification, debugging, and submitting changes. State that `project.yml` is authoritative, generated project changes accompany source additions, behavior changes need regression tests, and `make verify-lifecycle` restarts Finder and needs Accessibility/Automation permission.

- [ ] **Step 3: Check consistency and commit**

```bash
rg -n "start at login|login item|verify-lifecycle|xcodegen|CopyPathApp" \
  README.md CONTRIBUTING.md
git diff --check
git add README.md CONTRIBUTING.md
git commit -m "docs: split user and contributor guidance"
```

Expected: no user instruction starts the host at login, contributor commands live in `CONTRIBUTING.md`, and obsolete `CopyPathApp` names are absent.

### Task 5: Full Verification

**Files:**
- Verify all modified files.

- [ ] **Step 1: Regenerate and inspect**

Run `xcodegen generate`, `git diff --check`, and `git status --short`. Preserve the user's untracked `RELEASE_NOTES.md` without modifying or staging it.

- [ ] **Step 2: Run unit tests**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project CopyPath.xcodeproj -scheme CopyPathUnitTests \
  -destination 'platform=macOS' test
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 3: Build the application**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project CopyPath.xcodeproj -scheme CopyPath \
  -destination 'platform=macOS' build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Validate the lifecycle script non-destructively**

Run `bash -n scripts/verify_lifecycle.sh`; expect exit 0. Report the full desktop lifecycle run as a manual follow-up because it restarts Finder.

- [ ] **Step 5: Commit generated normalization only if needed**

If regeneration changed `CopyPath.xcodeproj/project.pbxproj`, stage it and commit `chore: regenerate Xcode project`. Do not create an empty commit.
