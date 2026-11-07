// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Protects against the most dangerous mistake: taking a medication twice. Every "Taken" action
/// that is not obviously right asks first. The app never refuses; it makes the person look twice.
enum DoseGuard {
    /// A dose may be confirmed with one tap from this long before its time (and any time after,
    /// while it is still open). Further ahead the card shows only the time.
    static let earlyWindow: TimeInterval = 30 * 60

    enum Verdict: Equatable {
        case ok
        /// The same medication was taken at this time, too recently for another dose.
        case recentlyTaken(Date)
        /// The dose is planned for this time, more than `earlyWindow` from now.
        case tooEarly(Date)
    }

    /// Recently taken wins over too early: a second dose is the bigger danger.
    @MainActor
    static func verdict(for slot: DoseSlot, now: Date) -> Verdict {
        if let last = lastTaken(of: slot.medication, before: now, excluding: slot.event),
           now.timeIntervalSince(last) < minimumGap(for: slot.medication) {
            return .recentlyTaken(last)
        }
        if slot.scheduledAt.timeIntervalSince(now) > earlyWindow {
            return .tooEarly(slot.scheduledAt)
        }
        return .ok
    }

    /// For an extra dose outside the plan only the "recently taken" part applies.
    @MainActor
    static func verdictForExtraDose(of medication: Medication, at date: Date) -> Verdict {
        if let last = lastTaken(of: medication, before: date, excluding: nil),
           date.timeIntervalSince(last) < minimumGap(for: medication) {
            return .recentlyTaken(last)
        }
        return .ok
    }

    /// Half of the shortest gap between the planned times, between 1 and 3 hours. A medication taken
    /// once a day, or with no plan, gets 3 hours.
    @MainActor
    static func minimumGap(for medication: Medication) -> TimeInterval {
        let minutes = Array(Set(medication.activeSchedules.flatMap(\.minutesOfDay))).sorted()
        guard minutes.count > 1, let first = minutes.first, let last = minutes.last else { return 3 * 3600 }
        let gaps = zip(minutes, minutes.dropFirst()).map { $1 - $0 } + [first + 24 * 60 - last]
        let half = Double(gaps.min() ?? 0) * 60 / 2
        return min(max(half, 3600), 3 * 3600)
    }

    @MainActor
    static func lastTaken(of medication: Medication, before now: Date, excluding event: DoseEvent?) -> Date? {
        medication.eventList
            .filter { $0.status == .taken && $0 != event }
            .compactMap(\.takenAt)
            .filter { $0 <= now }
            .max()
    }
}
