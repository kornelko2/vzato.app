// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData
import Foundation

/// What the first-start guide collects: one medication taken every day at a few times.
struct MedicationDraft: Equatable, Sendable {
    var name = ""
    var dosageText = ""
    var unit = DoseUnit.tablet
    var unitsPerDose: Double = 1
    /// Times of day as minutes since midnight.
    var minutes: [Int] = [8 * 60]
    var colorHex = "1E7B46"

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isComplete: Bool { !trimmedName.isEmpty && !minutes.isEmpty && unitsPerDose > 0 }
}

/// Creates a medication with its schedule from a draft, the same way the medication form does.
@MainActor
enum MedicationFactory {
    @discardableResult
    static func create(_ draft: MedicationDraft, profile: Profile?, in context: NSManagedObjectContext,
                       now: Date = Date(), calendar: Calendar = .current) -> Medication? {
        guard draft.isComplete else { return nil }
        let medication = Medication(context: context)
        medication.name = draft.trimmedName
        medication.dosageText = draft.dosageText.trimmingCharacters(in: .whitespacesAndNewlines)
        medication.colorHex = draft.colorHex
        medication.profile = profile
        medication.createdAt = now
        medication.unitKind = draft.unit
        medication.unitsPerDose = min(draft.unit.maximumPerDose, max(Medication.minimumDoseUnits, draft.unitsPerDose))

        let schedule = Schedule(context: context)
        schedule.medication = medication
        schedule.weekdays = Array(1...7)
        schedule.minutesOfDay = Array(Set(draft.minutes.filter { (0..<(24 * 60)).contains($0) })).sorted()
        schedule.mealRelation = .any
        schedule.startDate = calendar.startOfDay(for: now)
        schedule.endDate = nil

        do {
            try context.save()
            return medication
        } catch {
            context.rollback()
            return nil
        }
    }
}
