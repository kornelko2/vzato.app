// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData

@objc(Profile)
public final class Profile: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String
    @NSManaged public var kindRaw: String
    @NSManaged public var colorHex: String?
    @NSManaged public var isDefault: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var medications: NSSet?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "id")
        setPrimitiveValue(Date(), forKey: "createdAt")
    }

    var kind: ProfileKind {
        get { ProfileKind(rawValue: kindRaw) ?? .person }
        set { kindRaw = newValue.rawValue }
    }

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Profile> {
        NSFetchRequest<Profile>(entityName: "Profile")
    }
}
