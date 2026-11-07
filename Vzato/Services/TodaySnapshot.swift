// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// A dose as the widget shows it: plain values only, so it can cross into WidgetKit.
struct WidgetDose: Identifiable, Hashable, Sendable {
    let id: String
    let medicationID: UUID?
    let name: String
    let amount: String
    let strength: String
    let colorHex: String
    let scheduledAt: Date
    let status: DoseStatus
    let isOverdue: Bool
    /// No record yet: can still be confirmed.
    let isOpen: Bool
    /// One tap on "Taken" is safe: not more than an hour early and the same medication not taken
    /// moments ago (`DoseGuard`). Otherwise the widget shows the time instead of a button.
    let canTakeNow: Bool
    /// Due now, overdue or missed: the widget shows a Taken button for it.
    var isCurrent: Bool { isOpen && (isOverdue || status == .missed) }
}

/// What the Today widget shows at one moment.
struct TodayEntry: Sendable {
    let date: Date
    /// Same rule as the big card in the app: oldest overdue, else oldest missed, else next.
    let featured: WidgetDose?
    /// Other open doses still to come or overdue, by time.
    let upcoming: [WidgetDose]
    let taken: Int
    let total: Int
}

/// Builds widget timelines from the dose schedule. Kept out of the widget target so it is testable.
@MainActor
enum TodaySnapshot {
    /// One entry now and one at every moment the picture changes today: each open dose becomes
    /// overdue at its time and missed after the grace period.
    static func entries(for medications: [Medication], now: Date, grace: TimeInterval,
                        calendar: Calendar = .current, limit: Int = 40) -> [TodayEntry] {
        let slots = DoseScheduler.slots(for: medications, on: now, calendar: calendar)
        var moments: Set<Date> = [now]
        for slot in slots where slot.event == nil {
            if slot.scheduledAt > now { moments.insert(slot.scheduledAt) }
            let expiry = slot.scheduledAt.addingTimeInterval(grace)
            if expiry > now, calendar.isDate(expiry, inSameDayAs: now) { moments.insert(expiry) }
        }
        return moments.sorted().prefix(limit).map { entry(at: $0, slots: slots, grace: grace) }
    }

    static func entry(at date: Date, slots: [DoseSlot], grace: TimeInterval) -> TodayEntry {
        let doses = slots.map { dose(for: $0, at: date, grace: grace) }
        let open = doses.filter(\.isOpen)
        let featured = open.first(where: \.isOverdue)
            ?? open.first { $0.status == .missed }
            ?? open.first { $0.scheduledAt > date }
        // Everything else still open: current ones (overdue, missed) first, then later ones by time.
        let rest = open.filter { $0.id != featured?.id }
        let upcoming = rest.filter(\.isCurrent) + rest.filter { !$0.isCurrent && $0.status == .pending }
        return TodayEntry(date: date, featured: featured, upcoming: upcoming,
                          taken: doses.filter { $0.status == .taken }.count, total: doses.count)
    }

    static func dose(for slot: DoseSlot, at date: Date, grace: TimeInterval) -> WidgetDose {
        WidgetDose(
            id: slot.id,
            medicationID: slot.medication.id,
            name: slot.medication.name,
            amount: slot.medication.doseAmountText,
            strength: slot.medication.dosageText,
            colorHex: slot.medication.colorHex,
            scheduledAt: slot.scheduledAt,
            status: slot.status(now: date, grace: grace),
            isOverdue: slot.isOverdue(now: date, grace: grace),
            isOpen: slot.event == nil,
            canTakeNow: slot.event == nil && DoseGuard.verdict(for: slot, now: date) == .ok
        )
    }
}
