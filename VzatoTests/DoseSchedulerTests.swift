// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import Vzato

@MainActor
struct DoseSchedulerTests {
    @Test func generatesSlotsForEachTime() {
        let store = TestStore()
        let medication = store.medication(times: [8 * 60, 20 * 60])
        let slots = DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar)
        #expect(slots.map(\.scheduledAt) == [at(monday, 8), at(monday, 20)])
        #expect(slots.allSatisfy { $0.event == nil })
    }

    @Test func respectsWeekdays() {
        let store = TestStore()
        // Weekday 2 = Monday, 4 = Wednesday
        let medication = store.medication(times: [9 * 60], weekdays: [2, 4])
        #expect(DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar).count == 1)
        #expect(DoseScheduler.slots(for: [medication], on: days(1, after: monday), calendar: testCalendar).isEmpty)
        #expect(DoseScheduler.slots(for: [medication], on: days(2, after: monday), calendar: testCalendar).count == 1)
    }

    @Test func respectsStartAndEndDates() {
        let store = TestStore()
        let medication = store.medication(times: [9 * 60], start: days(1, after: monday), end: days(2, after: monday))
        #expect(DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar).isEmpty)
        #expect(DoseScheduler.slots(for: [medication], on: days(1, after: monday), calendar: testCalendar).count == 1)
        #expect(DoseScheduler.slots(for: [medication], on: days(2, after: monday), calendar: testCalendar).count == 1)
        #expect(DoseScheduler.slots(for: [medication], on: days(3, after: monday), calendar: testCalendar).isEmpty)
    }

    @Test func pausedAndArchivedMedicationsStopGeneratingDoses() {
        let store = TestStore()
        let medication = store.medication(times: [9 * 60])
        medication.allSchedules.first?.isPaused = true
        #expect(DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar).isEmpty)
        medication.allSchedules.first?.isPaused = false
        medication.archivedAt = days(1, after: monday)
        #expect(DoseScheduler.slots(for: [medication], on: days(1, after: monday), calendar: testCalendar).count == 1)
        #expect(DoseScheduler.slots(for: [medication], on: days(2, after: monday), calendar: testCalendar).isEmpty)
    }

    @Test func matchesRecordedEventsAndKeepsExtraDoses() {
        let store = TestStore()
        let medication = store.medication(times: [8 * 60, 20 * 60])
        let logger = DoseLogger(context: store.context, now: at(monday, 8, 5), notifier: SpyNotifier())
        let morning = DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar)[0]
        logger.markTaken(morning)
        logger.logExtraDose(for: medication, at: at(monday, 14))

        let slots = DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar)
        #expect(slots.count == 3)
        #expect(slots[0].event?.status == .taken)
        #expect(slots[1].isUnscheduled)
        #expect(slots[2].event == nil)
    }

    @Test func pendingBecomesMissedAfterGrace() {
        let store = TestStore()
        let medication = store.medication(times: [8 * 60])
        let slot = DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar)[0]
        let grace: TimeInterval = 2 * 60 * 60
        #expect(slot.status(now: at(monday, 7), grace: grace) == .pending)
        #expect(slot.isOverdue(now: at(monday, 9), grace: grace))
        #expect(slot.status(now: at(monday, 10, 1), grace: grace) == .missed)
    }

    @Test func slotsInIntervalSpanDays() {
        let store = TestStore()
        let medication = store.medication(times: [8 * 60, 20 * 60])
        let interval = DateInterval(start: monday, end: at(days(2, after: monday), 12))
        let slots = DoseScheduler.slots(for: [medication], in: interval, calendar: testCalendar)
        #expect(slots.count == 5)
    }
}
