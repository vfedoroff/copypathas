#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR}"

fail() {
  echo "error: $*" >&2
  exit 1
}

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
SWIFT_BIN="${SWIFT_BIN:-$(/usr/bin/xcrun --find swift 2>/dev/null || true)}"
[[ -n "$SWIFT_BIN" && -x "$SWIFT_BIN" ]] || fail "Swift is required; checked DEVELOPER_DIR=$DEVELOPER_DIR"

RESOLUTIONS=("1280x800" "1440x900" "2560x1600" "2880x1800")
ITEMS=(
  "1|context|Copy Finder Paths Faster|Right-click once and send paths straight from Finder."
  "2|submenu|Choose Any Path Format|Shell, JSON, Markdown, URLs, filenames, and more."
  "3|preview|Preview Before Copying|See the exact result before it reaches your clipboard."
  "4|setup|Set Up Once|Enable the Finder extension and keep working normally."
  "5|selection|Works With Selections|Copy paths for files, folders, or mixed selections."
)

if [[ "${1:-}" == "--check" ]]; then
  echo "Swift: $SWIFT_BIN"
  echo "Output: $OUTPUT_DIR"
  printf 'Screenshots: %s\n' "${ITEMS[@]}"
  exit 0
fi

TMP_ROOT="${TMPDIR:-/tmp}/copypath-appstore"
mkdir -p "$TMP_ROOT"
WORK_DIR="$(mktemp -d "$TMP_ROOT/screenshots.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT
export CLANG_MODULE_CACHE_PATH="$WORK_DIR/clang-module-cache"
mkdir -p "$CLANG_MODULE_CACHE_PATH"

RENDERER="$WORK_DIR/render_clean_appstore_screenshot.swift"
cat >"$RENDERER" <<'SWIFT'
import AppKit
import Foundation

struct C {
    let r: CGFloat
    let g: CGFloat
    let b: CGFloat
    let a: CGFloat
    var ns: NSColor { NSColor(red: r / 255, green: g / 255, blue: b / 255, alpha: a) }
}

let ink = C(r: 15, g: 23, b: 42, a: 1).ns
let secondary = C(r: 71, g: 85, b: 105, a: 1).ns
let lineColor = C(r: 203, g: 213, b: 225, a: 1).ns
let blue = C(r: 0, g: 92, b: 230, a: 1).ns

func topRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ canvasH: CGFloat) -> NSRect {
    NSRect(x: x, y: canvasH - y - h, width: w, height: h)
}

func round(_ rect: NSRect, _ radius: CGFloat, fill: NSColor, stroke: NSColor? = nil, width: CGFloat = 1) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()
    if let stroke {
        stroke.setStroke()
        path.lineWidth = width
        path.stroke()
    }
}

func shadow(_ blur: CGFloat, y: CGFloat, alpha: CGFloat) {
    let s = NSShadow()
    s.shadowColor = NSColor.black.withAlphaComponent(alpha)
    s.shadowBlurRadius = blur
    s.shadowOffset = NSSize(width: 0, height: y)
    s.set()
}

func text(_ value: String, _ rect: NSRect, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = ink, align: NSTextAlignment = .left, mono: Bool = false, mode: NSLineBreakMode = .byTruncatingTail) {
    let p = NSMutableParagraphStyle()
    p.alignment = align
    p.lineBreakMode = mode
    let font = mono ? NSFont.monospacedSystemFont(ofSize: size, weight: weight) : NSFont.systemFont(ofSize: size, weight: weight)
    NSString(string: value).draw(in: rect, withAttributes: [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: p,
        .kern: 0
    ])
}

func strokeLine(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, color: NSColor = lineColor, width: CGFloat = 1.5) {
    let p = NSBezierPath()
    p.move(to: NSPoint(x: x1, y: y1))
    p.line(to: NSPoint(x: x2, y: y2))
    color.setStroke()
    p.lineWidth = width
    p.stroke()
}

func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, fill: NSColor, stroke: NSColor? = nil) {
    let rect = NSRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
    let p = NSBezierPath(ovalIn: rect)
    fill.setFill()
    p.fill()
    if let stroke {
        stroke.setStroke()
        p.lineWidth = 1.5
        p.stroke()
    }
}

func smallFileIcon(_ rect: NSRect, fill: NSColor, stroke: NSColor, folded: Bool = true) {
    round(rect, 3, fill: fill, stroke: stroke, width: 1)
    if folded {
        let fold = NSBezierPath()
        fold.move(to: NSPoint(x: rect.maxX - rect.width * 0.30, y: rect.maxY))
        fold.line(to: NSPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.30))
        fold.line(to: NSPoint(x: rect.maxX - rect.width * 0.30, y: rect.maxY - rect.height * 0.30))
        fold.close()
        NSColor.white.withAlphaComponent(0.7).setFill()
        fold.fill()
    }
}

func folderIcon(_ rect: NSRect, selected: Bool) {
    let fill = selected ? NSColor.white.withAlphaComponent(0.92) : C(r: 75, g: 166, b: 225, a: 1).ns
    let stroke = selected ? NSColor.white.withAlphaComponent(0.45) : C(r: 38, g: 121, b: 178, a: 1).ns
    let tab = NSRect(x: rect.minX + 2, y: rect.maxY - rect.height * 0.38, width: rect.width * 0.43, height: rect.height * 0.28)
    round(tab, 3, fill: fill, stroke: stroke, width: 1)
    round(NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * 0.72), 4, fill: fill, stroke: stroke, width: 1)
}

@discardableResult
func finderWindow(x: CGFloat, yTop: CGFloat, w: CGFloat, h: CGFloat, canvasH: CGFloat, mode: String) -> NSRect {
    let rect = topRect(x, yTop, w, h, canvasH)
    shadow(42, y: -14, alpha: 0.13)
    round(rect, 34, fill: .white, stroke: C(r: 190, g: 203, b: 218, a: 1).ns, width: 2)
    NSShadow().set()

    let topY = yTop
    let bottomY = yTop + h
    let left = x
    let right = x + w
    let toolbarH: CGFloat = 132
    let addressH: CGFloat = 54
    let headerH: CGFloat = 64
    let rowH: CGFloat = 56

    circle(left + 48, canvasH - topY - 44, 12, fill: C(r: 255, g: 95, b: 86, a: 1).ns)
    circle(left + 86, canvasH - topY - 44, 12, fill: C(r: 255, g: 189, b: 46, a: 1).ns)
    circle(left + 124, canvasH - topY - 44, 12, fill: C(r: 39, g: 201, b: 63, a: 1).ns)

    round(topRect(left + 218, topY + 20, 116, 58, canvasH), 28, fill: C(r: 248, g: 250, b: 252, a: 1).ns, stroke: C(r: 148, g: 163, b: 184, a: 1).ns, width: 2)
    text("‹", topRect(left + 240, topY + 21, 28, 50, canvasH), size: 44, weight: .regular, color: secondary, align: .center)
    text("›", topRect(left + 285, topY + 21, 28, 50, canvasH), size: 44, weight: .regular, color: secondary, align: .center)
    text("Sample Project", topRect(left + 378, topY + 30, 410, 44, canvasH), size: 34, weight: .bold, color: ink)

    let buttonY = topY + 20
    let controls: [(String, CGFloat)] = [("☷", right - 430), ("▦", right - 320), ("»", right - 188), ("⌕", right - 102)]
    for item in controls {
        round(topRect(item.1, buttonY, 66, 58, canvasH), 29, fill: C(r: 248, g: 250, b: 252, a: 1).ns, stroke: C(r: 148, g: 163, b: 184, a: 1).ns, width: 2)
        text(item.0, topRect(item.1, buttonY + 10, 66, 36, canvasH), size: item.0 == "⌕" ? 34 : 28, weight: .medium, color: ink, align: .center)
    }

    round(topRect(left + 28, topY + 92, w - 90, addressH, canvasH), 25, fill: .white, stroke: C(r: 100, g: 116, b: 139, a: 1).ns, width: 2)
    text("Sample Project", topRect(left + 28, topY + 105, w - 90, 30, canvasH), size: 23, weight: .semibold, color: ink, align: .center)
    round(topRect(right - 54, topY + 92, 50, 50, canvasH), 25, fill: .white, stroke: C(r: 100, g: 116, b: 139, a: 1).ns, width: 2)
    text("+", topRect(right - 54, topY + 96, 50, 34, canvasH), size: 36, weight: .regular, color: ink, align: .center)

    strokeLine(left, canvasH - topY - toolbarH, right, canvasH - topY - toolbarH, color: C(r: 148, g: 163, b: 184, a: 1).ns, width: 2)
    let headerY = topY + toolbarH
    text("Name", topRect(left + 92, headerY + 18, 190, 34, canvasH), size: 25, weight: .bold)
    text("Date Modified", topRect(left + 520, headerY + 18, 250, 34, canvasH), size: 25, weight: .medium, color: secondary)
    text("Size", topRect(right - 390, headerY + 18, 110, 34, canvasH), size: 25, weight: .medium, color: secondary)
    text("Kind", topRect(right - 230, headerY + 18, 170, 34, canvasH), size: 25, weight: .medium, color: secondary)
    strokeLine(left, canvasH - headerY - headerH, right, canvasH - headerY - headerH, color: C(r: 148, g: 163, b: 184, a: 1).ns, width: 2)

    let rows = [
        ("Design Assets", "", "--", "Folder", "folder"),
        ("project-plan.pdf", "Today, 3:42 PM", "16 KB", "PDF Document", "pdf"),
        ("README.md", "Today, 3:42 PM", "68 bytes", "Markdown", "markdown"),
        ("sales-data.csv", "Today, 3:42 PM", "55 bytes", "CSV Document", "file"),
        ("Sources", "Today, 3:42 PM", "--", "Folder", "folder")
    ]

    for i in rows.indices {
        let rowTop = headerY + headerH + CGFloat(i) * rowH
        let selected = (mode == "context" || mode == "submenu") && i == 0 || mode == "selection" && (i == 0 || i == 1 || i == 2)
        let rowRect = topRect(left + 26, rowTop + 6, w - 52, rowH - 10, canvasH)
        if selected {
            round(rowRect, 13, fill: blue)
        } else if i % 2 == 1 {
            round(rowRect, 13, fill: C(r: 241, g: 245, b: 249, a: 1).ns)
        }

        let color = selected ? NSColor.white : ink
        if rows[i].4 == "folder" {
            text(i == 0 ? "›" : "›", topRect(left + 50, rowTop + 14, 18, 30, canvasH), size: 28, weight: .semibold, color: color, align: .center)
            folderIcon(topRect(left + 74, rowTop + 17, 31, 24, canvasH), selected: selected)
        } else {
            let iconFill = rows[i].4 == "markdown" ? C(r: 14, g: 165, b: 233, a: 1).ns : C(r: 238, g: 242, b: 247, a: 1).ns
            smallFileIcon(topRect(left + 78, rowTop + 15, 24, 30, canvasH), fill: iconFill, stroke: C(r: 203, g: 213, b: 225, a: 1).ns)
        }
        text(rows[i].0, topRect(left + 118, rowTop + 13, 390, 34, canvasH), size: 27, weight: selected ? .semibold : .medium, color: color)
        text(rows[i].1, topRect(left + 520, rowTop + 13, 300, 34, canvasH), size: 26, weight: .regular, color: color)
        text(rows[i].2, topRect(right - 420, rowTop + 13, 120, 34, canvasH), size: 26, weight: .regular, color: color, align: .right)
        text(rows[i].3, topRect(right - 250, rowTop + 13, 210, 34, canvasH), size: 26, weight: .regular, color: color)
    }

    var fillerTop = headerY + headerH + CGFloat(rows.count) * rowH + 8
    while fillerTop < bottomY - 58 {
        round(topRect(left + 26, fillerTop, w - 52, 38, canvasH), 13, fill: C(r: 241, g: 245, b: 249, a: 0.78).ns)
        fillerTop += 64
    }

    return rect
}

func menuItem(_ title: String, x: CGFloat, yTop: CGFloat, w: CGFloat, canvasH: CGFloat, selected: Bool = false, arrow: Bool = false) {
    if selected {
        round(topRect(x + 10, yTop, w - 20, 42, canvasH), 8, fill: blue)
    }
    let color = selected ? NSColor.white : ink
    text(title, topRect(x + 36, yTop + 8, w - 78, 27, canvasH), size: 23, weight: selected ? .semibold : .regular, color: color)
    if arrow {
        text("›", topRect(x + w - 36, yTop + 5, 22, 30, canvasH), size: 27, weight: .semibold, color: color, align: .center)
    }
}

func divider(_ x: CGFloat, _ yTop: CGFloat, _ w: CGFloat, _ canvasH: CGFloat) {
    strokeLine(x + 32, canvasH - yTop, x + w - 32, canvasH - yTop, color: C(r: 148, g: 163, b: 184, a: 1).ns, width: 1.2)
}

func contextMenu(x: CGFloat, yTop: CGFloat, canvasH: CGFloat, withSubmenu: Bool) {
    let w: CGFloat = 430
    let h: CGFloat = 654
    shadow(28, y: -9, alpha: 0.18)
    round(topRect(x, yTop, w, h, canvasH), 20, fill: C(r: 252, g: 253, b: 255, a: 0.98).ns, stroke: C(r: 100, g: 116, b: 139, a: 1).ns, width: 2)
    NSShadow().set()

    var y = yTop + 22
    for title in ["Open in New Tab", "Move to Trash"] {
        menuItem(title, x: x, yTop: y, w: w, canvasH: canvasH)
        y += 45
        if title == "Open in New Tab" { divider(x, y + 4, w, canvasH); y += 16 }
    }
    divider(x, y + 4, w, canvasH); y += 16
    for title in ["Get Info", "Rename", "Compress “Design Assets”", "Duplicate", "Make Alias", "Quick Look"] {
        menuItem(title, x: x, yTop: y, w: w, canvasH: canvasH)
        y += 45
    }
    divider(x, y + 4, w, canvasH); y += 18
    for title in ["Copy", "Share…"] {
        menuItem(title, x: x, yTop: y, w: w, canvasH: canvasH)
        y += 45
    }
    divider(x, y + 4, w, canvasH); y += 18
    menuItem("Customize Folder…", x: x, yTop: y, w: w, canvasH: canvasH); y += 45
    menuItem("Import from iPhone", x: x, yTop: y, w: w, canvasH: canvasH, arrow: true); y += 45
    menuItem("Quick Actions", x: x, yTop: y, w: w, canvasH: canvasH, arrow: true); y += 45
    menuItem("New Untitled File", x: x, yTop: y, w: w, canvasH: canvasH, arrow: true); y += 45
    menuItem("Copy Path As", x: x, yTop: y, w: w, canvasH: canvasH, selected: withSubmenu, arrow: true); y += 45
    menuItem("Services", x: x, yTop: y, w: w, canvasH: canvasH, arrow: true)

    if withSubmenu {
        let sx = x + w - 2
        let sy = yTop + 455
        let sw: CGFloat = 342
        let sh: CGFloat = 365
        shadow(24, y: -8, alpha: 0.16)
        round(topRect(sx, sy, sw, sh, canvasH), 18, fill: C(r: 252, g: 253, b: 255, a: 0.99).ns, stroke: C(r: 100, g: 116, b: 139, a: 1).ns, width: 2)
        NSShadow().set()
        var iy = sy + 18
        for title in ["Copy Path", "Quoted Path", "Shell-Escaped Path", "File URL", "Filename", "Filename Without Extension", "Parent Folder", "JSON Array", "Markdown Link"] {
            menuItem(title, x: sx, yTop: iy, w: sw, canvasH: canvasH, selected: title == "Shell-Escaped Path")
            iy += 38
        }
    }
}

func appPreviewPanel(x: CGFloat, yTop: CGFloat, w: CGFloat, h: CGFloat, canvasH: CGFloat) {
    shadow(28, y: -9, alpha: 0.12)
    round(topRect(x, yTop, w, h, canvasH), 24, fill: .white, stroke: lineColor, width: 2)
    NSShadow().set()
    text("Try a sample path", topRect(x + 44, yTop + 38, w - 88, 46, canvasH), size: 34, weight: .bold)
    text("Shell-Escaped Path", topRect(x + 44, yTop + 104, w - 88, 34, canvasH), size: 24, weight: .semibold, color: C(r: 37, g: 99, b: 235, a: 1).ns)
    round(topRect(x + 44, yTop + 154, w - 88, 70, canvasH), 13, fill: C(r: 248, g: 250, b: 252, a: 1).ns, stroke: lineColor)
    text("/Users/appleseed/Projects/app/sources/main.swift", topRect(x + 66, yTop + 176, w - 132, 32, canvasH), size: 24, weight: .medium, color: C(r: 51, g: 65, b: 85, a: 1).ns, mono: true)
    round(topRect(x + 44, yTop + 272, w - 88, 120, canvasH), 13, fill: C(r: 15, g: 23, b: 42, a: 1).ns)
    text("/Users/appleseed/Projects/app/sources/main.swift", topRect(x + 66, yTop + 314, w - 132, 34, canvasH), size: 23, weight: .medium, color: C(r: 226, g: 232, b: 240, a: 1).ns, mono: true)
}

let args = CommandLine.arguments
guard args.count == 7,
      let pixelW = Int(args[1]),
      let pixelH = Int(args[2]) else {
    fatalError("usage: render width height output mode headline caption")
}

let outputPath = args[3]
let mode = args[4]
let headline = args[5]
let caption = args[6]

let baseW: CGFloat = 2880
let baseH: CGFloat = 1800
let scale = min(CGFloat(pixelW) / baseW, CGFloat(pixelH) / baseH)

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixelW, pixelsHigh: pixelH, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = ctx
ctx.imageInterpolation = .high
ctx.cgContext.scaleBy(x: scale, y: scale)

C(r: 241, g: 248, b: 252, a: 1).ns.setFill()
NSRect(x: 0, y: 0, width: baseW, height: baseH).fill()
NSGradient(colors: [C(r: 232, g: 246, b: 253, a: 1).ns, C(r: 248, g: 251, b: 253, a: 1).ns, C(r: 218, g: 235, b: 247, a: 1).ns])!.draw(in: NSRect(x: 0, y: 0, width: baseW, height: baseH), angle: 90)

let wave = NSBezierPath()
wave.move(to: NSPoint(x: -220, y: 680))
wave.curve(to: NSPoint(x: 3100, y: 760), controlPoint1: NSPoint(x: 700, y: 1020), controlPoint2: NSPoint(x: 1900, y: 500))
wave.line(to: NSPoint(x: 3100, y: 0))
wave.line(to: NSPoint(x: -220, y: 0))
wave.close()
C(r: 50, g: 151, b: 210, a: 0.16).ns.setFill()
wave.fill()

text(headline, topRect(240, 126, 2400, 132, baseH), size: 102, weight: .bold, align: .center)
text(caption, topRect(410, 280, 2060, 56, baseH), size: 34, weight: .semibold, color: secondary, align: .center)

let stage = topRect(96, 408, 2688, 1320, baseH)
shadow(58, y: -18, alpha: 0.12)
round(stage, 40, fill: C(r: 232, g: 244, b: 250, a: 0.90).ns, stroke: C(r: 226, g: 239, b: 247, a: 1).ns, width: 2)
NSShadow().set()

switch mode {
case "context":
    let finder = finderWindow(x: 520, yTop: 500, w: 1840, h: 700, canvasH: baseH, mode: mode)
    contextMenu(x: finder.midX - 190, yTop: 720, canvasH: baseH, withSubmenu: false)
case "submenu":
    let finder = finderWindow(x: 430, yTop: 500, w: 1880, h: 700, canvasH: baseH, mode: mode)
    contextMenu(x: finder.midX - 245, yTop: 710, canvasH: baseH, withSubmenu: true)
case "preview":
    _ = finderWindow(x: 260, yTop: 520, w: 1320, h: 720, canvasH: baseH, mode: "selection")
    appPreviewPanel(x: 1640, yTop: 600, w: 900, h: 500, canvasH: baseH)
case "setup":
    _ = finderWindow(x: 260, yTop: 580, w: 1300, h: 640, canvasH: baseH, mode: "finder")
    shadow(28, y: -9, alpha: 0.12)
    round(topRect(1640, 620, 850, 420, baseH), 24, fill: .white, stroke: lineColor, width: 2)
    NSShadow().set()
    text("Copy Path As", topRect(1710, 684, 560, 58, baseH), size: 48, weight: .bold)
    text("Finder extension enabled", topRect(1712, 764, 560, 40, baseH), size: 30, weight: .semibold, color: C(r: 22, g: 163, b: 74, a: 1).ns)
    text("Adds path-copy commands to Finder.", topRect(1712, 840, 610, 42, baseH), size: 28, weight: .medium, color: secondary)
    round(topRect(1712, 956, 250, 58, baseH), 15, fill: C(r: 37, g: 99, b: 235, a: 1).ns)
    text("Open Finder", topRect(1712, 970, 250, 32, baseH), size: 25, weight: .semibold, color: .white, align: .center)
case "selection":
    _ = finderWindow(x: 500, yTop: 540, w: 1880, h: 780, canvasH: baseH, mode: "selection")
default:
    _ = finderWindow(x: 500, yTop: 540, w: 1880, h: 780, canvasH: baseH, mode: "finder")
}

guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("unable to render png") }
try png.write(to: URL(fileURLWithPath: outputPath))
SWIFT

for resolution in "${RESOLUTIONS[@]}"; do
  width="${resolution%x*}"
  height="${resolution#*x}"
  mkdir -p "$OUTPUT_DIR/$resolution"

  for item in "${ITEMS[@]}"; do
    IFS='|' read -r index mode headline caption <<<"$item"
    output="$OUTPUT_DIR/$resolution/$index.png"
    echo "Rendering $resolution/$index.png - $headline"
    "$SWIFT_BIN" "$RENDERER" "$width" "$height" "$output" "$mode" "$headline" "$caption"
  done
done

echo "Generated clean App Store screenshots in $OUTPUT_DIR"
