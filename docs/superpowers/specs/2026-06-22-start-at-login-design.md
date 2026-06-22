# Start at Login Design

## Goal

Let users configure Copy Path As to start automatically when they log in to macOS. An automatic launch must be silent: it must not open the settings window, activate the app, or leave a Dock icon visible. Opening Copy Path As normally must continue to show the settings window.

The implementation uses only public macOS APIs and follows the platform's Login Items controls. It does not install a helper executable, launch agent, or privileged component.

## User Experience

Add a `General` section near the top of the existing settings form with a `Start at login` toggle and short explanatory text. The toggle reflects the system registration state rather than a duplicated `UserDefaults` value.

Changing the toggle has these effects:

- On: register `SMAppService.mainApp`.
- Off: unregister `SMAppService.mainApp`.
- Registration success: clear any previous error and refresh the displayed system state.
- Registration that requires user approval: explain that approval is needed and offer an `Open Login Items Settings` button.
- Other registration failures: keep the actual system state visible and show a concise inline error without crashing or presenting a modal alert.

The view refreshes the registration status whenever its scene becomes active so changes made in System Settings are reflected promptly. VoiceOver receives the standard toggle label and the status/error text remains selectable and readable.

## Architecture

Introduce a small login-item boundary owned by the containing app:

- `LoginItemControlling` defines the status, enable, disable, and System Settings operations needed by the UI.
- `LoginItemController` adapts `SMAppService.mainApp` from the ServiceManagement framework.
- A view-owned observable settings model converts platform statuses into presentation state and performs toggle operations.

The system registration is the single source of truth. `@AppStorage` is intentionally not used because macOS users may change the setting outside the app, and a stored Boolean could then disagree with the operating system.

The controller maps all relevant `SMAppService.Status` values:

- `.enabled`: the toggle is on.
- `.notRegistered`: the toggle is off.
- `.requiresApproval`: the toggle is off and approval guidance is shown.
- `.notFound`: the toggle is off and an availability error is shown.
- Future unknown values: the toggle is off and a generic unavailable state is shown.

The app's macOS 15 deployment target means no legacy `SMLoginItemSetEnabled` fallback is needed.

## Silent Login Lifecycle

At launch, `AppLifecycleDelegate` inspects the current open-application Apple event for `keyAELaunchedAsLogInItem`, the public system marker specifically intended for suppressing normal launch UI.

For a login-item launch, the delegate:

1. Changes the activation policy to `.accessory` so the app has no Dock icon.
2. Orders any automatically created SwiftUI window out without closing it.
3. Leaves the process running silently with the hidden window available for later reuse.

For a normal launch, existing behavior remains unchanged and the settings window appears.

If the already-running silent app is opened from Finder, Spotlight, Launchpad, or `open`, the application reopen callback changes the activation policy back to `.regular`, activates the app, and makes the existing settings window key and visible. Closing the visible settings window continues to terminate the containing app; its login-item registration remains in place for the next login. The Finder extension remains independently managed by macOS.

Launch-event inspection is isolated behind an injectable value or protocol so lifecycle decisions can be tested without manufacturing real login sessions or mutating the developer machine's Login Items.

## Error Handling

Registration and unregistration errors are caught at the settings-model boundary. The UI never assumes the requested state was applied; it rereads `SMAppService.mainApp.status` after every attempt.

The app does not automatically open System Settings. It provides an explicit user action when approval is required, avoiding surprising navigation. No telemetry or network reporting is added.

## Testing

Development follows red-green-refactor cycles.

Unit tests cover:

- Mapping enabled, disabled, approval-required, unavailable, and unknown service states.
- Registering when the user turns the toggle on.
- Unregistering when the user turns the toggle off.
- Preserving the real system state and surfacing an error when an operation fails.
- Detecting login-item versus normal launches from injected launch context.
- Selecting silent accessory behavior for login launches and normal window behavior for direct launches.
- Restoring regular activation and the settings window when a silently running app is reopened.

Tests use a fake `LoginItemControlling`; they never register the test runner as a real login item.

The UI test verifies that the settings window exposes a `Start at login` toggle. Full automatic-login behavior is verified manually with a signed app because a UI test must not modify the host account's persistent Login Items or log the test session out.

Build verification uses the generated Xcode project with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. The project file remains generated from `project.yml`, which is the source of truth.

## Scope

Included:

- Main-app registration with `SMAppService.mainApp`.
- A settings toggle, system-state feedback, and approval guidance.
- Silent automatic launch and normal manual reopen behavior.
- Unit and UI regression coverage.
- A brief README update describing the option and macOS Login Items approval.

Excluded:

- A separate helper app, launch agent, daemon, or privileged service.
- Launching the Finder extension manually; macOS continues to manage it.
- Starting minimized, showing a menu-bar item, or adding a persistent background task.
- Supporting macOS releases older than the current macOS 15 deployment target.
