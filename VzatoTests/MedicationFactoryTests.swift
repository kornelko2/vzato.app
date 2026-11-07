// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import Vzato

@MainActor
struct MedicationFactoryTests {
    @Test func guideCreatesAnEveryDayMedication() throws {
        let store = TestStore()
        var draft = MedicationDraft()
        draft.name = "  Ibuprofen "
        draft.dosageText = "400 mg"
        draft.unitsPerDose = 0.5
        draft.minutes = [20 * 60, 8 * 60, 8 * 60]
        let now = at(monday, 9, 35)
        let medication = try #require(MedicationFactory.create(draft, profile: store.controller.ensureDefaultProfile(),
                                                               in: store.context, now: now, calendar: testCalendar))
        #expect(medication.name == "Ibuprofen")
        #expect(medication.dosageText == "400 mg")
        #expect(medication.unitKind == .tablet)
        #expect(medication.unitsPerDose == 0.5)
        #expect(medication.tracksStock == false)
        let schedule = try #require(medication.activeSchedules.first)
        #expect(schedule.isEveryDay)
        #expect(schedule.minutesOfDay == [8 * 60, 20 * 60])
        #expect(schedule.startDate == monday)

        // Added at 9:35: the 8:00 dose of the first day is not counted as missed.
        let slots = DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar)
        #expect(slots.map(\.scheduledAt) == [at(monday, 20)])
    }

    @Test func incompleteDraftCreatesNothing() throws {
        let store = TestStore()
        var draft = MedicationDraft()
        draft.name = "   "
        #expect(MedicationFactory.create(draft, profile: nil, in: store.context) == nil)
        draft.name = "Letrox"
        draft.minutes = []
        #expect(MedicationFactory.create(draft, profile: nil, in: store.context) == nil)
        #expect(try store.context.count(for: Medication.fetchRequest()) == 0)
    }
}
