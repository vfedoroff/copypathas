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

        XCTAssertTrue(app.otherElements["settings-root"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["formats-tab"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["format-library"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.otherElements["preview-console"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.otherElements["extension-status-enabled"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Supported formats"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Format preview"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Sample path"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Formatted preview"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["format-option-markdownLink"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["sample-path-value"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["formatted-preview-value"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["sample-path-value"].label.contains("Sample Project"))
    }

    @MainActor
    func testDemoOverviewShowsExtensionEnabledBanner() {
        let app = launchApp(demoState: "overview")

        XCTAssertTrue(app.otherElements["settings-root"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["overview-tab"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["extension-status-enabled"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.otherElements["context-menu-mockup"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.otherElements["feedback-preferences"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.otherElements["doctor-card"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.otherElements["how-it-works"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Extension Not Enabled"].exists)
        XCTAssertFalse(app.buttons["Close Window"].exists)
        XCTAssertTrue(app.staticTexts["Doctor"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Refresh Status"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["build-identity"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testDemoSetupShowsExtensionDisabledBanner() {
        let app = launchApp(demoState: "setup")

        XCTAssertTrue(app.otherElements["settings-root"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["overview-tab"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["extension-status-disabled"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Extension Not Enabled"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Open Settings"].waitForExistence(timeout: 2))
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
