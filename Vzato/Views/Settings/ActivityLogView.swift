// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData
import SwiftUI

/// Every recorded action, newest first, with the device and the screen it came from.
struct ActivityLogView: View {
    @FetchRequest(sortDescriptors: [SortDescriptor(\ActivityEntry.date, order: .reverse)])
    private var entries: FetchedResults<ActivityEntry>

    var body: some View {
        List {
            if entries.isEmpty {
                Text("No activity yet").foregroundStyle(.secondary)
            } else {
                Section {
                    ForEach(entries) { entry in
                        ActivityRow(entry: entry)
                    }
                } footer: {
                    Text("Every taken, skipped or corrected dose is recorded here with the device it came from. Entries are never changed.")
                }
            }
        }
        .navigationTitle(Text("Activity log"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: ActivityLogCSV(text: ActivityLogger.csv(Array(entries))),
                          preview: SharePreview(Text("Activity log"))) {
                    Label("Export log", systemImage: "square.and.arrow.up")
                }
                .disabled(entries.isEmpty)
            }
        }
    }
}

private struct ActivityRow: View {
    @ObservedObject var entry: ActivityEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.kind.symbolName)
                .foregroundStyle(color)
                .font(.title3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.kind.label).font(.body.weight(.semibold))
                    if !entry.medicationName.isEmpty {
                        Text(verbatim: "·").foregroundStyle(.secondary)
                        Text(entry.medicationName)
                    }
                }
                HStack(spacing: 4) {
                    if let scheduledAt = entry.scheduledAt {
                        Text("Dose \(scheduledAt.formatted(date: .abbreviated, time: .shortened))")
                        Text(verbatim: "·")
                    }
                    Text(entry.deviceName.isEmpty ? String(localized: "another device") : entry.deviceName)
                    Text(verbatim: "·")
                    Text(entry.source.label)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if !entry.detail.isEmpty {
                    Text(entry.detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if let date = entry.date {
                Text(date, format: .dateTime.day().month().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var color: Color {
        switch entry.kind {
        case .taken, .extraDose: Palette.taken
        case .skipped: Palette.skipped
        case .duplicateMerged: Palette.overdue
        default: .secondary
        }
    }
}

struct ActivityLogCSV: Transferable {
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { Data($0.text.utf8) }
            .suggestedFileName("vzato-activity-log.csv")
    }
}
