import FinderSync

enum FinderExtensionManager {
    static var isEnabled: Bool { FIFinderSyncController.isExtensionEnabled }
    static func showManagementInterface() { FIFinderSyncController.showExtensionManagementInterface() }
}

