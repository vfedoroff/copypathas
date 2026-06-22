# Promotional Visuals Design

## Goal

Create credible, reusable visuals that demonstrate Copy Path As in a real macOS Finder workflow for the README and promotional materials.

## Deliverables

- A short, seamless README GIF showing file selection, the Finder context menu, the Copy Path As submenu, and a format choice.
- Clean Retina screenshots of the important workflow states.
- Branded promotional versions derived from the same captures, using restrained framing and a short headline.
- Source captures retained so the exported assets can be revised without repeating the entire capture.

Final assets will live under `docs/assets/`, with source captures in a clearly named subdirectory.

## Demo Content

Use a temporary Finder folder named `Sample Project` with realistic, neutral content:

- `README.md`
- `project-plan.pdf`
- `sales-data.csv`
- `Design Assets/logo.svg`
- `Sources/App.swift`

The files contain no personal, proprietary, or repository-specific information. The folder structure should make multi-file selection and paths containing spaces visually clear.

## Capture Workflow

Capture the actual macOS UI rather than recreating it. The primary sequence is:

1. Open `Sample Project` in Finder.
2. Select one or more representative files.
3. Open the Finder context menu.
4. Open the Copy Path As submenu.
5. Choose a useful format, preferably Shell-Escaped Path or Markdown Link.

If clipboard confirmation is not visible in Finder, the GIF ends immediately after the menu selection. A separate screenshot may show the pasted result in a neutral text field only if it improves comprehension without making the sequence feel slow.

## Visual Treatment

- Use a clean, neutral macOS appearance and a compact Finder window.
- Avoid personal filenames, usernames, unrelated desktop items, notifications, and account details.
- Keep clean screenshots free of annotations.
- Create promotional derivatives with a restrained frame, consistent spacing, and one concise headline.
- Preserve legibility at typical GitHub README width.

## Export Targets

- README GIF: optimized for file size, readable at approximately 900–1200 CSS pixels wide, and short enough to loop naturally.
- Clean screenshots: PNG at Retina resolution.
- Promotional images: PNG, using the same source captures and a layout suitable for repository pages and general social sharing.

Exact pixel dimensions may be adjusted to the captured Finder window while preserving sharp text and reasonable file size.

## Verification

- Confirm the visuals show the real Copy Path As extension and an accurate menu flow.
- Inspect every frame for private or machine-specific information.
- Preview the GIF at README display size and confirm menu text remains readable.
- Check the GIF loops cleanly and does not linger on incidental cursor movement.
- Verify all README asset links resolve from the repository.

## README Integration

Add a compact demonstration section near the top of `README.md`, after the introductory paragraph. Use the optimized GIF as the primary visual and keep additional screenshots in `docs/assets/` for promotional reuse without overcrowding the README.
