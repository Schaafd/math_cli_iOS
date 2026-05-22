//
//  MathCLIUITests.swift
//  MathCLIUITests
//

import XCTest

final class MathCLIUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITestMode"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testCalculatorHistoryOperationsAndSettingsFlows() throws {
        XCTAssertTrue(app.tabBars.buttons["Calculator"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Welcome to Math CLI"].waitForExistence(timeout: 5))

        let input = app.textFields["CalculatorInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("add 5 10")
        app.buttons["ExecuteButton"].tap()
        XCTAssertTrue(app.staticTexts["15"].waitForExistence(timeout: 5))

        input.tap()
        input.typeText("sq")
        XCTAssertTrue(app.buttons["sqrt"].waitForExistence(timeout: 5))
        app.buttons["DismissKeyboardButton"].tap()

        app.tabBars.buttons["History"].tap()
        let sessionRow = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'calculation'")).firstMatch
        XCTAssertTrue(sessionRow.waitForExistence(timeout: 5))
        sessionRow.tap()
        XCTAssertTrue(app.staticTexts["add 5 10"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["15"].exists)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons["Operations"].tap()
        XCTAssertTrue(app.staticTexts["Basic Arithmetic"].waitForExistence(timeout: 5))
        app.staticTexts["Basic Arithmetic"].tap()
        XCTAssertTrue(app.staticTexts["add"].waitForExistence(timeout: 5))
        app.buttons["OperationDetailToggle_add"].tap()
        XCTAssertTrue(app.staticTexts["Add two numbers: add a b"].waitForExistence(timeout: 5))

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons["Settings"].tap()
        let clearVariablesButton = app.buttons["ClearAllVariablesButton"]
        XCTAssertTrue(clearVariablesButton.waitForExistence(timeout: 5))
        clearVariablesButton.tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
    }

    @MainActor
    func testSessionCreateRenameAndSwitch() throws {
        let newSessionButton = app.buttons["NewSessionButton"]
        XCTAssertTrue(newSessionButton.waitForExistence(timeout: 5))
        newSessionButton.tap()

        let sessionTabs = app.staticTexts.matching(identifierStartingWith: "SessionTab_")
        XCTAssertGreaterThanOrEqual(sessionTabs.count, 2)

        let currentTab = sessionTabs.element(boundBy: 0)
        XCTAssertTrue(currentTab.waitForExistence(timeout: 5))
        currentTab.press(forDuration: 1.0)
        XCTAssertTrue(app.buttons["Rename"].waitForExistence(timeout: 5))
        app.buttons["Rename"].tap()

        let renameInput = app.textFields["RenameSessionInput"]
        XCTAssertTrue(renameInput.waitForExistence(timeout: 5))
        renameInput.tap()
        renameInput.clearAndTypeText("UI Renamed")
        app.buttons["SaveRenameSessionButton"].tap()

        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'UI Renamed'")).firstMatch.waitForExistence(timeout: 5))
        app.staticTexts.matching(identifierStartingWith: "SessionTab_").element(boundBy: 1).tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Switched to'")).firstMatch.waitForExistence(timeout: 5))
    }
}

private extension XCUIElementQuery {
    func matching(identifierStartingWith prefix: String) -> XCUIElementQuery {
        matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
    }
}

private extension XCUIElement {
    func clearAndTypeText(_ text: String) {
        guard let currentValue = value as? String else {
            typeText(text)
            return
        }

        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
        typeText(deleteString)
        typeText(text)
    }
}
