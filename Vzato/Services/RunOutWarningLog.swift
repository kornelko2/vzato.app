// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Remembers when the "running out" warning of each medication was set to go off, so it comes once
/// per supply. Without it, a dose confirmed late or skipped moves the projected run-out date a day
/// later and the next rebuild would warn again.
enum RunOutWarningLog {
    private static let key = "runOutWarningFires"

    /// A warning that already went off is not repeated until the supply lasts clearly longer again
    /// (a refill): the new warning must be more than `windowDays` after the previous one.
    static func shouldSchedule(fire: Date, previous: Date?, now: Date, windowDays: Int, calendar: Calendar) -> Bool {
        guard let previous, previous <= now else { return true }
        guard let limit = calendar.date(byAdding: .day, value: windowDays, to: previous) else { return true }
        return fire > limit
    }

    static func previousFire(for id: UUID, defaults: UserDefaults = .standard) -> Date? {
        (defaults.dictionary(forKey: key)?[id.uuidString] as? Double).map(Date.init(timeIntervalSince1970:))
    }

    static func record(_ fire: Date, for id: UUID, defaults: UserDefaults = .standard) {
        var all = defaults.dictionary(forKey: key) ?? [:]
        all[id.uuidString] = fire.timeIntervalSince1970
        defaults.set(all, forKey: key)
    }
}
