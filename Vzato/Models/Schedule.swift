// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData

@objc(Schedule)
public final class Schedule: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var weekdaysRaw: String
    @NSManaged public var minutesRaw: String
    @NSManaged public var mealRelationRaw: String
    /// For "before a meal": minutes to wait after the dose before eating.
    @NSManaged public var mealWaitMinutes: Int
    @NSManaged public var startDate: Date?
    @NSManaged public var endDate: Date?
    @NSManaged public var isPaused: Bool
    @NSManaged public var medication: Medication?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "id")
        setPrimitiveValue(Calendar.current.startOfDay(for: Date()), forKey: "startDate")
    }

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Schedule> {
        NSFetchRequest<Schedule>(entityName: "Schedule")
    }

    /// Calendar weekdays, 1 = Sunday … 7 = Saturday.
    var weekdays: [Int] {
        get { Self.parse(weekdaysRaw).filter { (1...7).contains($0) } }
        set { weekdaysRaw = Self.encode(newValue) }
    }

    /// Times of day as minutes since midnight.
    var minutesOfDay: [Int] {
        get { Self.parse(minutesRaw).filter { (0..<(24 * 60)).contains($0) } }
        set { minutesRaw = Self.encode(newValue) }
    }

    var mealRelation: MealRelation {
        get { MealRelation(rawValue: mealRelationRaw) ?? .any }
        set { mealRelationRaw = newValue.rawValue }
    }

    var isEveryDay: Bool { Set(weekdays).count == 7 }

    static func parse(_ raw: String) -> [Int] {
        raw.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    static func encode(_ values: [Int]) -> String {
        Array(Set(values)).sorted().map(String.init).joined(separator: ",")
    }
}
