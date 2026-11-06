// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData

/// Records what the user did with a dose. The only place where stock changes because of a dose.
@MainActor
struct DoseLogger {
    let context: NSManagedObjectContext
    var now: Date = Date()
    var notifier: any DoseNotifying = NotificationService.shared

    @discardableResult
    func markTaken(_ slot: DoseSlot, at takenAt: Date? = nil, source: DoseSource = .app) -> DoseEvent {
        let event = slot.event ?? makeEvent(for: slot)
        set(event, status: .taken, takenAt: takenAt ?? now, source: source)
        return event
    }

    @discardableResult
    func markSkipped(_ slot: DoseSlot, source: DoseSource = .app) -> DoseEvent {
        let event = slot.event ?? makeEvent(for: slot)
        set(event, status: .skipped, takenAt: nil, source: source)
        return event
    }

    /// Removes the record so the slot is pending again (or missed, once the grace period passed).
    func reset(_ slot: DoseSlot) {
        guard let event = slot.event else { return }
        adjustStock(for: event, newStatus: .pending)
        let medication = event.medication
        context.delete(event)
        save()
        if let medication { StockService.checkLowStock(medication, now: now, notifier: notifier) }
    }

    /// A dose outside the plan, e.g. a painkiller. Counted in history and stock.
    @discardableResult
    func logExtraDose(for medication: Medication, at date: Date, source: DoseSource = .app) -> DoseEvent {
        let event = DoseEvent(context: context)
        event.isUnscheduled = true
        event.scheduledAt = date
        event.medication = medication
        set(event, status: .taken, takenAt: date, source: source)
        return event
    }

    private func set(_ event: DoseEvent, status: DoseStatus, takenAt: Date?, source: DoseSource) {
        adjustStock(for: event, newStatus: status)
        event.status = status
        event.takenAt = status == .taken ? takenAt : nil
        event.updatedAt = now
        event.source = source
        save()
        if let medication = event.medication {
            StockService.checkLowStock(medication, now: now, notifier: notifier)
        }
        if status != .pending, let scheduledAt = event.scheduledAt {
            notifier.doseResolved(medicationID: event.medication?.id, scheduledAt: scheduledAt)
        }
    }

    private func adjustStock(for event: DoseEvent, newStatus: DoseStatus) {
        guard let medication = event.medication, medication.tracksStock else { return }
        let was = event.status == .taken
        let will = newStatus == .taken
        let units = medication.effectiveUnitsPerDose
        if !was && will {
            medication.stockCount = max(0, medication.stockCount - units)
        } else if was && !will {
            medication.stockCount += units
        }
    }

    private func makeEvent(for slot: DoseSlot) -> DoseEvent {
        let event = DoseEvent(context: context)
        event.scheduledAt = slot.scheduledAt
        event.medication = slot.medication
        return event
    }

    private func save() {
        guard context.hasChanges else { return }
        do { try context.save() } catch {
            context.rollback()
            assertionFailure("Save failed: \(error)")
        }
    }
}
