import AppKit
import CopyPathCore
import FinderSync
import OSLog

final class FinderSync: FIFinderSync {
    private let directoryRegistry = MonitoredDirectoryRegistry()
    private let selectionProvider = FinderSelectionProvider()
    private let useCase = FormatPathsUseCase(
        formatter: PathFormatter(),
        clipboard: PasteboardClipboardService()
    )
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.vfedoroff.CopyPathAs.FinderExtension",
        category: "finder"
    )

    override init() {
        super.init()
        logger.info("Finder extension initialized")
        directoryRegistry.startObserving(NSWorkspace.shared.notificationCenter)
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        guard menuKind == .contextualMenuForItems else { return NSMenu() }

        let menu = NSMenu(title: "Copy Path As")
        let formatsMenu = NSMenu(title: "Copy Path As")
        for format in PathFormat.allCases {
            formatsMenu.addItem(makeItem(for: format))
        }
        let submenuItem = NSMenuItem(title: "Copy Path As", action: nil, keyEquivalent: "")
        menu.addItem(submenuItem)
        menu.setSubmenu(formatsMenu, for: submenuItem)
        return menu
    }

    private func makeItem(for format: PathFormat) -> NSMenuItem {
        let title = format == .path ? "Copy Path" : format.displayName
        let item = NSMenuItem(title: title, action: action(for: format), keyEquivalent: "")
        item.target = self
        return item
    }

    private func action(for format: PathFormat) -> Selector {
        switch format {
        case .path: #selector(copyPath(_:))
        case .quotedPath: #selector(copyQuotedPath(_:))
        case .shellEscapedPath: #selector(copyShellEscapedPath(_:))
        case .fileURL: #selector(copyFileURL(_:))
        case .filename: #selector(copyFilename(_:))
        case .filenameWithoutExtension: #selector(copyFilenameWithoutExtension(_:))
        case .parentFolder: #selector(copyParentFolder(_:))
        case .jsonArray: #selector(copyJSONArray(_:))
        case .markdownLink: #selector(copyMarkdownLink(_:))
        }
    }

    @objc private func copyPath(_ sender: NSMenuItem) { copySelection(as: .path) }
    @objc private func copyQuotedPath(_ sender: NSMenuItem) { copySelection(as: .quotedPath) }
    @objc private func copyShellEscapedPath(_ sender: NSMenuItem) { copySelection(as: .shellEscapedPath) }
    @objc private func copyFileURL(_ sender: NSMenuItem) { copySelection(as: .fileURL) }
    @objc private func copyFilename(_ sender: NSMenuItem) { copySelection(as: .filename) }
    @objc private func copyFilenameWithoutExtension(_ sender: NSMenuItem) { copySelection(as: .filenameWithoutExtension) }
    @objc private func copyParentFolder(_ sender: NSMenuItem) { copySelection(as: .parentFolder) }
    @objc private func copyJSONArray(_ sender: NSMenuItem) { copySelection(as: .jsonArray) }
    @objc private func copyMarkdownLink(_ sender: NSMenuItem) { copySelection(as: .markdownLink) }

    private func copySelection(as format: PathFormat) {
        guard let selection = selectionProvider.currentSelection() else {
            logger.debug("Ignoring menu action because Finder provided no selection")
            return
        }

        do {
            try useCase.execute(selection: selection, format: format)
        } catch {
            logger.error("Unable to copy formatted selection: \(error.localizedDescription, privacy: .public)")
        }
    }

}
