// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// One local notification to schedule: the reminder for every open dose at one time, or one of
/// its follow-ups. `attempt` 0 is the reminder at dose time, 1… the follow-ups.
struct PlannedReminder: Equatable, Sendable {
    /// The dose's day as "yyyy-MM-dd" in the current calendar.
    let dayKey: String
    let minutesOfDay: Int
    let attempt: Int
    let fireAt: Date
    let medicationIDs: [UUID]

    var identifier: String { "dose|\(dayKey)|\(minutesOfDay)|\(attempt)" }
    var groupKey: String { "\(dayKey)|\(minutesOfDay)" }
}

struct ReminderPlan: Sendable {
    var reminders: [PlannedReminder] = []
    /// Time of the last dose that got its reminders; nil when nothing was planned.
    var plannedUntil: Date?
    /// True when the budget ran out before the horizon: the app has to run again to plan further.
    var limited = false
}

/// Turns open doses into a list of notifications. Pure planning, so it is tested without
/// UNUserNotificationCenter. The rule a person can remember: one reminder per time with every
/// medication due then; if nobody confirms, it repeats `repeatCount` times every `snoozeMinutes`,
/// never after the dose would count as missed; then silence.
@MainActor
enum ReminderPlanner {
    /// How far ahead doses are planned at most. Fewer when the 64-notification budget runs out first.
    static let horizonDays = 14

    struct Settings: Sendable {
        var snoozeMinutes: Int
        var repeatCount: Int
        var missedAfterMinutes: Int
    }

    /// `slots` are open scheduled doses (no record yet), any order. Doses whose reminders are all in
    /// the past are skipped. Doses at the same minute share one notification. Groups are planned in
    /// time order, each with all its follow-ups or not at all, until `budget` is used up.
    static func plan(slots: [DoseSlot], now: Date, settings: Settings, budget: Int,
                     skipping snoozedGroups: Set<String> = [], calendar: Calendar = .current) -> ReminderPlan {
        var plan = ReminderPlan()
        let groups = Dictionary(grouping: slots) { Int($0.scheduledAt.timeIntervalSince1970 / 60) }
        for key in groups.keys.sorted() {
            guard let members = groups[key], let scheduledAt = members.first?.scheduledAt else { continue }
            let ids = members
                .sorted { $0.medication.name.localizedStandardCompare($1.medication.name) == .orderedAscending }
                .compactMap(\.medication.id)
            guard !ids.isEmpty else { continue }
            let dayKey = Self.dayKey(for: scheduledAt, calendar: calendar)
            let minutes = calendar.component(.hour, from: scheduledAt) * 60 + calendar.component(.minute, from: scheduledAt)
            if snoozedGroups.contains("\(dayKey)|\(minutes)") { continue }

            let missedAt = scheduledAt.addingTimeInterval(TimeInterval(settings.missedAfterMinutes * 60))
            var sequence: [PlannedReminder] = []
            for attempt in 0...max(0, settings.repeatCount) {
                let fireAt = scheduledAt.addingTimeInterval(TimeInterval(attempt * settings.snoozeMinutes * 60))
                guard fireAt > now, attempt == 0 || fireAt <= missedAt else { continue }
                sequence.append(PlannedReminder(dayKey: dayKey, minutesOfDay: minutes, attempt: attempt, fireAt: fireAt, medicationIDs: ids))
            }
            guard !sequence.isEmpty else { continue }
            if plan.reminders.count + sequence.count > budget {
                plan.limited = true
                break
            }
            plan.reminders += sequence
            plan.plannedUntil = scheduledAt
        }
        return plan
    }

    nonisolated static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    nonisolated static func day(fromKey key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}
