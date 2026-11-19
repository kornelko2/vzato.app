// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData
import Foundation

/// Doses of one organizer compartment on one day, e.g. Monday morning of the default profile.
struct OrganizerGroup: Identifiable {
    let profileID: NSManagedObjectID?
    let day: Date
    let compartment: Compartment
    /// Sorted by time, then name.
    let slots: [DoseSlot]

    var id: String { "\(profileID?.uriRepresentation().absoluteString ?? "")|\(day.timeIntervalSince1970)|\(compartment.rawValue)" }
    /// The earliest dose: the group is due, reminded and missed by it.
    var scheduledAt: Date { slots.map(\.scheduledAt).min() ?? day }
    var openSlots: [DoseSlot] { slots.filter { $0.event == nil } }
}

/// One cell of the fill guide: what goes into one compartment on one day.
struct OrganizerFillCell: Identifiable {
    struct Item: Identifiable {
        let medication: Medication
        let units: Double
        var id: NSManagedObjectID { medication.objectID }
    }
    let day: Date
    let compartment: Compartment
    let items: [Item]
    var id: String { "\(day.timeIntervalSince1970)|\(compartment.rawValue)" }
}

/// What the fill period needs per medication, next to the supply.
struct OrganizerNeed: Identifiable {
    let medication: Medication
    let units: Double
    /// nil when the supply is not tracked.
    let stock: Double?
    var id: NSManagedObjectID { medication.objectID }
    var isShort: Bool { stock.map { $0 + 0.0001 < units } ?? false }
}

/// Pill organizer logic without UI (specification 15).
@MainActor
enum OrganizerService {
    /// Tablets and capsules go into the organizer unless the medication says otherwise.
    static func belongsInOrganizer(_ medication: Medication) -> Bool {
        switch medication.organizerMode {
        case .included: true
        case .excluded: false
        case .auto: medication.unitKind == .tablet || medication.unitKind == .capsule
        }
    }

    /// The enabled organizer a medication's doses are grouped by, or nil.
    static func activeOrganizer(for medication: Medication) -> Organizer? {
        guard let organizer = medication.profile?.organizer, organizer.isEnabled,
              belongsInOrganizer(medication) else { return nil }
        return organizer
    }

    /// The compartment of a scheduled dose, or nil when it is not an organizer dose.
    static func compartment(of slot: DoseSlot, calendar: Calendar = .current) -> Compartment? {
        guard !slot.isUnscheduled, let organizer = activeOrganizer(for: slot.medication) else { return nil }
        let minutes = calendar.component(.hour, from: slot.scheduledAt) * 60 + calendar.component(.minute, from: slot.scheduledAt)
        return organizer.compartment(forMinutes: minutes)
    }

    /// Splits slots into organizer compartments (per profile and day) and the rest.
    static func group(_ slots: [DoseSlot], calendar: Calendar = .current) -> (groups: [OrganizerGroup], others: [DoseSlot]) {
        var buckets: [String: (profile: NSManagedObjectID?, day: Date, compartment: Compartment, slots: [DoseSlot])] = [:]
        var others: [DoseSlot] = []
        for slot in slots {
            guard let compartment = compartment(of: slot, calendar: calendar) else {
                others.append(slot)
                continue
            }
            let day = calendar.startOfDay(for: slot.scheduledAt)
            let profile = slot.medication.profile?.objectID
            let key = "\(profile?.uriRepresentation().absoluteString ?? "")|\(day.timeIntervalSince1970)|\(compartment.rawValue)"
            buckets[key, default: (profile, day, compartment, [])].slots.append(slot)
        }
        let groups = buckets.values.map { bucket in
            OrganizerGroup(profileID: bucket.profile, day: bucket.day, compartment: bucket.compartment,
                           slots: bucket.slots.sorted {
                               ($0.scheduledAt, $0.medication.name) < ($1.scheduledAt, $1.medication.name)
                           })
        }
        .sorted { ($0.scheduledAt, $0.compartment) < ($1.scheduledAt, $1.compartment) }
        return (groups, others)
    }

    /// The days the fill guide covers: the layout's days from `start`.
    static func fillDays(for organizer: Organizer, from start: Date, calendar: Calendar = .current) -> [Date] {
        let first = calendar.startOfDay(for: start)
        return (0..<organizer.layout.days).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
    }

    /// The compartments to fill, day by day, with each medication's pieces. Empty cells are kept so
    /// the grid matches the physical organizer.
    static func fillPlan(for organizer: Organizer, medications: [Medication], from start: Date,
                         calendar: Calendar = .current) -> [OrganizerFillCell] {
        let included = medications.filter { !$0.isArchived && belongsInOrganizer($0) }
        return fillDays(for: organizer, from: start, calendar: calendar).flatMap { day in
            let slots = DoseScheduler.slots(for: included, on: day, calendar: calendar).filter { !$0.isUnscheduled }
            return organizer.layout.compartments.map { compartment in
                var units: [NSManagedObjectID: (Medication, Double)] = [:]
                for slot in slots {
                    let minutes = calendar.component(.hour, from: slot.scheduledAt) * 60 + calendar.component(.minute, from: slot.scheduledAt)
                    guard organizer.compartment(forMinutes: minutes) == compartment else { continue }
                    units[slot.medication.objectID, default: (slot.medication, 0)].1 += slot.medication.effectiveUnitsPerDose
                }
                let items = units.values
                    .sorted { $0.0.name.localizedStandardCompare($1.0.name) == .orderedAscending }
                    .map { OrganizerFillCell.Item(medication: $0.0, units: $0.1) }
                return OrganizerFillCell(day: day, compartment: compartment, items: items)
            }
        }
    }

    /// Pieces per medication over the fill period, with the supply to compare.
    static func needs(in plan: [OrganizerFillCell]) -> [OrganizerNeed] {
        var totals: [NSManagedObjectID: (Medication, Double)] = [:]
        for item in plan.flatMap(\.items) {
            totals[item.medication.objectID, default: (item.medication, 0)].1 += item.units
        }
        return totals.values
            .sorted { $0.0.name.localizedStandardCompare($1.0.name) == .orderedAscending }
            .map { OrganizerNeed(medication: $0.0, units: $0.1, stock: $0.0.tracksStock ? $0.0.stockCount : nil) }
    }

    /// The organizer of a profile, created (switched off) on first use.
    static func organizer(for profile: Profile, in context: NSManagedObjectContext) -> Organizer {
        if let existing = profile.organizer { return existing }
        let organizer = Organizer(context: context)
        organizer.profile = profile
        organizer.layout = .week3
        return organizer
    }
}
