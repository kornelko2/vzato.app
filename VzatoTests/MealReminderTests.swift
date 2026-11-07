// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import Vzato

@MainActor
struct MealReminderTests {
    private func beforeMeal(_ store: TestStore, wait: Int = 30) -> Medication {
        let medication = store.medication(name: "Letrox", times: [7 * 60])
        medication.allSchedules.first?.mealRelation = .before
        medication.allSchedules.first?.mealWaitMinutes = wait
        return medication
    }

    @Test func takingABeforeMealDoseSchedulesTheMealReminder() {
        let store = TestStore()
        let medication = beforeMeal(store, wait: 45)
        let spy = SpyNotifier()
        let slot = DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar)[0]
        DoseLogger(context: store.context, now: at(monday, 7, 2), notifier: spy).markTaken(slot)
        #expect(spy.mealReady.count == 1)
        #expect(spy.mealReady.first?.name == "Letrox")
        #expect(spy.mealReady.first?.at == at(monday, 7, 47))
    }

    @Test func otherMealRelationsGetNoMealReminder() {
        let store = TestStore()
        let medication = store.medication(times: [8 * 60])
        medication.allSchedules.first?.mealRelation = .after
        let spy = SpyNotifier()
        let slot = DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar)[0]
        DoseLogger(context: store.context, now: at(monday, 8), notifier: spy).markTaken(slot)
        #expect(spy.mealReady.isEmpty)
    }

    @Test func lateRecordingDoesNotRemindAboutAMealThatIsLongPast() {
        let store = TestStore()
        let medication = beforeMeal(store)
        let spy = SpyNotifier()
        let slot = DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar)[0]
        // Confirmed at noon that it was taken at 7:00: eating was fine since 7:30.
        DoseLogger(context: store.context, now: at(monday, 12), notifier: spy).markTaken(slot, at: at(monday, 7))
        #expect(spy.mealReady.isEmpty)
    }

    @Test func resetCancelsTheMealReminder() {
        let store = TestStore()
        let medication = beforeMeal(store)
        let spy = SpyNotifier()
        let logger = DoseLogger(context: store.context, now: at(monday, 7), notifier: spy)
        let slot = DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar)[0]
        let event = logger.markTaken(slot)
        logger.reset(DoseSlot(medication: medication, scheduledAt: slot.scheduledAt, event: event))
        #expect(spy.mealCancelled.contains(at(monday, 7)))
    }

    @Test func mealReadyTimeFollowsTheIntake() {
        let store = TestStore()
        let medication = beforeMeal(store, wait: 30)
        let slot = DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar)[0]
        let event = DoseLogger(context: store.context, now: at(monday, 7, 10), notifier: SpyNotifier()).markTaken(slot)
        #expect(DoseScheduler.mealReadyTime(for: event, calendar: testCalendar) == at(monday, 7, 40))
    }
}
