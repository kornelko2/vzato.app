// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import Vzato

@MainActor
struct TodaySnapshotTests {
    private let grace: TimeInterval = 2 * 60 * 60

    /// Doses at 8, 12 and 20; the 8:00 one was taken.
    private func morningTaken() -> (TestStore, Medication) {
        let store = TestStore()
        let medication = store.medication(times: [8 * 60, 12 * 60, 20 * 60])
        let slot = DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar)[0]
        DoseLogger(context: store.context, now: at(monday, 8, 5), notifier: SpyNotifier()).markTaken(slot)
        return (store, medication)
    }

    @Test func entriesAtEveryChangeOfState() {
        let (_, medication) = morningTaken()
        let entries = TodaySnapshot.entries(for: [medication], now: at(monday, 10), grace: grace, calendar: testCalendar)
        // now, 12:00 (due), 14:00 (missed), 20:00 (due), 22:00 (missed)
        #expect(entries.map(\.date) == [at(monday, 10), at(monday, 12), at(monday, 14), at(monday, 20), at(monday, 22)])
        #expect(entries.allSatisfy { $0.taken == 1 && $0.total == 3 })
    }

    @Test func featuredFollowsTheAppRule() {
        let (_, medication) = morningTaken()
        let entries = TodaySnapshot.entries(for: [medication], now: at(monday, 10), grace: grace, calendar: testCalendar)

        // 10:00: nothing overdue, next is 12:00, 20:00 waits in the list.
        #expect(entries[0].featured?.scheduledAt == at(monday, 12))
        #expect(entries[0].featured?.isOverdue == false)
        #expect(entries[0].upcoming.map(\.scheduledAt) == [at(monday, 20)])

        // 12:00: the 12:00 dose is overdue.
        #expect(entries[1].featured?.isOverdue == true)

        // 14:00: it is missed and still shown, so it can be confirmed late.
        #expect(entries[2].featured?.status == .missed)
        #expect(entries[2].featured?.scheduledAt == at(monday, 12))

        // 20:00: the evening dose is overdue and wins over the missed one.
        #expect(entries[3].featured?.scheduledAt == at(monday, 20))
    }

    @Test func allDoneWhenEverythingIsRecorded() {
        let store = TestStore()
        let medication = store.medication(times: [8 * 60])
        let slot = DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar)[0]
        DoseLogger(context: store.context, now: at(monday, 8), notifier: SpyNotifier()).markTaken(slot)
        let entries = TodaySnapshot.entries(for: [medication], now: at(monday, 9), grace: grace, calendar: testCalendar)
        #expect(entries.count == 1)
        #expect(entries[0].featured == nil)
        #expect(entries[0].taken == 1)
    }

    @Test func amountIsCarriedIntoTheWidget() {
        let store = TestStore()
        let medication = store.medication(times: [9 * 60], unitsPerDose: 20)
        medication.unitKind = .drop
        let entry = TodaySnapshot.entries(for: [medication], now: at(monday, 8), grace: grace, calendar: testCalendar)[0]
        #expect(entry.featured?.amount == medication.doseAmountText)
        #expect(entry.featured?.medicationID == medication.id)
    }

    @Test func currentDosesComeFirstAndAreMarked() {
        let store = TestStore()
        // 8:00 and 9:00 overdue at 9:30, 12:00 later.
        let medication = store.medication(times: [8 * 60, 9 * 60, 12 * 60])
        let entry = TodaySnapshot.entries(for: [medication], now: at(monday, 9, 30), grace: grace, calendar: testCalendar)[0]
        #expect(entry.featured?.scheduledAt == at(monday, 8))
        #expect(entry.featured?.isCurrent == true)
        #expect(entry.upcoming.map(\.scheduledAt) == [at(monday, 9), at(monday, 12)])
        #expect(entry.upcoming.map(\.isCurrent) == [true, false])
    }

    @Test func slotIsCurrentFromItsTimeUntilRecorded() {
        let store = TestStore()
        let medication = store.medication(times: [8 * 60])
        let slot = DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar)[0]
        #expect(!slot.isCurrent(now: at(monday, 7, 59), grace: grace))
        #expect(slot.isCurrent(now: at(monday, 8), grace: grace))
        #expect(slot.isCurrent(now: at(monday, 23), grace: grace))   // missed, still confirmable
        let event = DoseLogger(context: store.context, now: at(monday, 8), notifier: SpyNotifier()).markTaken(slot)
        let recorded = DoseSlot(medication: medication, scheduledAt: slot.scheduledAt, event: event)
        #expect(!recorded.isCurrent(now: at(monday, 9), grace: grace))
    }
}
