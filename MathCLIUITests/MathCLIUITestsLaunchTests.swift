//
//  MathCLIUITestsLaunchTests.swift
//  MathCLIUITests
//

import XCTest

final class MathCLIUITestsLaunchTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsCalculator() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Calculator"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["CalculatorInput"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Welcome to Math CLI"].exists)
    }
}
