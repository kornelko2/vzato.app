// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// One expected dose on one day. Exists only in memory; a DoseEvent is attached when the user acts.
struct DoseSlot: Identifiable {
    let medication: Medication
    let scheduledAt: Date
    let event: DoseEvent?

    var id: String {
        "\(medication.id?.uuidString ?? medication.objectID.uriRepresentation().absoluteString)|\(Int(scheduledAt.timeIntervalSince1970))|\(event?.isUnscheduled == true ? "x" : "s")"
    }

    var isUnscheduled: Bool { event?.isUnscheduled ?? false }

    func status(now: Date, grace: TimeInterval) -> DoseStatus {
        if let event { return event.status }
        return scheduledAt.addingTimeInterval(grace) < now ? .missed : .pending
    }

    func isOverdue(now: Date, grace: TimeInterval) -> Bool {
        status(now: now, grace: grace) == .pending && scheduledAt <= now
    }
}

enum DoseScheduler {
    /// Scheduled times of one schedule on one day, or empty if the schedule does not apply.
    static func times(for schedule: Schedule, on day: Date, calendar: Calendar) -> [Date] {
        guard !schedule.isPaused else { return [] }
        let startOfDay = calendar.startOfDay(for: day)
        if let start = schedule.startDate, startOfDay < calendar.startOfDay(for: start) { return [] }
        if let end = schedule.endDate, startOfDay > calendar.startOfDay(for: end) { return [] }
        let weekday = calendar.component(.weekday, from: startOfDay)
        guard schedule.weekdays.contains(weekday) else { return [] }
        return schedule.minutesOfDay.sorted().compactMap { minutes in
            calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: startOfDay)
        }
    }

    /// All slots of the given medications on one day, scheduled ones merged with existing events,
    /// plus unscheduled (extra) doses logged that day. Sorted by time.
    static func slots(for medications: [Medication], on day: Date, calendar: Calendar = .current) -> [DoseSlot] {
        let startOfDay = calendar.startOfDay(for: day)
        var result: [DoseSlot] = []
        for medication in medications {
            let dayEvents = medication.eventList.filter { event in
                guard let at = event.scheduledAt else { return false }
                return calendar.isDate(at, inSameDayAs: startOfDay)
            }
            let archivedCutoff = medication.archivedAt.map { calendar.startOfDay(for: $0) }
            let generatesDoses = archivedCutoff.map { startOfDay <= $0 } ?? true
            var used = Set<ObjectIdentifier>()
            if generatesDoses {
                var seenTimes = Set<Int>()
                for schedule in medication.activeSchedules {
                    for time in times(for: schedule, on: startOfDay, calendar: calendar) {
                        let key = Int(time.timeIntervalSince1970 / 60)
                        guard seenTimes.insert(key).inserted else { continue }
                        let match = dayEvents.first { event in
                            guard !event.isUnscheduled, !used.contains(ObjectIdentifier(event)), let at = event.scheduledAt else { return false }
                            return calendar.isDate(at, equalTo: time, toGranularity: .minute)
                        }
                        if let match { used.insert(ObjectIdentifier(match)) }
                        result.append(DoseSlot(medication: medication, scheduledAt: time, event: match))
                    }
                }
            }
            for event in dayEvents where event.isUnscheduled {
                guard let at = event.scheduledAt else { continue }
                result.append(DoseSlot(medication: medication, scheduledAt: at, event: event))
            }
            // Scheduled events whose schedule no longer exists (plan changed): keep them visible in history.
            for event in dayEvents where !event.isUnscheduled && !used.contains(ObjectIdentifier(event)) {
                if let at = event.scheduledAt, event.status != .pending {
                    result.append(DoseSlot(medication: medication, scheduledAt: at, event: event))
                }
            }
        }
        return result.sorted { $0.scheduledAt < $1.scheduledAt }
    }

    /// Slots across several days, limited to the interval (inclusive).
    static func slots(for medications: [Medication], in interval: DateInterval, calendar: Calendar = .current) -> [DoseSlot] {
        var result: [DoseSlot] = []
        var day = calendar.startOfDay(for: interval.start)
        let lastDay = calendar.startOfDay(for: interval.end)
        while day <= lastDay {
            result += slots(for: medications, on: day, calendar: calendar).filter { interval.contains($0.scheduledAt) }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    /// Next scheduled dose of a medication after a point in time, looking ahead a limited number of days.
    static func nextSlot(for medication: Medication, after date: Date, calendar: Calendar = .current, lookaheadDays: Int = 14) -> DoseSlot? {
        var day = calendar.startOfDay(for: date)
        for _ in 0...lookaheadDays {
            if let slot = slots(for: [medication], on: day, calendar: calendar).first(where: { $0.scheduledAt > date && !$0.isUnscheduled }) {
                return slot
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return nil
    }
}
