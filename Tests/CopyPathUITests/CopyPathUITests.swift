import XCTest

final class CopyPathUITests: XCTestCase {
    @MainActor
    func testSettingsWindowExposesExtensionManagement() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.buttons["Open Finder Extension Settings"].waitForExistence(timeout: 2)
        )
    }
}
