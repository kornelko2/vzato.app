// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData
import Foundation
import Testing
@testable import Vzato

@MainActor
struct OrganizerTests {
    private func organizer(_ store: TestStore, _ layout: OrganizerLayout = .week3) -> Organizer {
        let organizer = OrganizerService.organizer(for: store.controller.ensureDefaultProfile(), in: store.context)
        organizer.layout = layout
        organizer.isEnabled = true
        try! store.context.save()
        return organizer
    }

    @Test func layoutsSplitTheDay() {
        #expect(OrganizerLayout.week1.compartment(forMinutes: 22 * 60, boundaries: []) == .morning)
        #expect(OrganizerLayout.week2.compartment(forMinutes: 13 * 60 + 59, boundaries: [14 * 60]) == .morning)
        #expect(OrganizerLayout.week2.compartment(forMinutes: 14 * 60, boundaries: [14 * 60]) == .evening)
        let four = OrganizerLayout.week4.defaultBoundaries
        #expect([7, 12, 18, 22].map { OrganizerLayout.week4.compartment(forMinutes: $0 * 60, boundaries: four) }
            == [.morning, .noon, .evening, .night])
        #expect(OrganizerLayout.day4.days == 1)
    }

    @Test func invalidBoundariesFallBackToTheDefaults() {
        let store = TestStore()
        let organizer = organizer(store)
        organizer.boundariesRaw = "900,600"
        #expect(organizer.boundaries == [11 * 60, 17 * 60])
        organizer.boundaries = [10 * 60, 16 * 60]
        #expect(organizer.compartment(forMinutes: 15 * 60) == .noon)
        // A new layout brings its own boundaries.
        organizer.layout = .week2
        #expect(organizer.boundaries == [14 * 60])
    }

    @Test func tabletsGoInDropsStayOutUnlessChosen() {
        let store = TestStore()
        let tablets = store.medication(name: "Letrox")
        let drops = store.medication(name: "Eye drops")
        drops.unitKind = .drop
        #expect(OrganizerService.belongsInOrganizer(tablets))
        #expect(!OrganizerService.belongsInOrganizer(drops))
        drops.organizerMode = .included
        tablets.organizerMode = .excluded
        #expect(OrganizerService.belongsInOrganizer(drops))
        #expect(!OrganizerService.belongsInOrganizer(tablets))
    }

    @Test func dosesAreGroupedByCompartmentOnlyWhenEnabled() {
        let store = TestStore()
        let letrox = store.medication(name: "Letrox", times: [7 * 60])
        let ibuprofen = store.medication(name: "Ibuprofen", times: [8 * 60, 19 * 60])
        let drops = store.medication(name: "Eye drops", times: [8 * 60])
        drops.unitKind = .drop
        let all = [letrox, ibuprofen, drops]
        #expect(OrganizerService.group(DoseScheduler.slots(for: all, on: monday, calendar: testCalendar), calendar: testCalendar).groups.isEmpty)

        _ = organizer(store)
        let (groups, others) = OrganizerService.group(DoseScheduler.slots(for: all, on: monday, calendar: testCalendar), calendar: testCalendar)
        #expect(groups.map(\.compartment) == [.morning, .evening])
        #expect(groups[0].slots.map(\.medication.name) == ["Letrox", "Ibuprofen"])
        #expect(groups[0].scheduledAt == at(monday, 7))
        #expect(others.map(\.medication.name) == ["Eye drops"])
    }

    @Test func fillPlanCountsPiecesAndComparesTheSupply() {
        let store = TestStore()
        let letrox = store.medication(name: "Letrox", times: [7 * 60], stock: 4, unitsPerDose: 0.5)
        let dewormer = store.medication(name: "Dewormer", times: [8 * 60], repeat: .days, every: 3)
        let organizer = organizer(store)
        let plan = OrganizerService.fillPlan(for: organizer, medications: [letrox, dewormer], from: monday, calendar: testCalendar)
        #expect(plan.count == 7 * 3)
        #expect(plan.filter { $0.compartment == .noon }.allSatisfy { $0.items.isEmpty })
        let needs = OrganizerService.needs(in: plan)
        let letroxNeed = needs.first { $0.medication == letrox }!
        #expect(letroxNeed.units == 3.5)
        #expect(letroxNeed.stock == 4 && !letroxNeed.isShort)
        // Every third day: Monday, Thursday, Sunday.
        #expect(needs.first { $0.medication.name == "Dewormer" }?.units == 3)
        #expect(needs.first { $0.medication.name == "Dewormer" }?.stock == nil)
    }

    @Test func duplicateOrganizersFromSyncResolveTheSameWay() {
        let store = TestStore()
        let profile = store.controller.ensureDefaultProfile()
        let older = Organizer(context: store.context)
        older.profile = profile
        older.createdAt = monday
        let newer = Organizer(context: store.context)
        newer.profile = profile
        newer.createdAt = days(1, after: monday)
        #expect(profile.organizer == older)
    }
}
