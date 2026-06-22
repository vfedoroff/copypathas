# Copy Path As 0.2.0

This release improves Finder extension reliability and makes the project documentation easier to navigate.

## Highlights

- Rebuilds the complete monitored-directory set whenever the Finder extension starts or mounted volumes change.
- Handles duplicated, malformed, or out-of-order volume notifications without accumulating stale paths.
- Adds privacy-safe lifecycle logging and regression tests for extension startup and volume refresh behavior.
- Adds an opt-in lifecycle verification workflow for Finder restarts and extension-process recovery.
- Separates user installation and usage documentation from contributor build and debugging guidance.
- Adds release, macOS, Swift, and license badges to the README.

## Requirements

- macOS 15 or later.
- Copy Path As enabled in **System Settings → General → Login Items & Extensions → Finder Extensions**.

Once enabled, macOS loads the extension whenever Finder starts. The Copy Path As settings app does not need to remain open or run at login.

## Installation

Download `CopyPathAs.dmg` or `CopyPathAs.zip`, move `CopyPathAs.app` to `/Applications`, and open it once to access Finder extension settings.

The release remains ad-hoc signed rather than notarized. If macOS blocks the first launch, Control-click the app, choose **Open**, and confirm the prompt.
