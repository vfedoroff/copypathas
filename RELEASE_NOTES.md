# Copy Path As 0.4.0

This release introduces an App Doctor diagnostic tool, customizable copy feedback options, UI refinements, a demo mode, and robustness improvements for developers.

## Highlights

- **App Doctor Diagnostic Dashboard**: Introduces a built-in diagnostic checker to verify extension heartbeat status, detect duplicate app installations, and ensure the app is running from a stable path (`/Applications`). Includes one-click repair actions like "Restart Finder" and "Open Extension Settings" to resolve integration conflicts.
- **Customizable Copy Feedback**: Configure how you want to be notified when a path is successfully copied. Choose to play a subtle audio tone ("Glass"), trigger a haptic pulse, show a standard macOS user notification, or copy silently.
- **Settings UI Polish**: Updates the Settings application with a clean, tabbed layout, refined status indicators, build metadata display, and improved scrolling behaviour.
- **Onboarding Demo Mode**: Introduces an interactive Demo Mode allowing command-line preview parameters (`--demo overview`, `--demo formats`, `--demo setup`) to run the UI in specific states without side-effects.
- **Contributor Sandbox Robustness**: Gracefully falls back to standard User Preferences when sandboxed App Groups are not available, fixing local preferences sync for local development builds.

## Requirements

- macOS 15 or later.
- Copy Path As enabled in **System Settings → General → Login Items & Extensions → Finder Extensions**.

Once enabled, macOS loads the extension whenever Finder starts. The Copy Path As settings app does not need to remain open or run at login.

## Installation

Download `CopyPathAs.dmg` or `CopyPathAs.zip`, move `CopyPathAs.app` to `/Applications`, and open it once to access Finder extension settings.

Maintainer releases are Developer ID signed and notarized locally before upload.
