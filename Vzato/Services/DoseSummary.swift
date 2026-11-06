// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Counts of doses by status for one day (or any set of slots).
struct DaySummary: Equatable {
    var total = 0
    var taken = 0
    var skipped = 0
    var missed = 0
    var pending = 0

    /// Doses with a final state; pending ones do not count against adherence.
    var decided: Int { taken + missed + skipped }

    /// Share of decided doses that were taken, nil until something was decided.
    var adherence: Double? {
        decided > 0 ? Double(taken) / Double(decided) : nil
    }

    static func + (lhs: DaySummary, rhs: DaySummary) -> DaySummary {
        DaySummary(total: lhs.total + rhs.total, taken: lhs.taken + rhs.taken, skipped: lhs.skipped + rhs.skipped,
                   missed: lhs.missed + rhs.missed, pending: lhs.pending + rhs.pending)
    }
}

enum DoseSummary {
    static func summarize(_ slots: [DoseSlot], now: Date, grace: TimeInterval) -> DaySummary {
        var summary = DaySummary()
        for slot in slots {
            summary.total += 1
            switch slot.status(now: now, grace: grace) {
            case .taken: summary.taken += 1
            case .skipped: summary.skipped += 1
            case .missed: summary.missed += 1
            case .pending: summary.pending += 1
            }
        }
        return summary
    }

    /// One summary per day of the month that has at least one dose. Keys are start-of-day dates.
    static func byDay(medications: [Medication], monthStart: Date, now: Date, grace: TimeInterval, calendar: Calendar = .current) -> [Date: DaySummary] {
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [:] }
        var result: [Date: DaySummary] = [:]
        let start = calendar.startOfDay(for: monthStart)
        for offset in 0..<range.count {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let summary = summarize(DoseScheduler.slots(for: medications, on: day, calendar: calendar), now: now, grace: grace)
            if summary.total > 0 { result[day] = summary }
        }
        return result
    }

    static func total(_ summaries: [DaySummary]) -> DaySummary {
        summaries.reduce(DaySummary(), +)
    }
}
