// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData
import SwiftUI

struct MedicationsView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(sortDescriptors: [SortDescriptor(\Medication.name)], predicate: NSPredicate(format: "isArchived == NO"))
    private var medications: FetchedResults<Medication>
    @State private var showingForm = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(medications) { medication in
                    NavigationLink(value: medication) {
                        MedicationRow(medication: medication)
                    }
                }
            }
            .overlay {
                if medications.isEmpty {
                    ContentUnavailableView {
                        Label("No medications", systemImage: "pills")
                    } description: {
                        Text("Tap + to add your first medication.")
                    }
                }
            }
            .navigationTitle(Text("Medications"))
            .navigationDestination(for: Medication.self) { medication in
                MedicationDetailView(medication: medication)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingForm = true } label: { Label("Add medication", systemImage: "plus") }
                }
            }
            .sheet(isPresented: $showingForm) {
                MedicationFormView(medication: nil)
            }
        }
    }
}

struct MedicationRow: View {
    @ObservedObject var medication: Medication

    private var next: DoseSlot? { DoseScheduler.nextSlot(for: medication, after: Date()) }

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(Color(hex: medication.colorHex)).frame(width: 14, height: 14)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(medication.name).font(.body.weight(.semibold))
                HStack(spacing: 6) {
                    if !medication.dosageText.isEmpty { Text(medication.dosageText) }
                    if let next {
                        if !medication.dosageText.isEmpty { Text(verbatim: "·") }
                        Text("Next")
                        Text(next.scheduledAt, format: nextFormat(next.scheduledAt))
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if medication.isLowStock {
                Label {
                    Text(medication.stockCount, format: .number)
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.overdue)
                .accessibilityLabel(Text("Running low, \(medication.stockCount) left"))
            }
        }
        .padding(.vertical, 4)
    }

    private func nextFormat(_ date: Date) -> Date.FormatStyle {
        Calendar.current.isDateInToday(date) ? .dateTime.hour().minute() : .dateTime.weekday(.abbreviated).hour().minute()
    }
}

#Preview {
    MedicationsView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
