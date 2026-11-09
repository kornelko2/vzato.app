// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// What a doctor needs to see in two minutes: what the person takes, how regularly, what was missed
/// and how much is left. Facts only, no interpretation (Vzato is not a medical device).
struct DoctorSummary {
    struct Row: Identifiable {
        let id: String
        let name: String
        let strength: String
        let amountPerDose: String
        /// "Every day", "Mon, Thu", "Every month".
        let repeatText: String
        let minutesOfDay: [Int]
        let mealRelation: MealRelation
        let scheduled: Int
        let taken: Int
        let missed: Int
        let skipped: Int
        let extraDoses: Int
        let stockText: String?
        let runOut: Date?

        /// Taken out of the doses that are decided (taken, missed or skipped); nil without any.
        var adherence: Double? {
            let decided = taken + missed + skipped
            return decided > 0 ? Double(taken) / Double(decided) : nil
        }
    }

    struct MissedDose: Identifiable {
        let id: String
        let name: String
        let scheduledAt: Date
    }

    let start: Date
    let end: Date
    let generatedAt: Date
    let rows: [Row]
    let missed: [MissedDose]
    /// Whose summary it is, when there are several profiles and one is chosen.
    var profileName: String?

    var totalTaken: Int { rows.reduce(0) { $0 + $1.taken } }
    var totalMissed: Int { rows.reduce(0) { $0 + $1.missed } }
    var totalSkipped: Int { rows.reduce(0) { $0 + $1.skipped } }
    var adherence: Double? {
        let decided = totalTaken + totalMissed + totalSkipped
        return decided > 0 ? Double(totalTaken) / Double(decided) : nil
    }
}

@MainActor
enum DoctorSummaryBuilder {
    /// The last `days` days up to `now`, today included.
    static func build(medications: [Medication], days: Int, now: Date = Date(), grace: TimeInterval,
                      calendar: Calendar = .current, missedLimit: Int = 40) -> DoctorSummary {
        let start = calendar.date(byAdding: .day, value: -(max(1, days) - 1), to: calendar.startOfDay(for: now)) ?? now
        let interval = DateInterval(start: start, end: now)
        var rows: [DoctorSummary.Row] = []
        var missed: [DoctorSummary.MissedDose] = []

        for medication in medications.sorted(by: { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) {
            let slots = DoseScheduler.slots(for: [medication], in: interval, calendar: calendar)
            let planned = slots.filter { !$0.isUnscheduled }
            var taken = 0, missedCount = 0, skipped = 0
            for slot in planned {
                switch slot.status(now: now, grace: grace) {
                case .taken: taken += 1
                case .missed:
                    missedCount += 1
                    missed.append(.init(id: slot.id, name: medication.name, scheduledAt: slot.scheduledAt))
                case .skipped: skipped += 1
                case .pending: break
                }
            }
            let extra = slots.filter { $0.isUnscheduled && $0.event?.status == .taken }.count
            // A medication archived before the period and never taken in it is not worth listing.
            if planned.isEmpty && extra == 0 && medication.isArchived { continue }
            let schedule = medication.activeSchedules.first ?? medication.allSchedules.first
            rows.append(.init(
                id: medication.id?.uuidString ?? medication.name,
                name: medication.name,
                strength: medication.dosageText,
                amountPerDose: medication.doseAmountText,
                repeatText: schedule?.repeatDescription(calendar: calendar) ?? "",
                minutesOfDay: (schedule?.minutesOfDay ?? []).sorted(),
                mealRelation: schedule?.mealRelation ?? .any,
                scheduled: planned.count,
                taken: taken,
                missed: missedCount,
                skipped: skipped,
                extraDoses: extra,
                stockText: medication.tracksStock ? medication.stockAmountText : nil,
                runOut: StockService.projectedRunOutDate(for: medication, from: now, calendar: calendar)
            ))
        }
        missed.sort { $0.scheduledAt > $1.scheduledAt }
        return DoctorSummary(start: start, end: now, generatedAt: now, rows: rows, missed: Array(missed.prefix(missedLimit)))
    }
}
