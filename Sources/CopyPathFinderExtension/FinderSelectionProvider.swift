import FinderSync
import Foundation
import CopyPathCore

struct FinderSelectionProvider {
    func currentSelection() -> FileSelection? {
        let controller = FIFinderSyncController.default()
        if let urls = controller.selectedItemURLs(), !urls.isEmpty {
            return FileSelection(urls)
        }
        if let targeted = controller.targetedURL() {
            return FileSelection([targeted])
        }
        return nil
    }
}

