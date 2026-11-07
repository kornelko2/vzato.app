// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest

/// A real user tapped "Taken" three times and recorded the whole day. That must not be possible.
final class DoubleDoseUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testRepeatedTapsDoNotTakeTheNextDoses() throws {
        let app = XCUIApplication()
        // Sample data: one overdue dose now, the next one an hour and a half away.
        app.launchArguments = ["--reset-data", "--sample-data", "--tab", "today", "-AppleLanguages", "(en)", "-AppleLocale", "en_GB"]
        app.launch()

        let taken = app.buttons["takenButton"]
        XCTAssertTrue(taken.waitForExistence(timeout: 10))
        taken.tap()

        // The card now shows the next dose, 1½ hours ahead: only its time, no button at all.
        XCTAssertTrue(app.descendants(matching: .any)["nextDoseAt"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["takenButton"].exists, "The next dose can be taken with the same tap")
        XCTAssertFalse(app.buttons["takeEarly"].exists, "A dose 1½ hours ahead offers a Taken button")
        XCTAssertTrue(app.buttons["undoTaken"].exists, "No undo after taking a dose")
        attach(app, "after-first-tap")

        // Undo brings the overdue dose back.
        app.buttons["undoTaken"].tap()
        XCTAssertTrue(app.buttons["takenButton"].waitForExistence(timeout: 3), "Undo did not restore the dose")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
