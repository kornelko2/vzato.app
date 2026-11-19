// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

@MainActor
enum CSVExport {
    /// Recorded doses plus the missed ones, which have no record (a scheduled dose gets one only
    /// when the person acts), so the export shows the same history as the calendar.
    static func make(events: [DoseEvent], missed: [DoseSlot] = []) -> String {
        let formatter = ISO8601DateFormatter()
        var lines = ["medication,dosage,scheduled_at,status,taken_at,source,unscheduled,profile"]
        var rows: [(Date, String)] = missed.map { slot in
            (slot.scheduledAt, [
                escape(slot.medication.name),
                escape(slot.medication.dosageText),
                formatter.string(from: slot.scheduledAt),
                DoseStatus.missed.rawValue,
                "", "", "0",
                escape(slot.medication.profile?.name ?? ""),
            ].joined(separator: ","))
        }
        for event in events {
            rows.append((event.scheduledAt ?? .distantPast, [
                escape(event.medication?.name ?? ""),
                escape(event.medication?.dosageText ?? ""),
                event.scheduledAt.map(formatter.string) ?? "",
                event.statusRaw,
                event.takenAt.map(formatter.string) ?? "",
                event.sourceRaw,
                event.isUnscheduled ? "1" : "0",
                escape(event.medication?.profile?.name ?? ""),
            ].joined(separator: ",")))
        }
        lines += rows.sorted { $0.0 < $1.0 }.map(\.1)
        return lines.joined(separator: "\n") + "\n"
    }

    /// Scheduled doses without a record whose grace period is over, from each medication's start,
    /// at most `maxDays` back.
    static func missedSlots(for medications: [Medication], now: Date, grace: TimeInterval, maxDays: Int = 730,
                            calendar: Calendar = .current) -> [DoseSlot] {
        let earliest = medications.flatMap(\.activeSchedules).compactMap(\.startDate).min()
            ?? medications.compactMap(\.createdAt).min() ?? now
        let limit = calendar.date(byAdding: .day, value: -maxDays, to: now) ?? now
        let start = calendar.startOfDay(for: max(earliest, limit))
        guard start < now else { return [] }
        return DoseScheduler.slots(for: medications, in: DateInterval(start: start, end: now), calendar: calendar)
            .filter { !$0.isUnscheduled && $0.status(now: now, grace: grace) == .missed }
    }

    /// Writes the table to a `.csv` file to share. Shared as plain data, Mail and Files would name
    /// it `.txt`; a file keeps its name and type. The BOM makes Excel read the accents as UTF-8.
    static func writeFile(_ text: String, on day: Date = Date()) -> URL? {
        let date = day.formatted(.iso8601.year().month().day())
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(String(localized: "Vzato history \(date).csv"))
        do {
            try Data(("\u{FEFF}" + text).utf8).write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    nonisolated static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
