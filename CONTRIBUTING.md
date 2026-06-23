# Contributing to Copy Path As

Contributions should preserve the extension's independence from the containing app and keep user-facing behavior covered by regression tests.

## Prerequisites

- macOS 15 or later
- Xcode 16 or later installed at `/Applications/Xcode.app`
- [Homebrew](https://brew.sh/)

Install the command-line dependencies:

```sh
brew bundle
```

The Brewfile installs XcodeGen and SwiftLint.

## Generate and Open the Project

`project.yml` is the source of truth for targets and build settings. Do not edit generated target membership directly in Xcode.

```sh
xcodegen generate
open CopyPathAs.xcodeproj
```

When adding or removing source files, regenerate `CopyPathAs.xcodeproj` and include the corresponding generated project change in the same commit.

If command-line tools point to the standalone Command Line Tools installation, prefix Xcode commands with:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

## Architecture and Project Structure

- `CopyPathAs` is the SwiftUI containing app. It shows extension status and exits after its final window closes.
- `CopyPathFinderExtension` is the Finder Sync extension. Finder and macOS own its process lifecycle.
- `CopyPathCore` contains deterministic formatting and application logic shared by the app extension.
- `CopyPathTests` contains Swift Testing unit tests.
- `CopyPathUITests` contains macOS UI tests for the settings window.

`CopyPathCore` must remain Foundation-only and safe for app-extension use. AppKit, SwiftUI, FinderSync, pasteboard access, and lifecycle APIs belong in their platform adapters.

The extension must reconstruct its state whenever Finder creates a new instance. Do not add a login item, helper process, daemon, polling loop, or dependency on the containing app for Finder menu availability.

## Coding Guidelines

- Use Swift 6 and preserve strict concurrency checking.
- Prefer small types with explicit dependencies over global mutable state.
- Treat operating-system state as authoritative; avoid duplicating it in preferences.
- Keep Finder callbacks fast and avoid modal UI from the extension.
- Log operational failures with `Logger` without exposing selected file paths.
- Add a failing regression test before implementing a behavior change or bug fix.
- Keep generated files, build products, and developer-specific signing settings out of source changes.

## Build and Test Commands

```sh
make build             # Generate the project and build with local signing defaults
make test              # Run unit tests
make test-ui           # Run unit and settings UI tests
make lint              # Run SwiftLint
make run               # Build, install to /Applications, and open the app
make package           # Create ad-hoc signed ZIP and DMG artifacts
make release-local     # Maintainer-only signed, notarized, published release
make clean             # Remove generated project and build output
```

Before submitting a change, run at least:

```sh
make test
make build
make lint
```

UI changes also require `make test-ui`. Changes to Finder startup, process ownership, or volume registration require the desktop lifecycle verification below.

## Signing and Finder Extension Setup

For normal Xcode development, select the same development team for `CopyPathAs`, `CopyPathFinderExtension`, and `CopyPathCore`. Build and run the `CopyPathAs` scheme once from a stable app location, then enable the extension in **System Settings → General → Login Items & Extensions → Finder Extensions**.

`scripts/build_and_run.sh` builds the app, installs it under `/Applications` by default, registers the embedded extension, and opens the settings app. Set `COPYPATH_INSTALL_DIR` to use a different stable install location. The stable install path matters because Finder extension registration should not point at transient DerivedData products.

## Maintainer Release Flow

Public CI does not store Apple signing certificates, provisioning profiles, or App Store Connect credentials. Maintainers publish signed releases from a local Mac that already has the Developer ID certificate in Keychain and a `notarytool` keychain profile.

One-time local setup:

```sh
cp Configs/Config.local.xcconfig.template Configs/Config.local.xcconfig
# Set DEVELOPMENT_TEAM in Configs/Config.local.xcconfig.
xcrun notarytool store-credentials copypath-notary
```

Release from an exact tag checkout:

```sh
export COPYPATH_NOTARY_PROFILE=copypath-notary
make test
make release-local
```

Or pass a tag explicitly:

```sh
COPYPATH_NOTARY_PROFILE=copypath-notary ./scripts/release_local_signed.sh --tag v0.3.0 --publish
```

The local release script builds the Release archive, Developer ID signs it, notarizes and staples the app, creates ZIP and DMG artifacts, notarizes and staples the DMG, writes SHA-256 checksums, and uploads the release assets with `gh`. The GitHub release follow-up workflow updates the Homebrew tap after the signed DMG is published.

## Desktop Lifecycle Verification

```sh
make verify-lifecycle
```

This opt-in check closes the settings app, restarts Finder, terminates the Finder extension process, and verifies that macOS loads a new extension process without relaunching the containing app.

The command changes the active desktop session and requires:

- The extension already enabled in System Settings.
- Accessibility permission for the terminal or development tool running it.
- Automation permission to control System Events if macOS requests it.

Do not run this command in ordinary CI or while the user has Finder operations in progress.

## Debugging the Finder Extension

To debug interactively, select the `CopyPathFinderExtension` scheme and set Finder (`/System/Library/CoreServices/Finder.app`) as the Run executable.

Useful diagnostics:

```sh
pluginkit -m -p com.apple.FinderSync
pgrep -fl CopyPathFinderExtension
log stream --info --predicate 'subsystem == "com.vfedoroff.CopyPathAs.FinderExtension"'
```

To stream both app and extension logs from the local development install:

```sh
./scripts/build_and_run.sh --logs
```

## Submitting Changes

Keep pull requests focused. Describe the user-visible behavior, include regression coverage, and note which verification commands were run. Do not include local signing identities, DerivedData, packaged applications, or unrelated generated changes.
