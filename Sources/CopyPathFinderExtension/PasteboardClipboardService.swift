import AppKit
import CopyPathCore

enum PasteboardClipboardError: Error {
    case writeRejected
}

struct PasteboardClipboardService: ClipboardWriting {
    func copy(_ value: String) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(value, forType: .string) else {
            throw PasteboardClipboardError.writeRejected
        }
    }
}

