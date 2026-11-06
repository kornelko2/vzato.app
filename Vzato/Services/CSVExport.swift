// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct DoseHistoryCSV: Transferable, Sendable {
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { Data($0.text.utf8) }
            .suggestedFileName("vzato-history.csv")
    }
}

enum CSVExport {
    static func make(events: [DoseEvent]) -> String {
        let formatter = ISO8601DateFormatter()
        var lines = ["medication,dosage,scheduled_at,status,taken_at,source,unscheduled"]
        let sorted = events.sorted { ($0.scheduledAt ?? .distantPast) < ($1.scheduledAt ?? .distantPast) }
        for event in sorted {
            lines.append([
                escape(event.medication?.name ?? ""),
                escape(event.medication?.dosageText ?? ""),
                event.scheduledAt.map(formatter.string) ?? "",
                event.statusRaw,
                event.takenAt.map(formatter.string) ?? "",
                event.sourceRaw,
                event.isUnscheduled ? "1" : "0",
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
