// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData
import SwiftUI

struct MedicationsView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(AppState.self) private var state
    @FetchRequest(sortDescriptors: [SortDescriptor(\Medication.name)], predicate: NSPredicate(format: "isArchived == NO"))
    private var medications: FetchedResults<Medication>
    @State private var path = NavigationPath()
    @FetchRequest(sortDescriptors: [SortDescriptor(\Medication.name)], predicate: NSPredicate(format: "isArchived == YES"))
    private var archived: FetchedResults<Medication>
    @State private var query = ""
    @State private var search = MedicineSearch()
    @State private var adding: MedicineEntry?

    private var searching: Bool { query.trimmingCharacters(in: .whitespaces).count >= 2 }

    /// Your own medications whose name and strength contain every typed word, like the database search.
    private var ownMatches: [Medication] {
        let words = MedicineIndex.fold(query).split(separator: " ").map(String.init)
        return medications.filter { medication in
            let text = MedicineIndex.fold("\(medication.name) \(medication.dosageText)")
            return words.allSatisfy { text.contains($0) }
        }
    }
    @Environment(\.showsProfiles) private var showsProfiles
    @FetchRequest(sortDescriptors: [SortDescriptor(\Profile.createdAt)]) private var profiles: FetchedResults<Profile>

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if searching {
                    searchResults
                } else if showsProfiles {
                    // One section per profile, so a child's or a dog's medications stay together.
                    ForEach(profiles) { profile in
                        let own = medications.of(profile: profile.id)
                        if !own.isEmpty {
                            Section {
                                rows(own)
                            } header: {
                                ProfileBadge(profile: profile, font: .subheadline.weight(.semibold))
                            }
                        }
                    }
                } else {
                    rows(Array(medications))
                }
                if !searching && !archived.isEmpty {
                    Section {
                        NavigationLink {
                            List { rows(Array(archived)) }
                                .navigationTitle(Text("Archived medications"))
                        } label: {
                            LabeledContent {
                                Text(verbatim: "\(archived.count)")
                            } label: {
                                Label("Archived medications", systemImage: "archivebox")
                            }
                        }
                        .accessibilityIdentifier("archivedMedications")
                    }
                }
            }
            .searchable(text: $query, prompt: Text("Your medications and the database"))
            .onChange(of: query) { _, value in search.update(value) }
            .sheet(item: $adding) { entry in
                MedicationFormView(medication: nil, entry: entry)
            }
            .overlay {
                if medications.isEmpty && archived.isEmpty && !searching {
                    ContentUnavailableView {
                        Label("No medications", systemImage: "pills")
                    } description: {
                        Text("Add your first medication with its dose and times. Vzato then reminds you.")
                    } actions: {
                        Button {
                            state.showingNewMedication = true
                        } label: {
                            Label("Add medication", systemImage: "plus")
                                .font(.title3.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityIdentifier("addFirstMedication")
                    }
                }
            }
            .navigationTitle(Text("Medications"))
            .navigationDestination(for: Medication.self) { medication in
                MedicationDetailView(medication: medication)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { state.showingNewMedication = true } label: { Label("Add medication", systemImage: "plus") }
                }
            }
            .onAppear {
                if query.isEmpty, let text = LaunchArguments.searchText { query = text }
                if path.isEmpty, let name = LaunchArguments.medicationToOpen,
                   let medication = medications.first(where: { $0.name == name }) {
                    path.append(medication)
                } else if LaunchArguments.opensFirstMedication, path.isEmpty, let first = medications.first {
                    path.append(first)
                }
            }
        }
    }
}

extension MedicationsView {
    @ViewBuilder
    fileprivate var searchResults: some View {
        if !ownMatches.isEmpty {
            Section("My medications") {
                rows(ownMatches)
            }
        }
        Section {
            if search.results.isEmpty {
                Text("Nothing found in the database. You can still add the medication by hand.")
                    .foregroundStyle(.secondary)
            }
            ForEach(search.results) { entry in
                MedicineResultRow(entry: entry) { adding = entry }
            }
        } header: {
            Text("Medicines database")
        } footer: {
            MedicineSourceNote()
        }
    }

    fileprivate func rows(_ list: [Medication]) -> some View {
        ForEach(list) { medication in
            NavigationLink(value: medication) {
                MedicationRow(medication: medication)
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
                if medication.tracksStock {
                    HStack(spacing: 4) {
                        Text(medication.stockAmountText)
                        if let reorder = StockService.reorderDate(for: medication) {
                            Text(verbatim: "·")
                            Text("get more by \(reorder.formatted(.dateTime.day().month()))")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(medication.isLowStock ? Palette.overdue : .secondary)
                }
            }
            Spacer()
            if medication.isLowStock {
                Label {
                    Text(medication.stockAmountText)
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.overdue)
                .accessibilityLabel(Text("Running low, \(medication.stockAmountText) left"))
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
        .environment(AppState())
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
