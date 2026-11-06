// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// What the services need from the notification layer. Kept small so tests can use a spy.
@MainActor
protocol DoseNotifying: AnyObject {
    func notifyLowStock(_ medication: Medication)
    /// A dose was confirmed or skipped: pending follow-up reminders for it can go.
    func doseResolved(medicationID: UUID?, scheduledAt: Date)
}

extension DoseNotifying {
    func doseResolved(medicationID: UUID?, scheduledAt: Date) {}
}

@MainActor
enum StockService {
    /// The user counted (or bought) pills: this becomes the new baseline for the supply check.
    static func setStock(_ medication: Medication, count: Double, at date: Date = Date()) {
        medication.tracksStock = true
        medication.stockCount = max(0, count)
        medication.stockAtLastCount = medication.stockCount
        medication.stockCountedAt = date
        if !medication.isLowStock {
            medication.lowStockNotifiedAt = nil
        }
    }

    /// Sends one low-stock notification per drop below the threshold.
    static func checkLowStock(_ medication: Medication, now: Date = Date(), notifier: any DoseNotifying) {
        guard medication.isLowStock else {
            medication.lowStockNotifiedAt = nil
            return
        }
        guard medication.lowStockNotifiedAt == nil else { return }
        notifier.notifyLowStock(medication)
        medication.lowStockNotifiedAt = now
    }

    /// Time of the first upcoming dose that the current stock cannot cover, or nil when stock lasts
    /// through the horizon or nothing is scheduled.
    static func projectedRunOutDate(for medication: Medication, from now: Date = Date(), calendar: Calendar = .current, horizonDays: Int = 365) -> Date? {
        guard medication.tracksStock else { return nil }
        var remaining = medication.stockCount
        let units = medication.effectiveUnitsPerDose
        var day = calendar.startOfDay(for: now)
        for _ in 0..<horizonDays {
            let upcoming = DoseScheduler.slots(for: [medication], on: day, calendar: calendar)
                .filter { $0.event == nil && $0.scheduledAt >= now }
            for slot in upcoming {
                if remaining + 0.0001 < units { return slot.scheduledAt }
                remaining -= units
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return nil
    }
}
