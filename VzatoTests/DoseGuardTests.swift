// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import Vzato

/// The user's real case: 7:00, 12:00 and 19:00, one tap on "Taken" at 7:25 must not take the day.
@MainActor
struct DoseGuardTests {
    private func degan(_ store: TestStore) -> Medication {
        store.medication(name: "Degan", times: [7 * 60, 12 * 60, 19 * 60])
    }

    @Test func dueDoseIsFine() {
        let store = TestStore()
        let medication = degan(store)
        let slots = DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar)
        #expect(DoseGuard.verdict(for: slots[0], now: at(monday, 7, 25)) == .ok)
    }

    @Test func secondTapOnTheNextDoseAsksFirst() {
        let store = TestStore()
        let medication = degan(store)
        let slots = DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar)
        DoseLogger(context: store.context, now: at(monday, 7, 25), notifier: SpyNotifier()).markTaken(slots[0])
        // The 12:00 dose a moment later: taken 0 min ago, and 4½ hours early.
        #expect(DoseGuard.verdict(for: slots[1], now: at(monday, 7, 25)) == .recentlyTaken(at(monday, 7, 25)))
    }

    @Test func doseFarAheadIsTooEarlyEvenWithoutRecentIntake() {
        let store = TestStore()
        let medication = degan(store)
        let slots = DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar)
        #expect(DoseGuard.verdict(for: slots[1], now: at(monday, 9)) == .tooEarly(at(monday, 12)))
        // From 30 minutes before, one tap is enough; 45 minutes before is still too early.
        #expect(DoseGuard.verdict(for: slots[1], now: at(monday, 11, 30)) == .ok)
        #expect(DoseGuard.verdict(for: slots[1], now: at(monday, 11, 15)) == .tooEarly(at(monday, 12)))
        // Late is always fine while the dose is open.
        #expect(DoseGuard.verdict(for: slots[1], now: at(monday, 15)) == .ok)
    }

    @Test func gapIsHalfTheShortestInterval() {
        let store = TestStore()
        #expect(DoseGuard.minimumGap(for: degan(store)) == 2.5 * 3600)          // 5 h between 7 and 12
        #expect(DoseGuard.minimumGap(for: store.medication(name: "A", times: [8 * 60])) == 3 * 3600)
        #expect(DoseGuard.minimumGap(for: store.medication(name: "B", times: [8 * 60, 9 * 60])) == 3600)
    }

    @Test func normalNextDoseAfterTheGapIsFine() {
        let store = TestStore()
        let medication = degan(store)
        let slots = DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar)
        DoseLogger(context: store.context, now: at(monday, 7), notifier: SpyNotifier()).markTaken(slots[0])
        #expect(DoseGuard.verdict(for: slots[1], now: at(monday, 12)) == .ok)
    }

    @Test func extraDoseRightAfterAPlannedOneAsks() {
        let store = TestStore()
        let medication = degan(store)
        let slots = DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar)
        DoseLogger(context: store.context, now: at(monday, 7), notifier: SpyNotifier()).markTaken(slots[0])
        #expect(DoseGuard.verdictForExtraDose(of: medication, at: at(monday, 8)) == .recentlyTaken(at(monday, 7)))
        #expect(DoseGuard.verdictForExtraDose(of: medication, at: at(monday, 10)) == .ok)
    }

    @Test func widgetOffersOneTapOnlyWhenSafe() {
        let store = TestStore()
        let medication = degan(store)
        let slots = DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar)
        DoseLogger(context: store.context, now: at(monday, 7, 25), notifier: SpyNotifier()).markTaken(slots[0])
        let entry = TodaySnapshot.entries(for: [medication], now: at(monday, 7, 26), grace: 7200, calendar: testCalendar)[0]
        #expect(entry.featured?.scheduledAt == at(monday, 12))
        #expect(entry.featured?.canTakeNow == false)
    }
}
