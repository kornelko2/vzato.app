// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest

/// Find a medicine in the bundled SÚKL register, add it, and download its leaflet from SÚKL.
final class MedicinesDatabaseUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testAddIbalginFromTheDatabaseAndDownloadTheLeaflet() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--scratch-store", "--no-onboarding", "--tab", "medications", "--search", "ibalgin 400",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_GB"]
        app.launch()

        let add = app.buttons["addFromDatabase"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 15), "no database result for Ibalgin 400")
        add.tap()

        // The form is filled from the register.
        let name = app.textFields["name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertTrue((name.value as? String ?? "").localizedCaseInsensitiveContains("Ibalgin"), "name field: \(String(describing: name.value)); \(app.debugDescription.prefix(3000))")
        app.buttons["save"].tap()

        // Back in the list, the search now finds it under My medications as well.
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Ibalgin' AND identifier != 'addFromDatabase'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "no Ibalgin row: \(app.debugDescription.prefix(4000))")
        row.tap()

        let download = app.buttons["downloadLeaflet"]
        for _ in 0..<6 where !(download.exists && download.isHittable) { app.swipeUp() }
        XCTAssertTrue(download.exists, "no Download button: \(app.debugDescription.prefix(4000))")
        download.tap()

        // Needs the internet: SÚKL sends the PDF and the viewer opens.
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 30), "the leaflet did not download")
        done.tap()
        XCTAssertTrue(app.buttons["openLeaflet"].waitForExistence(timeout: 5))
    }
}
