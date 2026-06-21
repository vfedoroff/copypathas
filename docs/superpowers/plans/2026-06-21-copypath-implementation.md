# CopyPath Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and test a native macOS 15 SwiftUI app with a Finder Sync extension that copies selected paths in nine formats.

**Architecture:** A `CopyPathCore` framework contains Foundation-only domain types, formatter, ports, and use case. The SwiftUI app and Finder extension are thin platform adapters; XcodeGen produces the native project deterministically.

**Tech Stack:** Swift 6, SwiftUI, AppKit, FinderSync, XCTest, XcodeGen, Xcode 26.5.

---

### Task 1: Project scaffold and core test harness

**Files:**
- Create: `project.yml`
- Create: `CopyPathCore/Domain/PathFormat.swift`
- Create: `CopyPathCore/Domain/FileSelection.swift`
- Create: `CopyPathCore/Formatting/PathFormatting.swift`
- Create: `CopyPathTests/PathFormatterTests.swift`

- [ ] Generate a four-target macOS project with `CopyPathCore`, `CopyPathApp`, `CopyPathFinderExtension`, and `CopyPathTests`; set macOS 15, Swift 6, app-extension-safe framework settings, extension embedding, and test dependencies.
- [ ] Add a failing formatter test that calls `PathFormatter().format([URL(fileURLWithPath: "/Users/me/main.go")], as: .path)` and expects `/Users/me/main.go`.
- [ ] Run `xcodegen generate` and `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project CopyPath.xcodeproj -scheme CopyPath -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`; expect failure because `PathFormatter` is undefined.
- [ ] Add the format enum, nonempty `FileSelection`, and `PathFormatting` protocol declarations required by the test.

### Task 2: Path formatter through TDD

**Files:**
- Create: `CopyPathCore/Formatting/PathFormatter.swift`
- Modify: `CopyPathTests/PathFormatterTests.swift`

- [ ] Add failing tests for plain, quoted, shell-escaped, file URL, filename, filename-without-extension, parent, JSON, and Markdown output, including spaces, quotes, backslashes, Unicode, dotfiles, multiple files, and Markdown delimiters.
- [ ] Implement `public struct PathFormatter: PathFormatting, Sendable` with `public func format(_ urls: [URL], as format: PathFormat) -> String` and focused private escaping helpers.
- [ ] Decode JSON output in tests to prove validity instead of asserting encoder whitespace only.
- [ ] Run the complete test scheme and require zero failures.

### Task 3: Application use case and clipboard port

**Files:**
- Create: `CopyPathCore/Application/ClipboardWriting.swift`
- Create: `CopyPathCore/Application/FormatPathsUseCase.swift`
- Create: `CopyPathTests/FormatPathsUseCaseTests.swift`

- [ ] Add test doubles implementing `PathFormatting` and `ClipboardWriting`.
- [ ] Add failing tests proving `execute(selection:format:)` forwards URLs and format, copies exactly once, and propagates clipboard errors.
- [ ] Implement `FormatPathsUseCase` with initializer-injected formatter and clipboard dependencies.
- [ ] Run all unit tests and require zero failures.

### Task 4: Finder extension adapter

**Files:**
- Create: `CopyPathFinderExtension/FinderSelectionProvider.swift`
- Create: `CopyPathFinderExtension/PasteboardClipboardService.swift`
- Create: `CopyPathFinderExtension/FinderSync.swift`
- Create: `CopyPathFinderExtension/Info.plist`
- Create: `CopyPathFinderExtension/CopyPathFinderExtension.entitlements`

- [ ] Implement pasteboard replacement with an error when `setString` fails.
- [ ] Implement selection retrieval from `selectedItemURLs()` at action time.
- [ ] Build a direct `Copy Path` item and one `CopyPath` submenu using one target/action method and `representedObject` raw format identifiers.
- [ ] Register `/` and mounted volumes; observe mount and unmount notifications.
- [ ] Log missing selections, unknown identifiers, and clipboard errors without modal UI.
- [ ] Build the extension with sandboxing and validate its `com.apple.FinderSync` Info.plist configuration.

### Task 5: SwiftUI settings app and developer workflow

**Files:**
- Create: `CopyPathApp/CopyPathApp.swift`
- Create: `CopyPathApp/SettingsView.swift`
- Create: `CopyPathApp/ExtensionStatusProvider.swift`
- Create: `CopyPathApp/CopyPathApp.entitlements`
- Create: `script/build_and_run.sh`
- Create: `.codex/environments/environment.toml`
- Create: `README.md`

- [ ] Implement a single SwiftUI utility window showing extension status, management button, concise Finder instructions, and all supported formats.
- [ ] Add the minimal app sandbox entitlement.
- [ ] Add an Xcode build/run script supporting run, debug, logs, telemetry, and process verification modes with explicit `DEVELOPER_DIR`.
- [ ] Wire the Codex Run action to the script.
- [ ] Document target creation/configuration, signing, enabling, debugging, Finder restart, sandbox limitations, and exact local commands.
- [ ] Generate the project, run all unit tests, build the app with signing disabled, and inspect the built bundle for the embedded extension and framework.

### Task 6: Final verification

**Files:**
- Modify only files required to fix verification failures.

- [ ] Run `xcodegen generate` from a clean project definition.
- [ ] Run the full `xcodebuild test` command with signing disabled and require zero failures.
- [ ] Run `xcodebuild build` with signing disabled and require exit code 0.
- [ ] Use `find` and `plutil` to verify `CopyPath.app/Contents/PlugIns/CopyPathFinderExtension.appex`, embedded framework locations, extension point identifier, and minimum OS version.
- [ ] Review `git diff --check` and repository status; report any remaining manual signing or System Settings steps accurately.
