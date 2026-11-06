// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData

/// Two devices can record the same dose before they have synced. After sync both records exist;
/// this keeps the preferred one (`DoseEvent.preferred`: taken wins) and deletes the others.
/// Every device decides the same way, so they converge without fighting.
///
/// The supply is not touched: each device subtracted the dose once from the same starting count and
/// the synced count is one of those results, which is correct for one physical dose.
@MainActor
enum DuplicateResolver {
    private struct Key: Hashable {
        let medication: NSManagedObjectID
        let minute: Int
    }

    /// Returns the number of records removed. Looks back `days` days; older duplicates are history.
    @discardableResult
    static func resolve(in context: NSManagedObjectContext, now: Date = Date(), days: Int = 60) -> Int {
        let request = DoseEvent.fetchRequest()
        let since = now.addingTimeInterval(-Double(days) * 86_400)
        request.predicate = NSPredicate(format: "isUnscheduled == NO AND scheduledAt >= %@", since as NSDate)
        guard let events = try? context.fetch(request) else { return 0 }

        var groups: [Key: [DoseEvent]] = [:]
        for event in events {
            guard let medication = event.medication, let at = event.scheduledAt else { continue }
            groups[Key(medication: medication.objectID, minute: Int(at.timeIntervalSince1970 / 60)), default: []].append(event)
        }

        var removed = 0
        for group in groups.values where group.count > 1 {
            guard let keep = DoseEvent.preferred(group) else { continue }
            for duplicate in group where duplicate != keep {
                let detail = String(localized: "Kept \(describe(keep)), removed \(describe(duplicate)).")
                ActivityLogger.log(.duplicateMerged, medication: keep.medication, scheduledAt: keep.scheduledAt,
                                   detail: detail, source: keep.source, in: context, at: now)
                context.delete(duplicate)
                removed += 1
            }
        }
        if removed > 0, context.hasChanges {
            do { try context.save() } catch { context.rollback() }
        }
        return removed
    }

    /// "taken at 8:05 on iPhone" / "skipped on iPad"
    private static func describe(_ event: DoseEvent) -> String {
        let status = String(localized: event.status.label)
        let device = (event.deviceName?.isEmpty == false) ? event.deviceName! : String(localized: "another device")
        if event.status == .taken, let takenAt = event.takenAt {
            return String(localized: "\(status) at \(takenAt.formatted(date: .omitted, time: .shortened)) on \(device)")
        }
        return String(localized: "\(status) on \(device)")
    }
}
