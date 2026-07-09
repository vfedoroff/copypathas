# Copy Path As App Store Assets

This directory contains the reproducible Mac App Store screenshot pipeline for
Copy Path As.

## Canonical Workflow

1. Check the capture environment:

   ```sh
   docs/assets/appstore/check_capture_readiness.sh
   ```

2. For live Finder context-menu captures, require the Finder extension:

   ```sh
   docs/assets/appstore/check_capture_readiness.sh --require-extension
   ```

   If it is missing, rebuild, install, register, and verify the local app:

   ```sh
   docs/assets/appstore/check_capture_readiness.sh --install-if-needed
   ```

3. Capture source media as windows or selected regions:

   ```sh
   docs/assets/appstore/capture_deskpad_sources.sh --prepare
   docs/assets/appstore/capture_deskpad_sources.sh --screenshot 01-context-menu
   docs/assets/appstore/capture_deskpad_sources.sh --screenshot 02-format-menu
   docs/assets/appstore/capture_deskpad_sources.sh --screenshot 03-preview-tab
   docs/assets/appstore/capture_deskpad_sources.sh --screenshot 04-setup-overview
   docs/assets/appstore/capture_deskpad_sources.sh --screenshot 05-selections
   ```

4. Record preview source video as a selected region:

   ```sh
   docs/assets/appstore/capture_deskpad_sources.sh --record-preview
   ```

   This writes `source/deskpad/app-preview-source.mov`.

5. Generate preview video and GIF:

   ```sh
   docs/assets/appstore/generate_preview.sh
   ```

   This writes:

   - `preview/copy-path-as-app-preview.mp4`
   - `preview/copy-path-as-app-preview.gif`

   To keep a new export alongside older stable filenames:

   ```sh
   TIMESTAMPED_OUTPUT=true docs/assets/appstore/generate_preview.sh
   ```

   To encode a specific live recording without replacing the default source:

   ```sh
   SOURCE=/path/to/live-recording.mov OUTPUT_BASENAME=copy-path-as-app-preview-YYYYMMDD-HHMMSS docs/assets/appstore/generate_preview.sh
   ```

6. Generate and validate final assets:

   ```sh
   docs/assets/appstore/generate_screenshots.sh
   docs/assets/appstore/validate_assets.sh
   ```

## Capture Rules

- Use window or selected-region captures, not full-screen screenshots.
- Exclude menu bar, Dock, desktop edges, Stage Manager, private data, and unrelated apps from raw source media.
- Keep Finder hidden files off, Dock auto-hide on, Stage Manager off, and Light appearance active.
- Use neutral sample files from `capture_deskpad_sources.sh --prepare`.
- Use Computer Use only to stage fragile UI states such as nested Finder menus.
- Record videos as selected regions so the source movie excludes the menu bar,
  Dock, and unrelated apps.

## App Health Gate

Live Finder menu screenshots require a healthy installed app and Finder
extension:

- `/Applications/CopyPathAs.app` exists with bundle id `com.vfedoroff.CopyPathAs`.
- `pluginkit` shows `com.vfedoroff.CopyPathAs.FinderExtension` registered and enabled.
- `scripts/build_and_run.sh --verify` succeeds.
- `scripts/verify_lifecycle.sh` succeeds before production capture.

Local ad-hoc signing is acceptable for source captures. Use a signed release
build only when screenshots must represent the exact public release.

## Optional Design Tools

Figma can be used for reviewing layout direction, copy hierarchy, visual polish,
or sharing concepts. It is not the export source of truth.

`ParthJadhav/app-store-screenshots` is useful inspiration for marketing
screenshots: one outcome per slide, large readable headlines, connected visual
rhythm, and git-trackable deck state. It is not a dependency for this macOS
pipeline because its documented exports target iPhone, iPad, Android, and Play
Store formats rather than Mac App Store 16:10 screenshots.
