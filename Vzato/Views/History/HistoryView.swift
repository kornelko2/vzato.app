// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData
import SwiftUI

struct HistoryView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(sortDescriptors: [SortDescriptor(\Medication.name)])
    private var medications: FetchedResults<Medication>
    @FetchRequest(sortDescriptors: [SortDescriptor(\DoseEvent.scheduledAt)])
    private var events: FetchedResults<DoseEvent>
    @AppStorage(AppSettings.missedAfterMinutesKey) private var missedAfterMinutes = AppSettings.defaultMissedAfterMinutes

    @State private var monthStart = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var now = Date()

    private let calendar = Calendar.current
    private var grace: TimeInterval { TimeInterval(missedAfterMinutes * 60) }

    private var daySlots: [DoseSlot] {
        _ = events.count
        return DoseScheduler.slots(for: Array(medications), on: selectedDay, calendar: calendar)
    }

    private var monthSummaries: [Date: DaySummary] {
        _ = events.count
        return DoseSummary.byDay(medications: Array(medications), monthStart: monthStart, now: now, grace: grace, calendar: calendar)
    }

    private var monthTotals: DaySummary { DoseSummary.total(Array(monthSummaries.values)) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    MonthCalendarView(monthStart: $monthStart, selectedDay: $selectedDay, summaries: monthSummaries)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }

                Section {
                    if daySlots.isEmpty {
                        Text("No doses on this day").foregroundStyle(.secondary)
                    } else {
                        ForEach(daySlots) { slot in
                            DoseRow(slot: slot, now: now, grace: grace,
                                    onTaken: { DoseLogger(context: context).markTaken(slot, at: slot.scheduledAt) },
                                    onSkipped: { DoseLogger(context: context).markSkipped(slot) },
                                    onReset: { DoseLogger(context: context).reset(slot) })
                        }
                    }
                } header: {
                    Text(selectedDay, format: .dateTime.weekday(.wide).day().month(.wide))
                }

                Section("This month") {
                    let totals = monthTotals
                    LabeledContent("Taken") { Text(totals.taken, format: .number) }
                    LabeledContent("Missed") { Text(totals.missed, format: .number) }
                    LabeledContent("Skipped") { Text(totals.skipped, format: .number) }
                    if let adherence = totals.adherence {
                        LabeledContent("Adherence") {
                            Text(adherence, format: .percent.precision(.fractionLength(0)))
                        }
                    }
                }
            }
            .navigationTitle(Text("History"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: DoseHistoryCSV(text: CSVExport.make(events: Array(events))),
                              preview: SharePreview(Text("Dose history"))) {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                    .disabled(events.isEmpty)
                }
            }
            .onAppear { now = Date() }
        }
    }
}

#Preview {
    HistoryView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
