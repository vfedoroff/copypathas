import XCTest

final class CopyPathUITests: XCTestCase {
    @MainActor
    func testSettingsWindowExposesExtensionManagement() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.buttons["Open Settings"].waitForExistence(timeout: 2)
                || app.buttons["Extension Settings"].waitForExistence(timeout: 2)
        )
    }

    @MainActor
    func testDemoFormatsShowsFormatsTabAndSamplePath() {
        let app = launchApp(demoState: "formats")

        XCTAssertTrue(app.staticTexts["All set. Copy Path As is ready."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Supported formats"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Try a sample path"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Formatted preview"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["Copy"].exists)
        XCTAssertFalse(app.buttons["Copied!"].exists)
        let testPathValue = app.textFields.firstMatch.value as? String
        XCTAssertTrue(testPathValue?.contains("Sample Project") == true)
    }

    @MainActor
    func testDemoOverviewShowsExtensionEnabledBanner() {
        let app = launchApp(demoState: "overview")

        XCTAssertTrue(app.staticTexts["All set. Copy Path As is ready."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Extension Not Enabled"].exists)
        XCTAssertFalse(app.buttons["Close Window"].exists)
        XCTAssertTrue(app.staticTexts["Doctor"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Refresh Status"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["build-identity"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testDemoSetupShowsExtensionDisabledBanner() {
        let app = launchApp(demoState: "setup")

        XCTAssertTrue(app.staticTexts["Extension Not Enabled"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Open Settings"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testDemoCopiedShowsStableToast() {
        let app = launchApp(demoState: "copied")

        XCTAssertTrue(app.staticTexts["All set. Copy Path As is ready."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Supported formats"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["copied-toast-title"].waitForExistence(timeout: 2))
        let toastDetail = app.staticTexts["copied-toast-detail"]
        XCTAssertTrue(toastDetail.waitForExistence(timeout: 2))
    }

    @MainActor
    private func launchApp(demoState: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", demoState]
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
        return app
    }
}
