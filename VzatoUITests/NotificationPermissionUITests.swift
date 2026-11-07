// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest

/// Needs a fresh install (permission not asked yet): `xcrun simctl uninstall <udid> app.vzato` first.
final class NotificationPermissionUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testAsksForPermissionAndHidesTheWarningOnceAllowed() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-data", "--sample-data", "-AppleLanguages", "(cs)", "-AppleLocale", "cs_CZ"]
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        guard alert.waitForExistence(timeout: 10) else {
            throw XCTSkip("Permission was already decided; uninstall the app to run this test")
        }
        XCTAssertTrue(app.buttons["allowNotifications"].exists, "Today should warn while reminders are off")
        attach(app, "reminders-off")
        // The second button is "Allow" in every language.
        alert.buttons.element(boundBy: 1).tap()

        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: app.buttons["allowNotifications"])
        waitForExpectations(timeout: 10)
        attach(app, "reminders-on")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
