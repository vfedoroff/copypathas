# Copy Path As

**Copy Path As** is a macOS utility built for macOS 15+ using Swift 6. It adds a context menu to Finder via a Finder Sync Extension, providing formatting options to copy file or folder paths to the clipboard.

---

## Why Copy Path As?

In macOS, copying a file or folder's path to the clipboard natively is possible but has significant usability constraints:

1. **Poor Usability & Discoverability**: To copy a path natively in Finder, you must right-click an item, hold down the Option key (`⌥`), and then select the hidden *Copy "..." as Pathname* option (or press `⌥⌘C`). This interaction is undiscoverable for most users.
2. **Single Format Constraint**: The native copy feature only provides the absolute filesystem path (e.g., `/Users/username/file.txt`).
3. **Developer & AI Workflow Friction**: Modern developer workflows, command-line operations, and interactions with LLM-based coding agents frequently require different path formatting conventions:
   - Paste-ready **double-quoted** or **shell-escaped** paths for terminal commands.
   - Fully qualified **File URLs** (`file://`) or formatted **Markdown links** to pass into markdown documentation or prompt context windows.
   - **JSON arrays** of path strings when feeding multiple file paths to configurations, scripts, or AI context prompts.

**Copy Path As** addresses these limitations by adding a highly visible submenu containing 9 formatting options that work on single or multiple items simultaneously.

---

## Features & Available Formats

When you select one or more items in Finder, right-click, and open **Copy Path As**, you can choose from the following formats:

| Format Option | Description | Output Example |
| :--- | :--- | :--- |
| **Path** | Plain, absolute filesystem path. | `/Users/username/Projects/main.swift` |
| **Quoted Path** | Absolute path enclosed in double quotes with internal quotes and backslashes escaped. | `"/Users/username/Projects/main.swift"` |
| **Shell-Escaped Path** | Absolute path with spaces and shell special characters escaped for terminal use. | `/Users/username/My\ Projects/main.swift` |
| **File URL** | A standard local file URL. | `file:///Users/username/Projects/main.swift` |
| **Filename** | The name of the file or folder, including its extension. | `main.swift` |
| **Filename Without Extension** | The name of the file or folder with the extension removed. | `main` |
| **Parent Folder** | The absolute path to the folder containing the selected item. | `/Users/username/Projects` |
| **JSON Array** | A pretty-printed JSON array containing the selected path(s). | `[\n  "/Users/username/Projects/main.swift"\n]` |
| **Markdown Link** | A ready-to-paste Markdown link referencing the file URL. | `[main.swift](file:///Users/username/Projects/main.swift)` |

### Multi-Selection Behavior
When copying paths for multiple selected files/folders:
- **JSON Array**: Combines all paths into a single structured JSON array string.
- **Other Formats**: Formats each path individually and joins them with newlines (`\n`).

---

## Architecture & Security

- **Integration**: Utilizes Apple's `FinderSync` framework for native context menu integration.
- **Sandboxed**: Both the containing application and the extension run within the macOS App Sandbox (`com.apple.security.app-sandbox`). They do not request filesystem read/write access; the extension formats URLs supplied by Finder in-memory without reading file contents.
- **Swift 6**: Built with strict concurrency checking and the macOS 15 SDK.

---

## Requirements

- macOS 15.0 or later
- Xcode 16.0 or later (supporting Swift 6 and the macOS 15 SDK)
- Homebrew (to install `xcodegen` and `swiftlint`)

---

## Setup & Local Installation

### 1. Install Prerequisites

Install the required development tools using the [Brewfile](Brewfile) and Homebrew:

```sh
brew bundle
```

### 2. Generate the Xcode Project

We use [project.yml](project.yml) as the source of truth for targets and build settings. Generate the Xcode project by running:

```sh
xcodegen generate
open CopyPath.xcodeproj
```

### 3. Signing and Enabling the Finder Extension

1. Open `CopyPath.xcodeproj` in Xcode.
2. Select the same development team for `CopyPathApp`, `CopyPathFinderExtension`, and `CopyPathCore` under **Signing & Capabilities**.
3. Build and run the `CopyPath` scheme once to register the app.
4. In the app settings window, click **Open Finder Extension Settings**, or open System Settings → General → Login Items & Extensions → Finder Extensions.
5. Enable **Copy Path As**.
6. Select any item in Finder, right-click, and find the **Copy Path As** submenu.

---

## Project Structure & Targets

- **`CopyPathApp`**: SwiftUI containing application located in [Sources/CopyPathApp](Sources/CopyPathApp). Manages settings and extension status.
- **`CopyPathFinderExtension`**: The Finder Sync extension located in [Sources/CopyPathFinderExtension](Sources/CopyPathFinderExtension) which implements the context menu.
- **`CopyPathCore`**: Foundation-only shared framework located in [Sources/CopyPathCore](Sources/CopyPathCore).
- **`CopyPathTests`**: Unit tests for formatting logic located in [Tests/CopyPathTests](Tests/CopyPathTests).
- **`CopyPathUITests`**: UI automation tests verifying settings app states, located in [Tests/CopyPathUITests](Tests/CopyPathUITests).

---

## Build & Test Automation

The repository includes a [Makefile](Makefile) to simplify development tasks.

### Makefile Commands

- **Build Application**:
  ```sh
  make build
  ```
- **Build and Run**: Rebuilds, registers the extension, and runs the containing app locally:
  ```sh
  make run
  ```
- **Run Unit Tests**: Runs the fast unit test suite (suitable for local validation and CI):
  ```sh
  make test
  ```
- **Run UI Tests**: Runs full tests including native macOS settings UI interactions:
  ```sh
  make test-ui
  ```
- **Verify Lifecycle**: Runs the local lifecycle verification checks:
  ```sh
  make verify-lifecycle
  ```
- **Clean Project**: Removes build artifacts and the generated Xcode project:
  ```sh
  make clean
  ```

### Script-Based Workflows

For local build automation and debugging, you can use:
- **[build_and_run.sh](scripts/build_and_run.sh)**: Rebuilds and launches the app. Supports flags: `--debug`, `--logs`, `--telemetry`, and `--verify`.
- **[verify_lifecycle.sh](scripts/verify_lifecycle.sh)**: A local lifecycle check that installs the app in `~/Applications`, closes the settings UI via System Events, and verifies the extension remains running in the background. *(Note: Requires Accessibility permissions under System Settings → Privacy & Security → Accessibility)*.

---

## Distribution & Installation

### Manual Installation (GitHub Releases)
Pre-compiled versions of **Copy Path As** are available as `.dmg` or `.zip` files on the [GitHub Releases](https://github.com/vfedoroff/copypathas/releases) page.

> [!WARNING]
> **Ad-Hoc Code Signing (Gatekeeper Security warning)**:
> This utility is distributed with ad-hoc signing. macOS Gatekeeper will show a warning when launching the app for the first time.
>
> To bypass this restriction:
> 1. Mount the `.dmg` and drag `CopyPathAs.app` into your `/Applications` folder.
> 2. Open a terminal window and run the following command to strip the quarantine attribute:
>    ```sh
>    xattr -d com.apple.quarantine /Applications/CopyPathAs.app
>    ```
> 3. Alternatively, right-click (or Control-click) `CopyPathAs.app` in Finder, select **Open**, and then select **Open** in the dialog window.

---

## Debugging the Finder Extension

To debug the Finder Sync Extension:
1. Select the `CopyPathFinderExtension` scheme in Xcode.
2. Edit the Run action of the scheme: set the executable to **Finder** (`/System/Library/CoreServices/Finder.app`).
3. Run the scheme. When Finder relaunches, invoke a **Copy Path As** command to hit active breakpoints.

### Useful Diagnostics

- **List active Finder Sync extensions**:
  ```sh
  pluginkit -m -p com.apple.FinderSync
  ```
- **Check if extension process is running**:
  ```sh
  pgrep -fl CopyPathFinderExtension
  ```
- **Stream extension logs**:
  ```sh
  log stream --info --predicate 'subsystem == "com.vfedoroff.CopyPathAs.FinderExtension"'
  ```
- **Force Finder restart** (to clear stale extension cache):
  ```sh
  killall Finder
  ```
