// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData

@objc(DoseEvent)
public final class DoseEvent: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var scheduledAt: Date?
    @NSManaged public var statusRaw: String
    @NSManaged public var takenAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var sourceRaw: String
    @NSManaged public var isUnscheduled: Bool
    /// Device that recorded the dose, e.g. "iPhone", "iPad", "MacBook".
    @NSManaged public var deviceName: String?
    /// The amount taken, in `unitRaw`, saved when the dose is taken. 0 for records from before
    /// version 8 (or an older app on another device): those use the medication's current amount.
    @NSManaged public var units: Double
    @NSManaged public var unitRaw: String?
    @NSManaged public var medication: Medication?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "id")
        setPrimitiveValue(Date(), forKey: "updatedAt")
    }

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DoseEvent> {
        NSFetchRequest<DoseEvent>(entityName: "DoseEvent")
    }

    var status: DoseStatus {
        get { DoseStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    /// What was taken: the saved amount, or the medication's current one for older records.
    var takenUnits: Double {
        units > 0 ? units : (medication?.effectiveUnitsPerDose ?? Medication.minimumDoseUnits)
    }

    var takenUnit: DoseUnit {
        unitRaw.flatMap { DoseUnit(rawValue: $0) } ?? medication?.unitKind ?? .tablet
    }

    /// "½ tablet": the amount of this dose as it was taken.
    var amountText: String { DoseFormatter.amount(takenUnits, unit: takenUnit) }

    /// Saves the medication's current amount on a record that has none yet.
    func keepAmount() {
        guard units <= 0, let medication else { return }
        units = medication.effectiveUnitsPerDose
        unitRaw = medication.unitKind.rawValue
    }

    var source: DoseSource {
        get { DoseSource(rawValue: sourceRaw) ?? .app }
        set { sourceRaw = newValue.rawValue }
    }

    /// When two devices recorded the same dose before syncing, this decides which record stays.
    /// Must give the same answer on every device: taken beats skipped beats anything else, the
    /// earliest intake wins, then the earliest write, then the record id.
    static func preferred(_ events: [DoseEvent]) -> DoseEvent? {
        events.min { a, b in
            if a.status.mergeRank != b.status.mergeRank { return a.status.mergeRank > b.status.mergeRank }
            let aTaken = a.takenAt ?? .distantFuture, bTaken = b.takenAt ?? .distantFuture
            if aTaken != bTaken { return aTaken < bTaken }
            let aUpdated = a.updatedAt ?? .distantFuture, bUpdated = b.updatedAt ?? .distantFuture
            if aUpdated != bUpdated { return aUpdated < bUpdated }
            return (a.id?.uuidString ?? "") < (b.id?.uuidString ?? "")
        }
    }
}
