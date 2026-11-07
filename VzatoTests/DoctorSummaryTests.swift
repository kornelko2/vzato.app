// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import Vzato

@MainActor
struct DoctorSummaryTests {
    private let grace: TimeInterval = 2 * 60 * 60

    @Test func countsTheLastSevenDays() {
        let store = TestStore()
        // Started a week before Monday 2 Nov; doses at 8 and 20.
        let medication = store.medication(name: "Degan", times: [8 * 60, 20 * 60], start: days(-7, after: monday), stock: 30)
        let logger = DoseLogger(context: store.context, now: at(monday, 21), notifier: SpyNotifier())
        // Last 7 days = Tue 27 Oct … Mon 2 Nov. Take all doses except: one missed, one skipped.
        for offset in -6...0 {
            let day = days(offset, after: monday)
            for slot in DoseScheduler.slots(for: [medication], on: day, calendar: testCalendar) {
                if offset == -3 && testCalendar.component(.hour, from: slot.scheduledAt) == 20 { continue }          // missed
                if offset == -1 && testCalendar.component(.hour, from: slot.scheduledAt) == 8 {
                    logger.markSkipped(slot); continue
                }
                logger.markTaken(slot, at: slot.scheduledAt)
            }
        }
        logger.logExtraDose(for: medication, at: at(days(-2, after: monday), 14))

        let summary = DoctorSummaryBuilder.build(medications: [medication], days: 7, now: at(monday, 23), grace: grace, calendar: testCalendar)
        #expect(summary.start == days(-6, after: monday))
        #expect(summary.rows.count == 1)
        let row = summary.rows[0]
        #expect(row.scheduled == 14)
        #expect(row.taken == 12)
        #expect(row.missed == 1)
        #expect(row.skipped == 1)
        #expect(row.extraDoses == 1)
        #expect(row.adherence == 12.0 / 14.0)
        #expect(row.minutesOfDay == [8 * 60, 20 * 60])
        #expect(summary.missed.map(\.scheduledAt) == [at(days(-3, after: monday), 20)])
        #expect(row.stockText != nil)
    }

    @Test func pendingDosesDoNotCountAgainstAdherence() {
        let store = TestStore()
        let medication = store.medication(times: [8 * 60, 20 * 60])
        let slot = DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar)[0]
        DoseLogger(context: store.context, now: at(monday, 8), notifier: SpyNotifier()).markTaken(slot)
        // At 9:00 the 20:00 dose is still ahead: 1 of 1 decided.
        let summary = DoctorSummaryBuilder.build(medications: [medication], days: 1, now: at(monday, 9), grace: grace, calendar: testCalendar)
        #expect(summary.rows[0].adherence == 1)
        #expect(summary.adherence == 1)
        #expect(summary.totalMissed == 0)
    }

    @Test func archivedMedicationWithoutActivityIsLeftOut() {
        let store = TestStore()
        let old = store.medication(name: "Old", times: [8 * 60], start: days(-60, after: monday))
        old.isArchived = true
        old.archivedAt = days(-30, after: monday)
        let summary = DoctorSummaryBuilder.build(medications: [old], days: 7, now: at(monday, 12), grace: grace, calendar: testCalendar)
        #expect(summary.rows.isEmpty)
    }
}
