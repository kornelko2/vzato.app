// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import Vzato

/// The numbers behind the user's case: one tablet at 8, 12 and 18, 79 at home.
@MainActor
struct SupplyScenarioTests {
    @Test func threeTabletsADayWith79AtHome() {
        let store = TestStore()
        let medication = store.medication(times: [8 * 60, 12 * 60, 18 * 60], stock: 79)
        #expect(medication.dosesInStock == 79)

        // Counted on Monday 7:00: 79 tablets cover 26 full days (78) and the morning of day 27.
        let now = at(monday, 7)
        let runOut = StockService.projectedRunOutDate(for: medication, from: now, calendar: testCalendar)
        #expect(runOut == at(days(26, after: monday), 12))

        // A week earlier is the day to get more.
        let reorder = StockService.reorderDate(for: medication, from: now, calendar: testCalendar, warningDays: 7)
        #expect(reorder == days(19, after: monday))
    }

    @Test func reorderDateIsNeverInThePast() {
        let store = TestStore()
        let medication = store.medication(times: [8 * 60], stock: 2)
        let reorder = StockService.reorderDate(for: medication, from: at(monday, 7), calendar: testCalendar, warningDays: 7)
        #expect(reorder == monday)
    }

    @Test func addTimeSuggestsMorningNoonEveningNight() {
        #expect(Schedule.nextSuggestedMinutes(after: [8 * 60]) == 12 * 60)
        #expect(Schedule.nextSuggestedMinutes(after: [8 * 60, 12 * 60]) == 18 * 60)
        #expect(Schedule.nextSuggestedMinutes(after: [8 * 60, 12 * 60, 18 * 60]) == 22 * 60)
        #expect(Schedule.nextSuggestedMinutes(after: [8 * 60, 12 * 60, 18 * 60, 22 * 60]) == 23 * 60)
        #expect(Schedule.nextSuggestedMinutes(after: [7 * 60]) == 8 * 60)
    }
}
