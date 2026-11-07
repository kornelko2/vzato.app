// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData
import SwiftUI

/// Supply check: compare what the app recorded with what the user counts at home.
struct ReconciliationView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var medication: Medication

    @State private var actual: Double?
    @State private var recordMissing = true

    private var report: ReconciliationReport {
        ReconciliationService.report(for: medication, actualStock: actual)
    }

    var body: some View {
        NavigationStack {
            Form {
                if medication.tracksStock {
                    Section("Since the last count") {
                        LabeledContent("Counted on") { Text(report.since, style: .date) }
                        LabeledContent("Scheduled doses") { Text(report.scheduledDoses, format: .number) }
                        LabeledContent("Recorded as taken") { Text(report.recordedTaken, format: .number) }
                        LabeledContent("Skipped") { Text(report.recordedSkipped, format: .number) }
                        LabeledContent("Without a record") { Text(report.unaccounted, format: .number) }
                        LabeledContent("Should be at home") { Text(DoseFormatter.amount(report.expectedStock, unit: medication.unitKind)) }
                    }
                }

                Section {
                    AmountField("Amount you have at home", value: $actual)
                } header: {
                    Text("Count what you have")
                } footer: {
                    if !medication.tracksStock {
                        Text("Enter the number of units to start tracking this medication's supply.")
                    }
                }

                if actual != nil {
                    Section("Result") {
                        verdictView
                        if case .unrecordedDoses = report.verdict, report.unaccounted > 0 {
                            Toggle("Record the missing doses as taken", isOn: $recordMissing)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(Text("Supply check"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(actual == nil)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 520)
        #endif
    }

    @ViewBuilder
    private var verdictView: some View {
        switch report.verdict {
        case .notTracking, .needsCount:
            Label("Supply tracking starts with this count.", systemImage: "shippingbox")
        case .consistent:
            Label("Your count matches the records.", systemImage: "checkmark.circle.fill")
                .foregroundStyle(Palette.taken)
        case .unrecordedDoses(let doses):
            VStack(alignment: .leading, spacing: 6) {
                Label("Fewer units than the records expect.", systemImage: "exclamationmark.circle")
                    .foregroundStyle(Palette.overdue)
                Text("Units missing: \(DoseFormatter.amount(report.unitDifference ?? 0, unit: medication.unitKind)). That is about \(doses) doses taken without being recorded.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        case .overRecordedDoses(let doses):
            VStack(alignment: .leading, spacing: 6) {
                Label("More units than the records expect.", systemImage: "questionmark.circle")
                    .foregroundStyle(Palette.overdue)
                Text("Units extra: \(DoseFormatter.amount(-(report.unitDifference ?? 0), unit: medication.unitKind)). About \(doses) recorded doses may not have been taken. Review them in History.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private func save() {
        guard let actual else { return }
        ReconciliationService.apply(report, actualStock: actual, recordMissingDoses: recordMissing,
                                    context: context, notifier: NotificationService.shared)
        dismiss()
    }
}
