// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData

/// What happened, for the activity log.
enum ActivityKind: String, CaseIterable, Sendable {
    case taken, skipped, reset, extraDose, stockCounted, supplyCheck, duplicateMerged

    var label: LocalizedStringResource {
        switch self {
        case .taken: "Taken"
        case .skipped: "Skipped"
        case .reset: "Reset"
        case .extraDose: "Extra dose"
        case .stockCounted: "Supply counted"
        case .supplyCheck: "Supply check"
        case .duplicateMerged: "Duplicate merged"
        }
    }

    var symbolName: String {
        switch self {
        case .taken: "checkmark.circle.fill"
        case .skipped: "forward.circle"
        case .reset: "arrow.uturn.backward.circle"
        case .extraDose: "plus.circle"
        case .stockCounted: "shippingbox"
        case .supplyCheck: "checklist"
        case .duplicateMerged: "arrow.triangle.merge"
        }
    }
}

/// One line of the activity log. Synced like everything else, never edited, and independent of the
/// medication record (name and id are copied) so the log survives deleting a medication.
@objc(ActivityEntry)
public final class ActivityEntry: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var date: Date?
    @NSManaged public var kindRaw: String
    @NSManaged public var medicationID: UUID?
    @NSManaged public var medicationName: String
    @NSManaged public var scheduledAt: Date?
    @NSManaged public var detail: String
    @NSManaged public var deviceName: String
    @NSManaged public var sourceRaw: String

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "id")
        setPrimitiveValue(Date(), forKey: "date")
    }

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ActivityEntry> {
        NSFetchRequest<ActivityEntry>(entityName: "ActivityEntry")
    }

    var kind: ActivityKind {
        get { ActivityKind(rawValue: kindRaw) ?? .taken }
        set { kindRaw = newValue.rawValue }
    }

    var source: DoseSource {
        get { DoseSource(rawValue: sourceRaw) ?? .app }
        set { sourceRaw = newValue.rawValue }
    }
}
