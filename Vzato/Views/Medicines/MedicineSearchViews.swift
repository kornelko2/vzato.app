// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// Searches the bundled register off the main thread as the person types.
@MainActor
@Observable
final class MedicineSearch {
    private(set) var results: [MedicineEntry] = []
    private var task: Task<Void, Never>?

    /// Slovak first for people using the app in Slovak, Czech otherwise.
    private var preferred: MedicineSource {
        Locale.current.language.languageCode?.identifier == "sk" ? .sk : .cz
    }

    func update(_ query: String) {
        task?.cancel()
        let query = query.trimmingCharacters(in: .whitespaces)
        guard query.count >= 2 else { results = []; return }
        let prefer = preferred
        task = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            let found = await Task.detached(priority: .userInitiated) {
                MedicineIndex.bundled?.search(query, prefer: prefer) ?? []
            }.value
            guard !Task.isCancelled else { return }
            results = found
        }
    }
}

extension MedicineEntry {
    /// Czech names are published in capitals ("IBALGIN RAPIDCAPS"); shown like the Slovak ones.
    var displayName: String {
        name == name.uppercased() ? name.capitalized(with: Locale(identifier: "cs")) : name
    }

    var flag: String { source == .cz ? "🇨🇿" : "🇸🇰" }
}

struct MedicineResultRow: View {
    let entry: MedicineEntry
    let onAdd: () -> Void

    /// The whole row is one button: tapping anywhere opens the form, filled in.
    var body: some View {
        Button(action: onAdd) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(entry.displayName).font(.body.weight(.semibold)).lineLimit(2)
                        Text(verbatim: entry.flag).accessibilityHidden(true)
                    }
                    Text([entry.dosageText, entry.form].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    if !entry.packs.isEmpty {
                        Text("Packs: \(entry.packs.prefix(4).joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Label("Add", systemImage: "plus.circle.fill")
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .foregroundStyle(Palette.taken)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("addFromDatabase")
        .accessibilityHint(Text("Add"))
    }
}

/// Where the data comes from, as the SÚKL terms ask; says that the list is not a recommendation.
struct MedicineSourceNote: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Source: SÚKL and ŠÚKL open data, as of \(MedicineSourceNote.dates). The list only helps to fill in the name and does not recommend any medicine.")
            Link(destination: URL(string: "https://opendata.sukl.gov.cz/podminky-uziti-otevrenych-dat")!) {
                Text("SÚKL terms of use")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    static var dates: String {
        guard let index = MedicineIndex.bundled else { return "" }
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        return ["cz", "sk"].compactMap { index.dates[$0].flatMap(parser.date(from:)) }
            .map { $0.formatted(date: .abbreviated, time: .omitted) }
            .uniqued()
            .joined(separator: ", ")
    }
}

/// iPad and Mac sidebar: the register on its own.
struct MedicineDatabaseView: View {
    @State private var query = ""
    @State private var search = MedicineSearch()
    @State private var adding: MedicineEntry?

    var body: some View {
        NavigationStack {
            List {
                if query.trimmingCharacters(in: .whitespaces).count < 2 {
                    Section {
                        Text("Type the name of a medicine from the Czech or Slovak register, then tap Add.")
                            .foregroundStyle(.secondary)
                    } footer: {
                        MedicineSourceNote()
                    }
                } else if search.results.isEmpty {
                    Text("Nothing found. You can still add the medication by hand.")
                        .foregroundStyle(.secondary)
                } else {
                    Section {
                        ForEach(search.results) { entry in
                            MedicineResultRow(entry: entry) { adding = entry }
                        }
                    } footer: {
                        MedicineSourceNote()
                    }
                }
            }
            .searchable(text: $query, prompt: Text("Medicine name"))
            .onChange(of: query) { _, value in search.update(value) }
            .navigationTitle(Text("Medicines database"))
            .sheet(item: $adding) { entry in
                MedicationFormView(medication: nil, entry: entry)
            }
        }
    }
}
