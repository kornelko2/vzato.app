// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

@MainActor
protocol LowStockNotifying: AnyObject {
    func notifyLowStock(_ medication: Medication)
}

@MainActor
enum StockService {
    /// The user counted (or bought) pills: this becomes the new baseline for the supply check.
    static func setStock(_ medication: Medication, count: Int, at date: Date = Date()) {
        medication.tracksStock = true
        medication.stockCount = max(0, count)
        medication.stockAtLastCount = medication.stockCount
        medication.stockCountedAt = date
        if !medication.isLowStock {
            medication.lowStockNotifiedAt = nil
        }
    }

    /// Sends one low-stock notification per drop below the threshold.
    static func checkLowStock(_ medication: Medication, now: Date = Date(), notifier: any LowStockNotifying) {
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
        let units = max(1, medication.unitsPerDose)
        var day = calendar.startOfDay(for: now)
        for _ in 0..<horizonDays {
            let upcoming = DoseScheduler.slots(for: [medication], on: day, calendar: calendar)
                .filter { $0.event == nil && $0.scheduledAt >= now }
            for slot in upcoming {
                if remaining < units { return slot.scheduledAt }
                remaining -= units
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return nil
    }
}
