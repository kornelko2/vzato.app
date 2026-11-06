// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import Vzato

struct DoseFormatterTests {
    @Test func wholeNumbersStayPlain() {
        #expect(DoseFormatter.units(0) == "0")
        #expect(DoseFormatter.units(1) == "1")
        #expect(DoseFormatter.units(12) == "12")
    }

    @Test func quartersUseFractionGlyphs() {
        #expect(DoseFormatter.units(0.25) == "¼")
        #expect(DoseFormatter.units(0.5) == "½")
        #expect(DoseFormatter.units(0.75) == "¾")
        #expect(DoseFormatter.units(1.5) == "1½")
        #expect(DoseFormatter.units(2.25) == "2¼")
        #expect(DoseFormatter.units(9.75) == "9¾")
    }

    @Test func otherFractionsFallBackToNumbers() {
        #expect(DoseFormatter.units(1.3).hasPrefix("1"))
        #expect(DoseFormatter.units(1.3).count <= 4)
    }
}

@MainActor
struct FractionalStockTests {
    @Test func halfTabletDosesLowerStockByHalf() {
        let store = TestStore()
        let medication = store.medication(times: [8 * 60, 20 * 60], stock: 10, unitsPerDose: 0.5)
        let logger = DoseLogger(context: store.context, now: at(monday, 8), notifier: SpyNotifier())
        let slots = DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar)
        logger.markTaken(slots[0])
        #expect(medication.stockCount == 9.5)
        #expect(medication.dosesInStock == 19)
        logger.markTaken(slots[1])
        #expect(medication.stockCount == 9)
    }

    @Test func runOutAccountsForQuarterTablets() {
        let store = TestStore()
        let medication = store.medication(times: [8 * 60], stock: 1, unitsPerDose: 0.25)
        // 4 doses covered: Mon, Tue, Wed, Thu. Friday is the first uncovered one.
        let runOut = StockService.projectedRunOutDate(for: medication, from: at(monday, 7), calendar: testCalendar)
        #expect(runOut == at(days(4, after: monday), 8))
    }

    @Test func reconciliationRoundsToWholeDoses() {
        let store = TestStore()
        let medication = store.medication(times: [8 * 60], stock: 10, unitsPerDose: 0.5)
        let now = at(days(3, after: monday), 12) // 4 scheduled doses, none recorded
        let report = ReconciliationService.report(for: medication, actualStock: 8.5, now: now, calendar: testCalendar)
        #expect(report.unitDifference == 1.5)
        #expect(report.verdict == .unrecordedDoses(3))
    }
}
