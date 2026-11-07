// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest

final class OnboardingUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testGuideAddsTheFirstMedication() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-data", "--onboarding", "-AppleLanguages", "(cs)", "-AppleLocale", "cs_CZ"]
        // The system permission prompt may appear; answer it so the guide can go on.
        addUIInterruptionMonitor(withDescription: "Notifications") { alert in
            alert.buttons.element(boundBy: 1).tap()
            return true
        }
        app.launch()

        let next = app.buttons["onboardingContinue"]
        XCTAssertTrue(next.waitForExistence(timeout: 10), "No guide on first start")
        attach(app, "1-welcome")
        next.tap()

        attach(app, "2-notifications")
        next.tap()
        // Lets the interruption monitor handle the system prompt.
        app.tap()

        let name = app.textFields["onboardingName"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        XCTAssertFalse(next.isEnabled, "Continue needs a name")
        name.tap()
        name.typeText("Letrox")
        attach(app, "3-name")
        next.tap()

        XCTAssertTrue(app.staticTexts["onboardingAmount"].waitForExistence(timeout: 5))
        app.buttons["Méně"].tap()
        XCTAssertEqual(app.staticTexts["onboardingAmount"].label, "½ tablety")
        attach(app, "4-amount")
        next.tap()

        let evening = app.switches["onboardingTime2"]
        XCTAssertTrue(evening.waitForExistence(timeout: 5))
        evening.switches.firstMatch.exists ? evening.switches.firstMatch.tap() : evening.tap()
        attach(app, "5-times")
        next.tap()

        XCTAssertTrue(app.staticTexts["Vše připraveno"].waitForExistence(timeout: 5))
        attach(app, "6-done")
        next.tap()

        XCTAssertFalse(app.otherElements["onboarding"].exists)
        XCTAssertTrue(app.staticTexts["Letrox"].firstMatch.waitForExistence(timeout: 5), "The new medication is not on Today")
        attach(app, "7-today")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
