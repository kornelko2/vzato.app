// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData

@objc(Medication)
public final class Medication: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String
    @NSManaged public var dosageText: String
    @NSManaged public var unitsPerDose: Double
    @NSManaged public var unitKindRaw: String
    @NSManaged public var notes: String
    @NSManaged public var colorHex: String
    @NSManaged public var createdAt: Date?
    @NSManaged public var isArchived: Bool
    @NSManaged public var archivedAt: Date?
    @NSManaged public var tracksStock: Bool
    @NSManaged public var stockCount: Double
    @NSManaged public var lowStockThreshold: Double
    @NSManaged public var stockCountedAt: Date?
    @NSManaged public var stockAtLastCount: Double
    @NSManaged public var lowStockNotifiedAt: Date?
    @NSManaged public var profile: Profile?
    @NSManaged public var schedules: NSSet?
    @NSManaged public var doseEvents: NSSet?
    @NSManaged public var photos: NSSet?
    /// Which photo the Today card shows: a `PhotoKind` raw value, or "none".
    @NSManaged public var shownPhotoKindRaw: String?

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

    /// The kind of photo shown on the Today card, `nil` when the user chose not to show any.
    var shownPhotoKind: PhotoKind? {
        get { shownPhotoKindRaw == Self.noPhoto ? nil : (PhotoKind(rawValue: shownPhotoKindRaw ?? "") ?? .pill) }
        set { shownPhotoKindRaw = newValue?.rawValue ?? Self.noPhoto }
    }

    static let noPhoto = "none"

    /// Photos for the Today card, following `shownPhotoKind`.
    var shownPhotos: [MedicationPhoto] {
        shownPhotoKind.map { photos(of: $0) } ?? []
    }

    func photos(of kind: PhotoKind) -> [MedicationPhoto] {
        photoList.filter { $0.kind == kind }
    }

    /// Smallest dose the app works with: a quarter tablet.
    static let minimumDoseUnits = 0.25

    var unitKind: DoseUnit {
        get { DoseUnit(rawValue: unitKindRaw) ?? .tablet }
        set { unitKindRaw = newValue.rawValue }
    }

    var effectiveUnitsPerDose: Double { max(Self.minimumDoseUnits, unitsPerDose) }

    /// "2 tablets", "20 drops", "½ tablet": what the user has to take at each dose.
    var doseAmountText: String { DoseFormatter.amount(effectiveUnitsPerDose, unit: unitKind) }

    /// Stock in the medication's own unit ("4 tablets").
    var stockAmountText: String { DoseFormatter.amount(stockCount, unit: unitKind) }
    var isLowStock: Bool { tracksStock && stockCount <= lowStockThreshold + 0.0001 }
    var isOutOfStock: Bool { tracksStock && stockCount + 0.0001 < effectiveUnitsPerDose }
    var dosesInStock: Int { tracksStock ? Int((stockCount / effectiveUnitsPerDose + 0.0001).rounded(.down)) : 0 }
}
