// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData
#if canImport(UIKit)
import UIKit
#endif

/// Writes the activity log. Callers save the context; the entry goes out with the change it describes.
@MainActor
enum ActivityLogger {
    @discardableResult
    static func log(_ kind: ActivityKind, medication: Medication?, scheduledAt: Date?, detail: String = "",
                    source: DoseSource = .app, in context: NSManagedObjectContext, at date: Date = Date()) -> ActivityEntry {
        let entry = ActivityEntry(context: context)
        entry.date = date
        entry.kind = kind
        entry.medicationID = medication?.id
        entry.medicationName = medication?.name ?? ""
        entry.scheduledAt = scheduledAt
        entry.detail = detail
        entry.deviceName = DeviceInfo.name
        entry.source = source
        return entry
    }

    /// The log as CSV, newest first, for export.
    static func csv(_ entries: [ActivityEntry]) -> String {
        let formatter = ISO8601DateFormatter()
        var lines = ["date,action,medication,dose_time,device,source,detail"]
        for entry in entries.sorted(by: { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }) {
            lines.append([
                entry.date.map(formatter.string) ?? "",
                entry.kindRaw,
                CSVExport.escape(entry.medicationName),
                entry.scheduledAt.map(formatter.string) ?? "",
                CSVExport.escape(entry.deviceName),
                entry.sourceRaw,
                CSVExport.escape(entry.detail),
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }
}

/// A short, human name for this device in the log ("iPhone", "iPad", the Mac's name).
enum DeviceInfo {
    @MainActor
    static var name: String {
        #if os(iOS)
        return UIDevice.current.name
        #elseif os(macOS)
        return Host.current().localizedName ?? "Mac"
        #else
        return ""
        #endif
    }
}
