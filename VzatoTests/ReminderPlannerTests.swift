// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import Vzato

@MainActor
struct ReminderPlannerTests {
    private let settings = ReminderPlanner.Settings(snoozeMinutes: 10, repeatCount: 2, missedAfterMinutes: 120)

    private func openSlots(_ store: TestStore, days: Int = 14, from start: Date = monday) -> [DoseSlot] {
        let medications = try! store.context.fetch(Medication.fetchRequest())
        let window = DateInterval(start: start, end: days_(days, after: start))
        return DoseScheduler.slots(for: medications, in: window, calendar: testCalendar).filter { $0.event == nil }
    }

    private func days_(_ n: Int, after day: Date) -> Date { days(n, after: day) }

    @Test func medicationsAtTheSameTimeShareOneReminder() {
        let store = TestStore()
        store.medication(name: "Letrox", times: [8 * 60])
        store.medication(name: "Ibalgin", times: [8 * 60, 20 * 60])
        let plan = ReminderPlanner.plan(slots: openSlots(store, days: 1), now: at(monday, 7), settings: settings, budget: 60, calendar: testCalendar)
        let morning = plan.reminders.filter { $0.minutesOfDay == 8 * 60 && $0.dayKey == "2026-11-02" }
        #expect(morning.map(\.attempt) == [0, 1, 2])
        #expect(morning.map { $0.medicationIDs.count } == [3, 3, 3].map { _ in 2 })
        #expect(morning[1].fireAt == at(monday, 8, 10))
        #expect(morning[2].fireAt == at(monday, 8, 20))
        #expect(morning[0].identifier == "dose|2026-11-02|480|0")
        let evening = plan.reminders.filter { $0.minutesOfDay == 20 * 60 && $0.dayKey == "2026-11-02" }
        #expect(evening.count == 3 && evening[0].medicationIDs.count == 1)
    }

    @Test func pastReminderStillGetsItsRemainingFollowUps() {
        let store = TestStore()
        store.medication(name: "Letrox", times: [8 * 60])
        // Opened at 8:12: the 8:00 reminder and the 8:10 follow-up are gone, 8:20 still comes.
        let plan = ReminderPlanner.plan(slots: openSlots(store, days: 1), now: at(monday, 8, 12), settings: settings, budget: 60, calendar: testCalendar)
        let today = plan.reminders.filter { $0.dayKey == "2026-11-02" }
        #expect(today.map(\.attempt) == [2])
    }

    @Test func followUpsNeverComeAfterTheDoseCountsAsMissed() {
        let store = TestStore()
        store.medication(name: "Letrox", times: [8 * 60])
        let tight = ReminderPlanner.Settings(snoozeMinutes: 60, repeatCount: 3, missedAfterMinutes: 90)
        let plan = ReminderPlanner.plan(slots: openSlots(store, days: 1), now: at(monday, 7), settings: tight, budget: 60, calendar: testCalendar)
        #expect(plan.reminders.filter { $0.dayKey == "2026-11-02" }.map(\.attempt) == [0, 1])
    }

    @Test func recordedDosesAreNotReminded() {
        let store = TestStore()
        let medication = store.medication(name: "Letrox", times: [8 * 60])
        let slot = DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar)[0]
        DoseLogger(context: store.context).markTaken(slot, at: at(monday, 7, 45))
        let plan = ReminderPlanner.plan(slots: openSlots(store, days: 2), now: at(monday, 7, 50), settings: settings, budget: 60, calendar: testCalendar)
        #expect(plan.reminders.first?.dayKey == "2026-11-03")
    }

    @Test func budgetCutsWholeGroupsAndMarksThePlanLimited() {
        let store = TestStore()
        store.medication(name: "Letrox", times: [8 * 60, 20 * 60])
        // 3 reminders per group; a budget of 7 fits two groups, not three.
        let plan = ReminderPlanner.plan(slots: openSlots(store, days: 14), now: at(monday, 7), settings: settings, budget: 7, calendar: testCalendar)
        #expect(plan.reminders.count == 6)
        #expect(plan.limited)
        #expect(plan.plannedUntil == at(monday, 20))
        let wide = ReminderPlanner.plan(slots: openSlots(store, days: 3), now: at(monday, 7), settings: settings, budget: 60, calendar: testCalendar)
        #expect(!wide.limited)
        #expect(wide.reminders.count == 3 * 2 * 3)
    }

    @Test func snoozedGroupsAreLeftToTheSnooze() {
        let store = TestStore()
        store.medication(name: "Letrox", times: [8 * 60])
        let plan = ReminderPlanner.plan(slots: openSlots(store, days: 1), now: at(monday, 7), settings: settings, budget: 60,
                                        skipping: ["2026-11-02|480"], calendar: testCalendar)
        #expect(plan.reminders.isEmpty)
    }

    @Test func dayKeysRoundTrip() {
        #expect(ReminderPlanner.dayKey(for: at(monday, 23, 59), calendar: testCalendar) == "2026-11-02")
        #expect(ReminderPlanner.day(fromKey: "2026-11-02", calendar: testCalendar) == monday)
        #expect(ReminderPlanner.day(fromKey: "nonsense", calendar: testCalendar) == nil)
    }
}
