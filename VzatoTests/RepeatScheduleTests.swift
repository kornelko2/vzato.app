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
        let monthly = store.medication(times: [8 * 60], repeat: .months).allSchedules[0]
        let monthlyDays = NotificationService.datedReminderDays(for: monthly, now: at(monday, 9), calendar: testCalendar)
        // Today's 8:00 has passed; the next is 2 December, more than a month is never needed.
        #expect(monthlyDays.count == 2)
        #expect(monthlyDays.last == testCalendar.date(from: DateComponents(year: 2026, month: 12, day: 2)))

        let everyOther = store.medication(times: [8 * 60], repeat: .days, every: 2).allSchedules[0]
        #expect(NotificationService.datedReminderDays(for: everyOther, now: at(monday, 9), calendar: testCalendar).count == 8)
        #expect(NotificationService.datedDoseID(medicationID: nil, day: days(2, after: monday), minutes: 480, calendar: testCalendar)
                == "dose||2026-11-04|480")
    }

    @Test func descriptions() {
        #expect(Schedule.describe(kind: .months, interval: 1, weekdays: []) == String(localized: "Every month"))
        #expect(Schedule.describe(kind: .days, interval: 1, weekdays: []) == String(localized: "Every day"))
        #expect(Schedule.describe(kind: .weekdays, interval: 1, weekdays: Array(1...7)) == String(localized: "Every day"))
    }
}
