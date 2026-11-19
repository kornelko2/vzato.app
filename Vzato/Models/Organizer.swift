// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData

/// A weekly pill organizer of one profile: its layout and where one compartment ends and the next
/// begins. It changes how doses are grouped, shown and confirmed, never the plan or the records.
@objc(Organizer)
public final class Organizer: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var layoutRaw: String
    /// Compartment boundaries as minutes of the day, comma-separated (one fewer than compartments).
    @NSManaged public var boundariesRaw: String
    @NSManaged public var isEnabled: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var profile: Profile?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "id")
        setPrimitiveValue(Date(), forKey: "createdAt")
    }

    var layout: OrganizerLayout {
        get { OrganizerLayout(rawValue: layoutRaw) ?? .week3 }
        set {
            layoutRaw = newValue.rawValue
            boundaries = newValue.defaultBoundaries
        }
    }

    /// Valid boundaries for the layout: the stored ones when they fit, the defaults otherwise.
    var boundaries: [Int] {
        get {
            let stored = boundariesRaw.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            return OrganizerLayout.isValid(stored, for: layout) ? stored : layout.defaultBoundaries
        }
        set { boundariesRaw = newValue.map(String.init).joined(separator: ",") }
    }

    /// The compartment a dose at this time of day goes into.
    func compartment(forMinutes minutes: Int) -> Compartment {
        layout.compartment(forMinutes: minutes, boundaries: boundaries)
    }

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Organizer> {
        NSFetchRequest<Organizer>(entityName: "Organizer")
    }
}

/// The common organizer types. Raw values are stored, never rename one.
enum OrganizerLayout: String, CaseIterable, Identifiable, Sendable {
    case week1, week2, week3, week4, day4
    var id: String { rawValue }

    var days: Int { self == .day4 ? 1 : 7 }

    var compartments: [Compartment] {
        switch self {
        case .week1: [.morning]
        case .week2: [.morning, .evening]
        case .week3: [.morning, .noon, .evening]
        case .week4, .day4: [.morning, .noon, .evening, .night]
        }
    }

    /// 14:00 between morning and evening; 11:00 and 17:00 for three; 10, 15 and 20 for four.
    var defaultBoundaries: [Int] {
        switch compartments.count {
        case 2: [14 * 60]
        case 3: [11 * 60, 17 * 60]
        case 4: [10 * 60, 15 * 60, 20 * 60]
        default: []
        }
    }

    var label: LocalizedStringResource {
        switch self {
        case .week1: "7 days × 1 (morning)"
        case .week2: "7 days × 2 (morning, evening)"
        case .week3: "7 days × 3 (morning, noon, evening)"
        case .week4: "7 days × 4 (morning, noon, evening, night)"
        case .day4: "1 day × 4 (refilled daily)"
        }
    }

    /// Rising, inside the day, one per gap between compartments.
    static func isValid(_ boundaries: [Int], for layout: OrganizerLayout) -> Bool {
        guard boundaries.count == layout.compartments.count - 1 else { return false }
        return zip([0] + boundaries, boundaries + [24 * 60]).allSatisfy { $0 < $1 }
    }

    func compartment(forMinutes minutes: Int, boundaries: [Int]) -> Compartment {
        let index = boundaries.firstIndex { minutes < $0 } ?? boundaries.count
        return compartments[min(index, compartments.count - 1)]
    }
}

enum Compartment: String, CaseIterable, Identifiable, Sendable, Comparable {
    case morning, noon, evening, night
    var id: String { rawValue }

    var label: LocalizedStringResource {
        switch self {
        case .morning: "Morning"
        case .noon: "Noon"
        case .evening: "Evening"
        case .night: "Night"
        }
    }

    /// "Taken: morning" on the big button and in notifications.
    var takenLabel: LocalizedStringResource {
        switch self {
        case .morning: "Taken: morning"
        case .noon: "Taken: noon"
        case .evening: "Taken: evening"
        case .night: "Taken: night"
        }
    }

    /// Notification title, e.g. "Morning: Letrox, Ibuprofen and Vitamin D".
    func reminderTitle(_ names: String) -> String {
        switch self {
        case .morning: String(localized: "Morning: \(names)")
        case .noon: String(localized: "Noon: \(names)")
        case .evening: String(localized: "Evening: \(names)")
        case .night: String(localized: "Night: \(names)")
        }
    }

    var symbolName: String {
        switch self {
        case .morning: "sunrise"
        case .noon: "sun.max"
        case .evening: "sunset"
        case .night: "moon"
        }
    }

    static func < (a: Compartment, b: Compartment) -> Bool {
        allCases.firstIndex(of: a)! < allCases.firstIndex(of: b)!
    }
}

/// Whether a medication goes into the organizer. Raw values are stored.
enum OrganizerMode: String, CaseIterable, Sendable {
    /// Tablets and capsules do, drops, liquids and the rest do not.
    case auto
    case included = "in"
    case excluded = "out"
}
