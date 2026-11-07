// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData
import SwiftUI

/// Logs a dose outside the plan, e.g. a painkiller taken as needed.
struct ExtraDoseView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(sortDescriptors: [SortDescriptor(\Medication.name)], predicate: NSPredicate(format: "isArchived == NO"))
    private var medications: FetchedResults<Medication>
    @State private var selected: Medication?
    @State private var date = Date()
    @State private var warning: String?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Medication", selection: $selected) {
                    ForEach(medications) { medication in
                        Text(medication.name).tag(Optional(medication))
                    }
                }
                DatePicker("Time", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
            }
            .formStyle(.grouped)
            .navigationTitle(Text("Extra dose"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") {
                        guard let selected else { return }
                        if case .recentlyTaken(let at) = DoseGuard.verdictForExtraDose(of: selected, at: date) {
                            warning = String(localized: "\(selected.name) was already taken at \(at.formatted(date: .omitted, time: .shortened)). Take another dose now?")
                        } else {
                            DoseLogger(context: context).logExtraDose(for: selected, at: date)
                            dismiss()
                        }
                    }
                    .disabled(selected == nil)
                }
            }
            .onAppear { if selected == nil { selected = medications.first } }
            .confirmationDialog(Text("Take this dose?"), isPresented: Binding(get: { warning != nil }, set: { if !$0 { warning = nil } }),
                                titleVisibility: .visible) {
                Button("Take anyway", role: .destructive) {
                    if let selected { DoseLogger(context: context).logExtraDose(for: selected, at: date) }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(warning ?? "")
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 220)
        #endif
    }
}
