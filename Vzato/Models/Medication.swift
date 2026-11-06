// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData

@objc(Medication)
public final class Medication: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String
    @NSManaged public var dosageText: String
    @NSManaged public var unitsPerDose: Int
    @NSManaged public var notes: String
    @NSManaged public var colorHex: String
    @NSManaged public var createdAt: Date?
    @NSManaged public var isArchived: Bool
    @NSManaged public var archivedAt: Date?
    @NSManaged public var tracksStock: Bool
    @NSManaged public var stockCount: Int
    @NSManaged public var lowStockThreshold: Int
    @NSManaged public var stockCountedAt: Date?
    @NSManaged public var stockAtLastCount: Int
    @NSManaged public var lowStockNotifiedAt: Date?
    @NSManaged public var profile: Profile?
    @NSManaged public var schedules: NSSet?
    @NSManaged public var doseEvents: NSSet?
    @NSManaged public var photos: NSSet?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "id")
        setPrimitiveValue(Date(), forKey: "createdAt")
    }

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Medication> {
        NSFetchRequest<Medication>(entityName: "Medication")
    }

    /// Schedules that currently generate doses.
    var activeSchedules: [Schedule] {
        ((schedules as? Set<Schedule>) ?? []).filter { !$0.isPaused }
    }

    var allSchedules: [Schedule] {
        Array((schedules as? Set<Schedule>) ?? [])
    }

    var eventList: [DoseEvent] {
        Array((doseEvents as? Set<DoseEvent>) ?? [])
    }

    /// Photos sorted by kind, page and creation time.
    var photoList: [MedicationPhoto] {
        ((photos as? Set<MedicationPhoto>) ?? []).sorted { a, b in
            if a.kindRaw != b.kindRaw { return a.kindRaw < b.kindRaw }
            if a.pageIndex != b.pageIndex { return a.pageIndex < b.pageIndex }
            return (a.createdAt ?? .distantPast) < (b.createdAt ?? .distantPast)
        }
    }

    func photos(of kind: PhotoKind) -> [MedicationPhoto] {
        photoList.filter { $0.kind == kind }
    }

    var isLowStock: Bool { tracksStock && stockCount <= lowStockThreshold }
    var isOutOfStock: Bool { tracksStock && stockCount < max(1, unitsPerDose) }
    var dosesInStock: Int { tracksStock ? stockCount / max(1, unitsPerDose) : 0 }
}
