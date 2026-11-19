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
    /// SF Symbol chosen for the profile; nil means the default for its kind.
    @NSManaged public var symbolName: String?
    @NSManaged public var isDefault: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var medications: NSSet?
    @NSManaged public var organizers: NSSet?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "id")
        setPrimitiveValue(Date(), forKey: "createdAt")
    }

    var kind: ProfileKind {
        get { ProfileKind(rawValue: kindRaw) ?? .person }
        set { kindRaw = newValue.rawValue }
    }

    var symbol: String { symbolName ?? kind.defaultSymbol }

    /// The profile's pill organizer settings. Two devices may each create one before syncing;
    /// every device picks the same: the oldest, then by id.
    var organizer: Organizer? {
        ((organizers as? Set<Organizer>) ?? []).min { a, b in
            let (dateA, dateB) = (a.createdAt ?? .distantFuture, b.createdAt ?? .distantFuture)
            if dateA != dateB { return dateA < dateB }
            return (a.id?.uuidString ?? "") < (b.id?.uuidString ?? "")
        }
    }

    var medicationList: [Medication] {
        (medications as? Set<Medication>)?.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } ?? []
    }

    /// The profile marked as default ("Me"), if any.
    static func defaultProfile(in context: NSManagedObjectContext) -> Profile? {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "isDefault == YES")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    /// Whether more than one profile exists, so names need the profile to be clear.
    static func several(in context: NSManagedObjectContext?) -> Bool {
        guard let context else { return false }
        return ((try? context.count(for: Profile.fetchRequest())) ?? 0) > 1
    }

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Profile> {
        NSFetchRequest<Profile>(entityName: "Profile")
    }
}
