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
    func reset(_ slot: DoseSlot, source: DoseSource = .app) {
        guard let event = slot.event else { return }
        ActivityLogger.log(.reset, medication: event.medication, scheduledAt: event.scheduledAt,
                           detail: String(localized: "Previously \(String(localized: event.status.label)).", locale: .current),
                           source: source, in: context, at: now)
        adjustStock(for: event, newStatus: .pending)
        let medication = event.medication
        if let scheduledAt = event.scheduledAt {
            notifier.cancelMealReady(medicationID: medication?.id, scheduledAt: scheduledAt)
        }
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
        set(event, status: .taken, takenAt: date, source: source, kind: .extraDose)
        return event
    }

    private func set(_ event: DoseEvent, status: DoseStatus, takenAt: Date?, source: DoseSource, kind: ActivityKind? = nil) {
        adjustStock(for: event, newStatus: status)
        event.status = status
        event.takenAt = status == .taken ? takenAt : nil
        event.updatedAt = now
        event.source = source
        event.deviceName = DeviceInfo.name
        let logKind = kind ?? (status == .taken ? .taken : .skipped)
        let detail = status == .taken && takenAt.map({ abs($0.timeIntervalSince(now)) > 60 }) == true
            ? String(localized: "Recorded later, taken at \(takenAt!.formatted(date: .abbreviated, time: .shortened)).")
            : ""
        ActivityLogger.log(logKind, medication: event.medication, scheduledAt: event.scheduledAt,
                           detail: detail, source: source, in: context, at: now)
        save()
        if let medication = event.medication {
            StockService.checkLowStock(medication, now: now, notifier: notifier)
        }
        if status != .pending, let scheduledAt = event.scheduledAt {
            notifier.doseResolved(medicationID: event.medication?.id, scheduledAt: scheduledAt)
            notifier.cancelMealReady(medicationID: event.medication?.id, scheduledAt: scheduledAt)
            // Before a meal: remind when eating is fine. Skipped for doses recorded too late to matter.
            if let readyAt = DoseScheduler.mealReadyTime(for: event), readyAt > now,
               let medication = event.medication,
               let wait = DoseScheduler.schedule(of: medication, at: scheduledAt)?.mealWaitMinutes {
                notifier.scheduleMealReady(medicationID: medication.id, name: medication.name,
                                           scheduledAt: scheduledAt, at: readyAt, waitMinutes: wait)
            }
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
