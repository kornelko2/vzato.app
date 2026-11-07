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

    /// Typical dose times: morning, noon, evening, night. "Add time" offers the next one that is
    /// not taken yet, then hourly after the last one, never a duplicate.
    static let suggestedMinutes = [8 * 60, 12 * 60, 18 * 60, 22 * 60]

    static func nextSuggestedMinutes(after existing: [Int]) -> Int {
        let taken = Set(existing)
        if let free = suggestedMinutes.first(where: { !taken.contains($0) }) { return free }
        var candidate = (existing.max() ?? 8 * 60) + 60
        while taken.contains(candidate % (24 * 60)) { candidate += 60 }
        return candidate % (24 * 60)
    }

    static func parse(_ raw: String) -> [Int] {
        raw.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    static func encode(_ values: [Int]) -> String {
        Array(Set(values)).sorted().map(String.init).joined(separator: ",")
    }
}
