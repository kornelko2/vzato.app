// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData

enum PhotoKind: String, CaseIterable, Identifiable, Sendable {
    case package, pill, leaflet
    var id: String { rawValue }

    var label: LocalizedStringResource {
        switch self {
        case .package: "Package"
        case .pill: "Pill"
        case .leaflet: "Leaflet"
        }
    }

    var symbolName: String {
        switch self {
        case .package: "shippingbox"
        case .pill: "pill"
        case .leaflet: "doc.text"
        }
    }

    /// Leaflets have several pages; the other kinds usually one photo, but more is allowed.
    var maxSelection: Int { self == .leaflet ? 20 : 4 }
}

@objc(MedicationPhoto)
public final class MedicationPhoto: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var kindRaw: String
    @NSManaged public var pageIndex: Int
    @NSManaged public var imageData: Data?
    @NSManaged public var createdAt: Date?
    @NSManaged public var medication: Medication?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "id")
        setPrimitiveValue(Date(), forKey: "createdAt")
    }

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MedicationPhoto> {
        NSFetchRequest<MedicationPhoto>(entityName: "MedicationPhoto")
    }

    var kind: PhotoKind {
        get { PhotoKind(rawValue: kindRaw) ?? .package }
        set { kindRaw = newValue.rawValue }
    }
}

extension MedicationPhoto: Identifiable {}
