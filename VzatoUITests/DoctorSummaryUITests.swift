// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest

final class DoctorSummaryUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testSummaryOpensAndOffersPDF() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-data", "--sample-data", "--tab", "history", "-AppleLanguages", "(cs)", "-AppleLocale", "cs_CZ"]
        app.launch()

        let entry = app.buttons["doctorSummary"]
        var swipes = 0
        while !entry.exists || !entry.isHittable {
            app.swipeUp()
            swipes += 1
            XCTAssertLessThan(swipes, 8, "No 'Summary for the doctor' entry in History")
        }
        entry.tap()

        XCTAssertTrue(app.segmentedControls["summaryPeriod"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["exportSummaryPDF"].waitForExistence(timeout: 5), "No PDF export")
        attach(app, "doctor-summary")

        app.segmentedControls["summaryPeriod"].buttons.element(boundBy: 0).tap()
        attach(app, "doctor-summary-7-days")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
