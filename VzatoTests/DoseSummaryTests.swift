// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import Vzato

@MainActor
struct DoseSummaryTests {
    private let grace: TimeInterval = 2 * 60 * 60

    @Test func countsEachStatusOnce() {
        let store = TestStore()
        let medication = store.medication(times: [8 * 60, 12 * 60, 16 * 60, 20 * 60])
        let logger = DoseLogger(context: store.context, now: at(monday, 17), notifier: SpyNotifier())
        let slots = DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar)
        logger.markTaken(slots[0])
        logger.markSkipped(slots[1])
        // 16:00 is unrecorded and within grace at 17:00 (pending); 12:00 was skipped; 8:00 taken.

        let now = at(monday, 17)
        let summary = DoseSummary.summarize(DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar), now: now, grace: grace)
        #expect(summary == DaySummary(total: 4, taken: 1, skipped: 1, missed: 0, pending: 2))

        let later = DoseSummary.summarize(DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar), now: at(monday, 23), grace: grace)
        #expect(later.missed == 2)
        #expect(later.adherence == 1.0 / 4.0)
    }

    @Test func adherenceIgnoresPendingDoses() {
        var summary = DaySummary(total: 3, taken: 0, skipped: 0, missed: 0, pending: 3)
        #expect(summary.adherence == nil)
        summary.taken = 2; summary.pending = 1; summary.missed = 0
        #expect(summary.adherence == 1.0)
    }

    @Test func byDayOnlyIncludesDaysWithDoses() {
        let store = TestStore()
        // Mondays and Wednesdays only, starting Monday 2 Nov.
        let medication = store.medication(times: [9 * 60], weekdays: [2, 4])
        let monthStart = testCalendar.date(from: DateComponents(year: 2026, month: 11, day: 1))!
        let byDay = DoseSummary.byDay(medications: [medication], monthStart: monthStart, now: at(monday, 12), grace: grace, calendar: testCalendar)
        // 2, 4, 9, 11, 16, 18, 23, 25, 30 November
        #expect(byDay.count == 9)
        #expect(byDay[monday]?.missed == 1)
        #expect(byDay[days(2, after: monday)]?.pending == 1)
        #expect(byDay[days(1, after: monday)] == nil)
    }

    @Test func totalsAddUp() {
        let total = DoseSummary.total([
            DaySummary(total: 2, taken: 2, skipped: 0, missed: 0, pending: 0),
            DaySummary(total: 3, taken: 1, skipped: 1, missed: 1, pending: 0),
        ])
        #expect(total == DaySummary(total: 5, taken: 3, skipped: 1, missed: 1, pending: 0))
        #expect(total.adherence == 0.6)
    }
}
