import FinderSync
import Foundation
import CopyPathCore

struct FinderSelectionProvider {
    func currentSelection() -> FileSelection? {
        guard let urls = FIFinderSyncController.default().selectedItemURLs() else { return nil }
        return FileSelection(urls)
    }
}

