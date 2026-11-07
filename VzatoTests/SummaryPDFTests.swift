// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreGraphics
import Foundation
import Testing
@testable import Vzato

@MainActor
struct SummaryPDFTests {
    @Test func writesAnA4PDFThatGrowsWithContent() throws {
        let store = TestStore()
        let medications = (1...12).map { index in
            store.medication(name: "Lék \(index)", times: [8 * 60, 12 * 60, 18 * 60], start: days(-40, after: monday), stock: 50)
        }
        let summary = DoctorSummaryBuilder.build(medications: medications, days: 30, now: at(monday, 20), grace: 7200, calendar: testCalendar)
        let url = try #require(SummaryPDF.write(summary))
        let document = try #require(CGPDFDocument(url as CFURL))
        #expect(document.numberOfPages >= 2, "Twelve medications and their missed doses should not fit on one page")
        let page = try #require(document.page(at: 1))
        let box = page.getBoxRect(.mediaBox)
        #expect(box.width == 595 && box.height == 842)
        // Keep a copy for a look outside the simulator when asked for.
        if let out = ProcessInfo.processInfo.environment["VZATO_PDF_OUT"] {
            try? FileManager.default.removeItem(atPath: out)
            try FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: out))
        }
    }

    @Test func emptySummaryStillMakesOnePage() throws {
        let summary = DoctorSummaryBuilder.build(medications: [], days: 7, now: at(monday, 20), grace: 7200, calendar: testCalendar)
        let url = try #require(SummaryPDF.write(summary))
        #expect(CGPDFDocument(url as CFURL)?.numberOfPages == 1)
    }
}
