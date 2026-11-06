// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import Vzato

@MainActor
struct StockTests {
    @Test func takingLowersStockAndResetRestoresIt() {
        let store = TestStore()
        let medication = store.medication(stock: 10, unitsPerDose: 2)
        let logger = DoseLogger(context: store.context, now: at(monday, 8), notifier: SpyNotifier())
        let slot = DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar)[0]

        let event = logger.markTaken(slot)
        #expect(medication.stockCount == 8)

        logger.markSkipped(DoseSlot(medication: medication, scheduledAt: slot.scheduledAt, event: event))
        #expect(medication.stockCount == 10)

        logger.markTaken(DoseSlot(medication: medication, scheduledAt: slot.scheduledAt, event: event))
        #expect(medication.stockCount == 8)

        logger.reset(DoseSlot(medication: medication, scheduledAt: slot.scheduledAt, event: event))
        #expect(medication.stockCount == 10)
        #expect(medication.eventList.isEmpty)
    }

    @Test func lowStockNotifiesOnceUntilRefilled() {
        let store = TestStore()
        let medication = store.medication(stock: 6)
        medication.lowStockThreshold = 5
        let notifier = SpyNotifier()
        let logger = DoseLogger(context: store.context, now: at(monday, 8), notifier: notifier)
        let slots = DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar)

        logger.markTaken(slots[0]) // 5 left: at threshold
        #expect(notifier.lowStockNames == ["Ibuprofen"])
        logger.markTaken(slots[1]) // 4 left: no second notification
        #expect(notifier.lowStockNames.count == 1)

        StockService.setStock(medication, count: 30, at: at(monday, 21))
        #expect(medication.lowStockNotifiedAt == nil)
        medication.stockCount = 5
        StockService.checkLowStock(medication, now: at(monday, 22), notifier: notifier)
        #expect(notifier.lowStockNames.count == 2)
    }

    @Test func projectedRunOutIsFirstUncoveredDose() {
        let store = TestStore()
        let medication = store.medication(times: [8 * 60, 20 * 60], stock: 3)
        let runOut = StockService.projectedRunOutDate(for: medication, from: at(monday, 7), calendar: testCalendar)
        // Doses at Mon 8, Mon 20, Tue 8 are covered; Tue 20 is the first that is not.
        #expect(runOut == at(days(1, after: monday), 20))
    }

    @Test func noRunOutWithoutStockTrackingOrSchedule() {
        let store = TestStore()
        let untracked = store.medication(name: "A")
        #expect(StockService.projectedRunOutDate(for: untracked, from: monday, calendar: testCalendar) == nil)
        let plenty = store.medication(name: "B", times: [8 * 60], stock: 1000)
        #expect(StockService.projectedRunOutDate(for: plenty, from: monday, calendar: testCalendar) == nil)
    }
}
