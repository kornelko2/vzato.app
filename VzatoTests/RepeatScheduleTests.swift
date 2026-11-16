// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import Vzato

/// Plans that repeat every N days, weeks or months, counted from the start date.
@MainActor
struct RepeatScheduleTests {
    private func doseDays(_ medication: Medication, over count: Int, from start: Date = monday) -> [Int] {
        (0..<count).filter { offset in
            !DoseScheduler.slots(for: [medication], on: days(offset, after: start), calendar: testCalendar).isEmpty
        }
    }

    @Test func everyOtherDay() {
        let store = TestStore()
        let medication = store.medication(times: [8 * 60], repeat: .days, every: 2)
        #expect(doseDays(medication, over: 7) == [0, 2, 4, 6])
    }

    @Test func everyTwoWeeksFromTheStartDay() {
        let store = TestStore()
        let medication = store.medication(times: [8 * 60], start: days(1, after: monday), repeat: .weeks, every: 2)
        #expect(doseDays(medication, over: 30) == [1, 15, 29])
    }

    @Test func monthlyDewormingKeepsTheDayOfTheMonth() {
        let store = TestStore()
        // Saturday 7 November 2026, then 7 December and 7 January.
        let start = days(5, after: monday)
        let medication = store.medication(times: [8 * 60], start: start, repeat: .months)
        let next = medication.allSchedules[0].occurrenceDays(from: monday, limit: 3, calendar: testCalendar)
        let components = next.map { testCalendar.dateComponents([.month, .day], from: $0) }
        #expect(components.map(\.month) == [11, 12, 1])
        #expect(components.map(\.day) == [7, 7, 7])
        #expect(DoseScheduler.slots(for: [medication], on: days(6, after: monday), calendar: testCalendar).isEmpty)
    }

    @Test func monthlyFromThe31stFallsOnTheLastDayOfShortMonths() {
        let start = testCalendar.date(from: DateComponents(year: 2027, month: 1, day: 31))!
        let next = Schedule.occurrenceDays(kind: .months, interval: 1, weekdays: [], start: start, end: nil,
                                           from: start, limit: 3, horizonDays: 100, calendar: testCalendar)
        let components = next.map { testCalendar.dateComponents([.month, .day], from: $0) }
        #expect(components.map(\.month) == [1, 2, 3])
        #expect(components.map(\.day) == [31, 28, 31])
    }

    @Test func everyThreeMonths() {
        let next = Schedule.occurrenceDays(kind: .months, interval: 3, weekdays: [], start: monday, end: nil,
                                           from: monday, limit: 3, horizonDays: 400, calendar: testCalendar)
        #expect(next.map { testCalendar.component(.month, from: $0) } == [11, 2, 5])
    }

    @Test func nothingBeforeTheStartOrAfterTheEnd() {
        let next = Schedule.occurrenceDays(kind: .days, interval: 3, weekdays: [], start: days(2, after: monday),
                                           end: days(8, after: monday), from: monday, limit: 10, horizonDays: 30,
                                           calendar: testCalendar)
        #expect(next == [days(2, after: monday), days(5, after: monday), days(8, after: monday)])
    }

    @Test func weekdayPlansWorkAsBefore() {
        let store = TestStore()
        let medication = store.medication(times: [9 * 60], weekdays: [2, 4])
        #expect(doseDays(medication, over: 7) == [0, 2])
        #expect(medication.allSchedules[0].isEveryDay == false)
    }

    @Test func supplyRunOutCountsOnlyMonthlyDoses() {
        let store = TestStore()
        let medication = store.medication(times: [8 * 60], stock: 2, repeat: .months)
        let runOut = StockService.projectedRunOutDate(for: medication, from: at(monday, 7), calendar: testCalendar)
        // Doses on 2 Nov and 2 Dec use the two tablets; 2 Jan is the first one not covered.
        #expect(runOut == at(testCalendar.date(from: DateComponents(year: 2027, month: 1, day: 2))!, 8))
    }

    @Test func remindersArePlannedOnDatesForIntervalPlans() {
        let store = TestStore()
        let monthly = store.medication(name: "Milbemax", times: [8 * 60], repeat: .months)
        let everyOther = store.medication(name: "Letrox", times: [9 * 60], repeat: .days, every: 2)
        let now = at(monday, 9, 30)
        let window = DateInterval(start: now, end: days(13, after: monday))
        let slots = DoseScheduler.slots(for: [monthly, everyOther], in: window, calendar: testCalendar).filter { $0.event == nil }
        let settings = ReminderPlanner.Settings(snoozeMinutes: 10, repeatCount: 0, missedAfterMinutes: 120)
        let plan = ReminderPlanner.plan(slots: slots, now: now, settings: settings, budget: 60, calendar: testCalendar)
        // Today's doses are past. Milbemax comes again on 2 December, beyond the horizon, so only
        // Letrox every other day is planned, on its dates.
        #expect(plan.reminders.map(\.dayKey).prefix(3) == ["2026-11-04", "2026-11-06", "2026-11-08"])
        #expect(plan.reminders.allSatisfy { $0.medicationIDs == [everyOther.id!] && $0.minutesOfDay == 9 * 60 && $0.attempt == 0 })
        #expect(!plan.limited)
    }

    @Test func descriptions() {
        #expect(Schedule.describe(kind: .months, interval: 1, weekdays: []) == String(localized: "Every month"))
        #expect(Schedule.describe(kind: .days, interval: 1, weekdays: []) == String(localized: "Every day"))
        #expect(Schedule.describe(kind: .weekdays, interval: 1, weekdays: Array(1...7)) == String(localized: "Every day"))
    }
}

/// Daylight saving changes in Prague: 25 Oct 2026 (02:00–03:00 twice) and 28 Mar 2027 (no 02:00–03:00).
@MainActor
struct DaylightSavingTests {
    private let autumn = testCalendar.date(from: DateComponents(year: 2026, month: 10, day: 25))!
    private let spring = testCalendar.date(from: DateComponents(year: 2027, month: 3, day: 28))!

    @Test func everyDoseTimeHappensOnceOnBothChangeDays() {
        let store = TestStore()
        let medication = store.medication(times: [2 * 60 + 30, 8 * 60, 22 * 60], start: days(-30, after: autumn))
        for day in [autumn, spring] {
            let slots = DoseScheduler.slots(for: [medication], on: day, calendar: testCalendar)
            #expect(slots.count == 3)
            #expect(Set(slots.map(\.scheduledAt)).count == 3)
            #expect(slots.allSatisfy { testCalendar.isDate($0.scheduledAt, inSameDayAs: day) })
        }
    }

    @Test func remindersAcrossTheChangeKeepTheirWallClockTime() {
        let store = TestStore()
        store.medication(times: [8 * 60], start: days(-30, after: autumn))
        let window = DateInterval(start: days(-1, after: autumn), end: days(2, after: autumn))
        let slots = DoseScheduler.slots(for: store.context.registeredObjects.compactMap { $0 as? Medication }, in: window, calendar: testCalendar)
        let plan = ReminderPlanner.plan(slots: slots, now: at(days(-1, after: autumn), 0),
                                        settings: .init(snoozeMinutes: 10, repeatCount: 0, missedAfterMinutes: 120),
                                        budget: 60, calendar: testCalendar)
        #expect(plan.reminders.count == 3)
        #expect(plan.reminders.allSatisfy { testCalendar.component(.hour, from: $0.fireAt) == 8 && $0.minutesOfDay == 480 })
    }

    @Test func everyOtherDayCountsCalendarDaysNotHours() {
        let store = TestStore()
        let medication = store.medication(times: [8 * 60], start: days(-2, after: spring), repeat: .days, every: 2)
        #expect(DoseScheduler.slots(for: [medication], on: spring, calendar: testCalendar).count == 1)
        #expect(DoseScheduler.slots(for: [medication], on: days(1, after: spring), calendar: testCalendar).isEmpty)
        #expect(DoseScheduler.slots(for: [medication], on: days(2, after: spring), calendar: testCalendar).count == 1)
    }
}
