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
    @NSManaged public var repeatKindRaw: String
    /// N in "every N days / weeks / months"; ignored for weekdays.
    @NSManaged public var repeatIntervalCount: Int
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

    var isEveryDay: Bool { repeatKind == .weekdays && Set(weekdays).count == 7 }

    var repeatKind: RepeatKind {
        get { RepeatKind(rawValue: repeatKindRaw) ?? .weekdays }
        set { repeatKindRaw = newValue.rawValue }
    }

    var repeatInterval: Int {
        get { max(1, repeatIntervalCount) }
        set { repeatIntervalCount = max(1, newValue) }
    }

    /// Whether the plan has doses on this day, by its repeat rule only (start, end and pause are
    /// checked by `DoseScheduler`). Intervals count from the start date; "every month" keeps the
    /// start's day of the month and falls back to the month's last day (31 Jan → 28 Feb → 31 Mar).
    func occurs(on day: Date, calendar: Calendar) -> Bool {
        Self.occurs(kind: repeatKind, interval: repeatInterval, weekdays: weekdays, start: startDate, on: day, calendar: calendar)
    }

    /// The next days with doses, from `day` on (inclusive), at most `limit`, looking `horizonDays` ahead.
    func occurrenceDays(from day: Date, limit: Int, horizonDays: Int = 400, calendar: Calendar) -> [Date] {
        Self.occurrenceDays(kind: repeatKind, interval: repeatInterval, weekdays: weekdays, start: startDate, end: endDate,
                            from: day, limit: limit, horizonDays: horizonDays, calendar: calendar)
    }

    static func occurs(kind: RepeatKind, interval: Int, weekdays: [Int], start: Date?, on day: Date, calendar: Calendar) -> Bool {
        let day = calendar.startOfDay(for: day)
        switch kind {
        case .weekdays:
            return weekdays.contains(calendar.component(.weekday, from: day))
        case .days, .weeks:
            guard let start else { return interval == 1 && kind == .days }
            let step = kind == .days ? interval : interval * 7
            guard let offset = calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: day).day,
                  offset >= 0 else { return false }
            return offset % step == 0
        case .months:
            guard let start else { return false }
            let anchor = calendar.startOfDay(for: start)
            let a = calendar.dateComponents([.year, .month], from: anchor)
            let d = calendar.dateComponents([.year, .month], from: day)
            guard let ay = a.year, let am = a.month, let dy = d.year, let dm = d.month else { return false }
            let months = (dy - ay) * 12 + (dm - am)
            guard months >= 0, months % interval == 0,
                  let expected = calendar.date(byAdding: .month, value: months, to: anchor) else { return false }
            return calendar.isDate(expected, inSameDayAs: day)
        }
    }

    static func occurrenceDays(kind: RepeatKind, interval: Int, weekdays: [Int], start: Date?, end: Date?,
                               from day: Date, limit: Int, horizonDays: Int, calendar: Calendar) -> [Date] {
        var result: [Date] = []
        var current = calendar.startOfDay(for: day)
        if let start, current < calendar.startOfDay(for: start) { current = calendar.startOfDay(for: start) }
        let lastDay = end.map { calendar.startOfDay(for: $0) }
        for _ in 0..<max(0, horizonDays) {
            if result.count >= limit { break }
            if let lastDay, current > lastDay { break }
            if occurs(kind: kind, interval: interval, weekdays: weekdays, start: start, on: current, calendar: calendar) {
                result.append(current)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return result
    }

    /// "Every day", "Mon, Wed, Fri", "Every 2 days", "Every month".
    func repeatDescription(calendar: Calendar = .current) -> String {
        Self.describe(kind: repeatKind, interval: repeatInterval, weekdays: weekdays, calendar: calendar)
    }

    static func describe(kind: RepeatKind, interval: Int, weekdays: [Int], calendar: Calendar = .current) -> String {
        let repeatInterval = max(1, interval)
        switch kind {
        case .weekdays:
            if Set(weekdays).count == 7 { return String(localized: "Every day") }
            let order = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
            return order.filter { weekdays.contains($0) }
                .map { calendar.shortStandaloneWeekdaySymbols[$0 - 1] }
                .joined(separator: ", ")
        case .days:
            return repeatInterval == 1 ? String(localized: "Every day") : String(localized: "Every \(repeatInterval) days")
        case .weeks:
            return repeatInterval == 1 ? String(localized: "Every week") : String(localized: "Every \(repeatInterval) weeks")
        case .months:
            return repeatInterval == 1 ? String(localized: "Every month") : String(localized: "Every \(repeatInterval) months")
        }
    }

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
