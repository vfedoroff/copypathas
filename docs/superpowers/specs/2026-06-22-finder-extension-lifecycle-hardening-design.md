# Finder Extension Lifecycle Hardening Design

## Goal

Make the Copy Path As Finder extension resilient across login, Finder restarts, extension-process termination, and volume mount changes without requiring the containing app to run.

macOS owns the Finder Sync extension lifecycle. Once the user enables the extension in System Settings, Finder loads it independently from the containing app. Copy Path As must work with that model instead of registering the app as a login item or adding a separate monitor process.

## User Experience

There is no new startup preference. The existing settings window remains the place to see whether the Finder extension is enabled and to open the system extension-management interface.

After the extension has been enabled:

- Its context menu is available after the user logs in and Finder starts.
- Restarting Finder does not require opening Copy Path As.
- If macOS terminates or recreates the extension process, a new instance reconstructs all required state from the current system state.
- Newly mounted visible volumes become covered, and unmounted volumes leave no stale registration.
- Closing the containing app does not affect the extension.

The app cannot and must not silently override the user's extension authorization. If the extension is disabled, the settings window continues to explain that state and provides the explicit system-management button.

## Architecture

Keep `FinderSync` as the thin Finder framework adapter and extract monitored-directory state into a focused, testable component.

### Monitored Directory Registry

`MonitoredDirectoryRegistry` owns the calculation and application of `FIFinderSyncController.directoryURLs`. It receives narrow dependencies for:

- Reading currently mounted, non-hidden volume URLs.
- Applying the complete monitored-directory set to Finder Sync.

Every refresh builds a new set containing the filesystem root `/` and all currently mounted visible volumes, then replaces Finder Sync's complete `directoryURLs` value. It does not incrementally mutate the previous set.

Full replacement is deliberate. Extension instances are disposable, mount notifications can be duplicated or missed, and notification ordering is not a reliable source of truth. Recomputing from `FileManager` makes startup and every later refresh idempotent and self-healing.

### FinderSync Lifecycle

Each `FinderSync` instance:

1. Creates its registry.
2. Performs an immediate full refresh during initialization.
3. Observes `NSWorkspace.didMountNotification` and `NSWorkspace.didUnmountNotification`.
4. Performs the same full refresh for either notification.

The callbacks do not depend on notification `userInfo`. A malformed, duplicated, or out-of-order notification therefore cannot insert a bad URL or remove the filesystem root.

The existing menu construction, selection formatting, and clipboard paths remain unchanged.

### Process Boundaries

The containing app remains a configuration and status UI. It terminates after its last window closes.

The Finder extension remains an app extension embedded in the containing application. It has no login item, launch agent, daemon, XPC helper, polling loop, or network dependency. Finder and macOS decide when to instantiate and terminate it.

## Diagnostics and Error Handling

Use the existing OSLog subsystem with privacy-safe lifecycle messages:

- Log extension initialization.
- Log successful directory refreshes with the number of registered roots, not their paths.
- Log when mounted-volume enumeration fails and the registry falls back to `/`.
- Log refreshes triggered by mount and unmount events.

Failure to enumerate mounted volumes is not fatal. The registry still applies `/`, keeping the primary filesystem covered. A later notification or a new extension instance performs another full refresh.

The extension continues to avoid modal UI. Missing selections remain no-ops, and clipboard failures remain logged without crashing Finder-facing code.

## Testing

Implementation follows red-green-refactor cycles.

### Unit Tests

Tests use fake volume providers and directory-set consumers; they do not mutate the real Finder Sync controller.

Cover these behaviors:

- Startup registration always contains `/`.
- Mounted visible volumes are included.
- Duplicate volume URLs are deduplicated.
- Failed or unavailable enumeration falls back to `/`.
- Each refresh replaces the complete set instead of accumulating stale entries.
- A mount-triggered refresh uses the latest system snapshot.
- An unmount-triggered refresh uses the latest system snapshot.
- Duplicate and malformed notifications are harmless because notification payloads are not used.

Existing menu routing, formatting, and app lifecycle tests remain regression coverage.

### Opt-In Desktop Lifecycle Verification

Strengthen `scripts/verify_lifecycle.sh`, which is intentionally separate from normal unit tests because it affects the logged-in desktop session and requires Accessibility/Automation permission.

The script builds and installs a signed app, then verifies:

1. The extension is registered and enabled according to `pluginkit`.
2. Closing the containing app terminates its process without disabling the extension.
3. Restarting Finder and opening a monitored location causes the extension process to load while the containing app remains stopped.
4. Terminating the extension process and triggering Finder again causes macOS to create a new extension process.

All waits are bounded and produce actionable failure messages containing the failed lifecycle stage. The script restores normal Finder availability before exiting after either success or failure. It does not enable or disable the extension automatically because that is a persistent user-controlled setting.

Normal CI runs unit tests and build verification only. The desktop lifecycle check remains an explicit local or dedicated-runner command.

## Documentation

Split documentation by audience instead of keeping user and developer material in one README.

`README.md` is the user-facing entry point. Keep:

- A compact Shields.io badge row for the latest release, macOS 15+, Swift 6, and the MIT license. Each badge links to its relevant release, platform, language, or license destination; do not claim CI or coverage status that the repository does not publish.
- What Copy Path As does and the available output formats.
- Supported macOS versions.
- Release installation and first-run instructions.
- The one-time System Settings step required to enable the Finder extension.
- Normal usage and concise troubleshooting.
- A clear statement that macOS manages the extension and the containing app does not need to remain open or start at login.
- A short link to `CONTRIBUTING.md` for source builds and development.

Create `CONTRIBUTING.md` for contributors. Move or rewrite:

- Prerequisites and source checkout setup.
- XcodeGen, signing, and local build instructions.
- Target structure and dependency boundaries.
- Makefile and script-based workflows.
- Unit, UI, and lifecycle test guidance.
- Finder extension debugging and diagnostics.
- The warning that lifecycle verification restarts Finder and requires Accessibility/Automation permissions.
- Expectations for keeping `project.yml` as the project source of truth and adding regression tests with changes.

Avoid duplicating detailed commands between the two files. User installation stays in the README; developer installation and verification stay in the contributing guide. This prevents users and contributors from treating the containing app as a required startup process and makes contributor-only desktop disruption explicit.

## Scope

Included:

- Idempotent, snapshot-based monitored-directory registration.
- Defensive mount/unmount handling.
- Privacy-safe lifecycle diagnostics.
- Unit coverage for directory registration and refresh behavior.
- Opt-in verification of Finder restart and extension-process recovery.
- A user-focused README and a separate contributor guide.

Excluded:

- Starting the containing app at login.
- A helper executable or background watchdog.
- Programmatically enabling the Finder extension.
- Changing menu contents or path formatting.
- Automatically restarting Finder during ordinary builds or CI.
