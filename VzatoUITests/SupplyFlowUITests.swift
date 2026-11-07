// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest

/// Reproduces a real user's setup end to end in the simulator: three tablets a day, 79 at home.
final class SupplyFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testThreeTabletsADayWith79AtHome() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-data", "--no-onboarding", "--tab", "medications", "-AppleLanguages", "(en)", "-AppleLocale", "en_GB"]
        app.launch()

        // Empty Medications screen: the big Add button.
        let add = app.buttons["addFirstMedication"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()

        let name = app.textFields["name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Testamin")

        // 08:00 is there by default; "Add time" twice gives 12:00 and 18:00.
        let addTime = app.buttons["addTime"]
        addTime.tap()
        addTime.tap()

        // Supply: switch on tracking and type 79.
        let track = app.switches["trackSupply"]
        while !track.isHittable { app.swipeUp() }
        if (track.value as? String) != "1" { track.switches.firstMatch.tap() }
        XCTAssertEqual(track.value as? String, "1")

        let stock = app.textFields["stockAmount"]
        XCTAssertTrue(stock.waitForExistence(timeout: 5))
        stock.tap()
        stock.typeText("79")
        attach(app, "form-filled")

        app.buttons["save"].tap()

        // Open the medication and read the supply section.
        let row = app.staticTexts["Testamin"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        let dosesLeft = app.descendants(matching: .any)["dosesLeft"]
        while !dosesLeft.exists || !dosesLeft.isHittable { app.swipeUp() }
        attach(app, "detail-supply")

        XCTAssertTrue(app.descendants(matching: .any)["amountAtHome"].label.contains("79"),
                      "Amount at home: \(app.descendants(matching: .any)["amountAtHome"].label)")
        XCTAssertTrue(dosesLeft.label.contains("79"), "Doses left: \(dosesLeft.label)")
        XCTAssertTrue(app.descendants(matching: .any)["runsOut"].exists, "No run-out date shown")
        XCTAssertTrue(app.descendants(matching: .any)["getMoreBy"].exists, "No get-more-by date shown")
        print("RESULT amountAtHome=\(app.descendants(matching: .any)["amountAtHome"].label)")
        print("RESULT dosesLeft=\(dosesLeft.label)")
        print("RESULT runsOut=\(app.descendants(matching: .any)["runsOut"].label)")
        print("RESULT getMoreBy=\(app.descendants(matching: .any)["getMoreBy"].label)")

        // Correcting the number later: tap the field showing 79 and type 60 — must become 60, not 6079.
        app.buttons["Edit"].tap()
        let edit = app.textFields["stockAmount"]
        while !edit.isHittable { app.swipeUp() }
        edit.tap()
        edit.typeText("60")
        app.buttons["save"].tap()
        let corrected = app.descendants(matching: .any)["amountAtHome"]
        XCTAssertTrue(corrected.waitForExistence(timeout: 5))
        XCTAssertTrue(corrected.label.contains("60") && !corrected.label.contains("6079") && !corrected.label.contains("7960"),
                      "After correction: \(corrected.label)")
        print("RESULT corrected=\(corrected.label)")

        // Supply check: 60 recorded, 57 counted -> 3 tablets missing = 3 unrecorded doses.
        let check = app.buttons["checkSupply"]
        while !check.isHittable { app.swipeUp() }
        check.tap()
        let counted = app.textFields["countedAmount"]
        XCTAssertTrue(counted.waitForExistence(timeout: 5))
        counted.tap()
        counted.typeText("57")
        XCTAssertTrue(app.staticTexts["Fewer units than the records expect."].waitForExistence(timeout: 3),
                      "The supply check shows no result after typing")
        XCTAssertTrue(app.buttons["saveCheck"].isEnabled)
        attach(app, "supply-check")
        app.buttons["saveCheck"].tap()
        let afterCheck = app.descendants(matching: .any)["amountAtHome"]
        XCTAssertTrue(afterCheck.waitForExistence(timeout: 5))
        XCTAssertTrue(afterCheck.label.contains("57"), "After supply check: \(afterCheck.label)")
        print("RESULT afterCheck=\(afterCheck.label)")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
