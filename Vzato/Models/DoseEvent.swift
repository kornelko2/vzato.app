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

    var source: DoseSource {
        get { DoseSource(rawValue: sourceRaw) ?? .app }
        set { sourceRaw = newValue.rawValue }
    }
}
