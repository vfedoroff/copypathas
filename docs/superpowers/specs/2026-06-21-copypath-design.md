# CopyPath Design

## Objective

CopyPath is a native macOS 15+ utility that adds developer-oriented path-copying commands to Finder. It consists of a small SwiftUI containing app, a Finder Sync extension, and a shared Swift framework containing deterministic formatting and application logic.

The MVP works locally without requiring the containing app to remain open. It has no network dependency, database, helper process, or third-party package.

## User Experience

When one or more Finder items are selected, the contextual menu contains a direct primary action and one submenu:

```text
Copy Path
CopyPath >
    Quoted Path
    Shell-Escaped Path
    File URL
    Filename
    Filename Without Extension
    Parent Folder
    JSON Array
    Markdown Link
```

`Copy Path` is direct because it is the most frequent operation and needs to remain immediately discoverable. The other formats use a single submenu level to avoid adding eight more top-level Finder commands.

The extension returns commands only for `FIMenuKind.contextualMenuForItems`. Container, sidebar, and toolbar menus are outside the MVP.

For multiple selections, plain formats produce one result per line, JSON produces one valid pretty-printed JSON array, and Markdown produces one link per line. Input order is preserved.

The settings app displays:

- Whether the Finder extension is enabled, using `FIFinderSyncController.isExtensionEnabled`.
- A button that invokes `FIFinderSyncController.showExtensionManagementInterface()`.
- Brief instructions for finding the two contextual-menu entries.
- The complete list of supported formats.

No menu customization is included in the MVP.

## Project and Target Structure

```text
CopyPath.xcodeproj
├── CopyPathCore
│   ├── Domain
│   │   ├── PathFormat.swift
│   │   └── FileSelection.swift
│   ├── Application
│   │   ├── FormatPathsUseCase.swift
│   │   └── ClipboardWriting.swift
│   └── Formatting
│       ├── PathFormatting.swift
│       └── PathFormatter.swift
├── CopyPathApp
│   ├── CopyPathApp.swift
│   ├── SettingsView.swift
│   └── ExtensionStatusProvider.swift
├── CopyPathFinderExtension
│   ├── FinderSync.swift
│   ├── FinderSelectionProvider.swift
│   ├── PasteboardClipboardService.swift
│   ├── Info.plist
│   └── CopyPathFinderExtension.entitlements
└── CopyPathTests
    ├── PathFormatterTests.swift
    └── FormatPathsUseCaseTests.swift
```

There are four Xcode targets:

1. `CopyPathCore`, a dynamic macOS framework embedded by both executable targets.
2. `CopyPathApp`, the containing SwiftUI application.
3. `CopyPathFinderExtension`, the Finder Sync app extension embedded in the containing app.
4. `CopyPathTests`, an XCTest bundle testing `CopyPathCore`.

`CopyPathCore` uses folder-level logical layers rather than separate framework targets. This preserves dependency direction without multiplying framework embedding and signing configuration.

## Dependency Rules

```text
CopyPathApp ───────────────> CopyPathCore
CopyPathFinderExtension ───> CopyPathCore
```

`CopyPathCore` imports Foundation only. It does not import AppKit, SwiftUI, FinderSync, or depend on either executable target.

The app and Finder extension are platform adapters. AppKit pasteboard access remains in the Finder extension. Finder selection APIs remain in the Finder extension. SwiftUI and extension-management APIs remain in the app.

No dependency-injection framework is used. Initializers receive protocol dependencies explicitly.

## Core Types and Application Flow

`PathFormat` is a `String`, `CaseIterable`, and `Sendable` enumeration containing:

- `path`
- `quotedPath`
- `shellEscapedPath`
- `fileURL`
- `filename`
- `filenameWithoutExtension`
- `parentFolder`
- `jsonArray`
- `markdownLink`

`FileSelection` is a nonempty value object wrapping `[URL]`. It preserves Finder ordering and rejects an empty URL array through a failable initializer.

`PathFormatting` exposes:

```swift
func format(_ urls: [URL], as format: PathFormat) -> String
```

`ClipboardWriting` exposes:

```swift
func copy(_ value: String) throws
```

`FormatPathsUseCase` receives a `PathFormatting` implementation and a `ClipboardWriting` implementation. Its `execute(selection:format:)` operation formats the selected URLs and copies the nonempty result. Clipboard failures are allowed to propagate to the adapter boundary.

The Finder action flow is:

```text
Finder action
  → FinderSelectionProvider reads selectedItemURLs()
  → FileSelection validates the selection
  → FormatPathsUseCase formats it
  → PasteboardClipboardService replaces pasteboard text
```

Selection is read inside the invoked menu action because Finder only guarantees valid selection URLs while building the menu or processing one of its actions. It is not cached between callbacks.

## Formatting Semantics

All formats operate on file URLs and preserve Unicode.

### Path

Uses `URL.path(percentEncoded: false)` and joins multiple results with `"\n"`.

### Quoted path

Wraps each path in double quotes and escapes `\`, `"`, newline, carriage return, and tab inside the quoted value. Multiple values are newline-separated.

### Shell-escaped path

Produces a POSIX-shell-safe token. For ordinary paths, every character outside `A-Z`, `a-z`, `0-9`, `_`, `-`, `.`, `/`, `:`, and non-ASCII letters or numbers is prefixed with a backslash; this gives the expected `/My\ App/` representation while preserving readable Unicode. If a path contains a newline or carriage return, the formatter instead uses POSIX single-quote syntax and represents an embedded single quote with the sequence `'\''`. The resulting token can be pasted as one shell argument. Multiple values are newline-separated.

### File URL

Uses `URL.absoluteString`, preserving valid URL percent encoding. Multiple values are newline-separated.

### Filename

Uses `URL.lastPathComponent`. Multiple values are newline-separated.

### Filename without extension

Uses `URL.deletingPathExtension().lastPathComponent`. A filename without an extension is unchanged. Dotfiles such as `.gitignore` are treated according to Foundation URL semantics and remain `.gitignore`.

### Parent folder

Uses `URL.deletingLastPathComponent().path(percentEncoded: false)`. Multiple values are newline-separated.

### JSON array

Encodes the decoded filesystem paths using `JSONEncoder` with `.prettyPrinted` and `.withoutEscapingSlashes`. Output is valid JSON and has stable indentation. JSON escaping is delegated to Foundation.

### Markdown link

Uses the decoded filename as link text and the percent-encoded `absoluteString` file URL as destination:

```text
[main.go](file:///Users/me/Projects/App/main.go)
```

In link text, `\`, `[`, and `]` are backslash-escaped. In the destination, literal `(` and `)` are percent-encoded to prevent them from terminating the Markdown destination. Multiple links are newline-separated.

## Finder Extension Behavior

`FinderSync` builds menu items from static `PathFormat` mappings. Menu item `representedObject` stores the format raw value, avoiding one selector per format. All items target one action method.

At initialization, the extension registers:

- The filesystem root `/`.
- Every currently mounted, non-hidden volume returned by `FileManager.mountedVolumeURLs`.

It observes `NSWorkspace.didMountNotification` and `NSWorkspace.didUnmountNotification` to add and remove volume roots. This supports external disks and network mounts without requiring the containing app.

If the selection is empty or unavailable, the action returns without modifying the pasteboard. Formatter and clipboard failures are logged through `Logger`; the extension does not display modal UI from Finder.

The extension never assumes the containing application is running.

## Clipboard Behavior

`PasteboardClipboardService` uses `NSPasteboard.general`. It calls `clearContents()` before `setString(_:forType: .string)` and throws a small adapter error if the pasteboard rejects the string.

The service copies text only. It does not place file promises or file-reference pasteboard types on the clipboard.

## Sandboxing and Entitlements

Both the containing app and Finder extension use App Sandbox:

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
```

No file read/write entitlement is required because CopyPath formats URLs provided by Finder and never opens, reads, writes, deletes, or launches the selected items.

No network, Apple Events, accessibility, login item, or temporary-exception entitlement is included.

An App Group is not included in the MVP because there are no shared settings. If configurable format visibility is later added, the app and extension will share only those preferences through an App Group `UserDefaults` suite.

All targets use the same signing team and signing style. `CopyPathCore` has `APPLICATION_EXTENSION_API_ONLY = YES` so both the app and extension can safely link it.

## Finder Extension Configuration

The Finder extension `Info.plist` defines:

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.FinderSync</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).FinderSync</string>
</dict>
```

The extension bundle is embedded in `CopyPath.app/Contents/PlugIns`. The shared framework is embedded and signed in both the containing app and extension bundle using the Frameworks destination.

## Error Handling and Diagnostics

Formatting functions are deterministic and do not fail for valid file URLs. An empty selection is rejected before formatting.

Operational failures are handled as follows:

- Missing Finder selection: no-op and debug log.
- Clipboard rejection: error log.
- Unknown menu format identifier: no-op and error log.
- Mount notification without a volume URL: ignored.

The extension uses `Logger` with the extension bundle identifier as subsystem and categories `finder`, `menu`, and `clipboard`. Paths are logged with privacy protection by default.

## Testing

`PathFormatterTests` covers:

- Simple paths.
- Paths containing spaces.
- Shell escaping of spaces and shell metacharacters.
- Unicode filenames.
- Files without extensions and dotfiles.
- Multiple selections for all line-oriented formats.
- File URL percent encoding.
- Parent folders.
- Valid JSON arrays and escaping of quotes, backslashes, newlines, and Unicode.
- Markdown escaping for brackets, backslashes, parentheses, spaces, and Unicode.

Tests use temporary or constructed file URLs and compare deterministic strings. JSON validity is additionally checked by decoding the output with `JSONDecoder`.

`FormatPathsUseCaseTests` uses an in-memory clipboard spy and formatter stub to verify:

- The requested format and URLs are forwarded.
- The formatted value is copied exactly once.
- Clipboard errors propagate.

FinderSync itself remains a thin platform adapter and is verified through a build plus manual Finder testing rather than unit tests that mock Apple framework singletons.

## Local Development and Debugging

The containing app and extension deploy to macOS 15.0. The project uses Swift 6 language mode and Xcode's current recommended build settings.

The developer selects a signing team, builds and runs `CopyPathApp`, then enables CopyPath under System Settings → General → Login Items & Extensions → Finder Extensions, or opens that interface from the app.

For extension debugging, the developer runs the Finder extension scheme with Finder as the host, invokes a CopyPath command in Finder, and attaches to the extension process when necessary. Finder can be restarted with:

```sh
killall Finder
```

Extension registration can be inspected with `pluginkit -m -p com.apple.FinderSync`, and unified logs can be filtered by the extension bundle identifier.

The repository includes a local build script and Codex run-button environment configuration. They build the app using `/Applications/Xcode.app/Contents/Developer` explicitly so the project works even when `xcode-select` points to Command Line Tools.

## Explicit Non-Goals

The MVP excludes configurable formats, keyboard shortcuts, toolbar integration, Finder sidebar commands, file mutation, shell execution, App Intents, Services, SwiftData, XPC helpers, login items, analytics, networking, update frameworks, and distribution automation.
