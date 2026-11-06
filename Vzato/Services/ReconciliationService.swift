// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData

/// Compares what the app recorded since the last pill count with what the user actually has at home.
struct ReconciliationReport {
    enum Verdict: Equatable {
        case notTracking
        case needsCount
        case consistent
        /// More pills are gone than recorded: doses were taken without being confirmed.
        case unrecordedDoses(Int)
        /// Fewer pills are gone than recorded: confirmed doses may not have been taken.
        case overRecordedDoses(Int)
    }

    let medication: Medication
    let since: Date
    let scheduledDoses: Int
    let recordedTaken: Int
    let recordedSkipped: Int
    let expectedStock: Int
    let actualStock: Int?

    /// Scheduled doses with no record at all (missed or still pending).
    var unaccounted: Int { max(0, scheduledDoses - recordedTaken - recordedSkipped) }

    var unitDifference: Int? { actualStock.map { expectedStock - $0 } }

    var doseDifference: Int? {
        guard let unitDifference else { return nil }
        let units = Double(max(1, medication.unitsPerDose))
        return Int((Double(unitDifference) / units).rounded())
    }

    var verdict: Verdict {
        guard medication.tracksStock else { return .notTracking }
        guard let doseDifference else { return .needsCount }
        if doseDifference > 0 { return .unrecordedDoses(doseDifference) }
        if doseDifference < 0 { return .overRecordedDoses(-doseDifference) }
        return .consistent
    }
}

@MainActor
enum ReconciliationService {
    static func report(for medication: Medication, actualStock: Int?, now: Date = Date(), calendar: Calendar = .current) -> ReconciliationReport {
        let since = medication.stockCountedAt ?? medication.createdAt ?? now
        let interval = DateInterval(start: min(since, now), end: now)
        let scheduled = DoseScheduler.slots(for: [medication], in: interval, calendar: calendar)
            .filter { !$0.isUnscheduled }
            .count
        let events = medication.eventList
        let taken = events.filter { event in
            guard event.status == .taken else { return false }
            let at = event.takenAt ?? event.scheduledAt ?? now
            return interval.contains(at)
        }.count
        let skipped = events.filter { event in
            guard event.status == .skipped, let at = event.scheduledAt else { return false }
            return interval.contains(at)
        }.count
        let units = max(1, medication.unitsPerDose)
        let expected = medication.tracksStock ? max(0, medication.stockAtLastCount - taken * units) : 0
        return ReconciliationReport(
            medication: medication,
            since: since,
            scheduledDoses: scheduled,
            recordedTaken: taken,
            recordedSkipped: skipped,
            expectedStock: expected,
            actualStock: actualStock
        )
    }

    /// Saves the counted stock. Optionally marks the oldest unaccounted scheduled doses as taken
    /// (source: reconciliation) to match the count. Never removes records.
    static func apply(_ report: ReconciliationReport, actualStock: Int, recordMissingDoses: Bool, context: NSManagedObjectContext, now: Date = Date(), calendar: Calendar = .current, notifier: any DoseNotifying) {
        let medication = report.medication
        if recordMissingDoses, case .unrecordedDoses(let count) = ReconciliationReport(
            medication: medication, since: report.since, scheduledDoses: report.scheduledDoses,
            recordedTaken: report.recordedTaken, recordedSkipped: report.recordedSkipped,
            expectedStock: report.expectedStock, actualStock: actualStock
        ).verdict {
            let interval = DateInterval(start: min(report.since, now), end: now)
            let open = DoseScheduler.slots(for: [medication], in: interval, calendar: calendar)
                .filter { $0.event == nil }
                .prefix(count)
            let logger = DoseLogger(context: context, now: now, notifier: notifier)
            for slot in open {
                logger.markTaken(slot, at: slot.scheduledAt, source: .reconciliation)
            }
        }
        StockService.setStock(medication, count: actualStock, at: now)
        if context.hasChanges { try? context.save() }
    }
}
