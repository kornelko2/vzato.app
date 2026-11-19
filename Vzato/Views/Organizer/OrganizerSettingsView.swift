// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData
import SwiftUI

/// Settings › Pill organizer: on or off, the layout and where compartments begin, per profile.
struct OrganizerSettingsView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(AppState.self) private var state
    @FetchRequest(sortDescriptors: [SortDescriptor(\Profile.createdAt)]) private var profiles: FetchedResults<Profile>
    @State private var profileID: NSManagedObjectID?

    private var profile: Profile? {
        profiles.first { $0.objectID == profileID }
            ?? profiles.first { $0.id == state.profileFilter }
            ?? profiles.first { $0.isDefault } ?? profiles.first
    }

    var body: some View {
        Form {
            if profiles.count > 1 {
                Section {
                    Picker("For", selection: Binding(get: { profile?.objectID }, set: { profileID = $0 })) {
                        ForEach(profiles) { profile in
                            Text(profile.name).tag(Optional(profile.objectID))
                        }
                    }
                }
            }
            if let profile {
                OrganizerSettingsSections(organizer: OrganizerService.organizer(for: profile, in: context), profile: profile)
                    .id(profile.objectID)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Text("Pill organizer"))
        .onDisappear { save() }
    }

    private func save() {
        guard context.hasChanges else { return }
        try? context.save()
        Task { await NotificationService.shared.rescheduleAll() }
    }
}

private struct OrganizerSettingsSections: View {
    @Environment(\.managedObjectContext) private var context
    @ObservedObject var organizer: Organizer
    let profile: Profile

    private var included: [Medication] {
        profile.medicationList.filter { !$0.isArchived && OrganizerService.belongsInOrganizer($0) }
    }

    var body: some View {
        Section {
            Toggle("Use a pill organizer", isOn: binding(\.isEnabled))
                .accessibilityIdentifier("organizerEnabled")
        } footer: {
            Text("Today shows the medications of one compartment together, with one Taken button for all of them, and one reminder comes per compartment. Your plan does not change.")
        }

        if organizer.isEnabled {
            Section {
                Picker("Layout", selection: Binding(get: { organizer.layout }, set: { organizer.layout = $0; save() })) {
                    ForEach(OrganizerLayout.allCases) { layout in
                        Text(layout.label).tag(layout)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Layout")
            }

            if organizer.layout.compartments.count > 1 {
                Section {
                    ForEach(Array(organizer.layout.compartments.dropFirst().enumerated()), id: \.element) { index, compartment in
                        DatePicker(selection: boundaryBinding(index), displayedComponents: .hourAndMinute) {
                            Label { Text(compartment.label) } icon: { Image(systemName: compartment.symbolName) }
                        }
                    }
                } header: {
                    Text("Compartment starts at")
                } footer: {
                    Text("Every dose time falls into one compartment. Morning starts at midnight.")
                }
            }

            Section {
                NavigationLink {
                    OrganizerFillView(profile: profile)
                } label: {
                    Label("Fill the organizer", systemImage: "square.grid.3x3")
                }
                .accessibilityIdentifier("fillOrganizer")
            } footer: {
                if included.isEmpty {
                    Text("No medication of this profile goes into the organizer yet.")
                } else {
                    Text("In the organizer: \(included.map(\.name).formatted(.list(type: .and))). Tablets and capsules go in by themselves; change it in a medication's settings.")
                }
            }
        }
    }

    private func binding(_ keyPath: ReferenceWritableKeyPath<Organizer, Bool>) -> Binding<Bool> {
        Binding(get: { organizer[keyPath: keyPath] }, set: { organizer[keyPath: keyPath] = $0; save() })
    }

    /// One boundary as a time; kept at least 15 minutes from its neighbours so the order holds.
    private func boundaryBinding(_ index: Int) -> Binding<Date> {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return Binding(
            get: { calendar.date(byAdding: .minute, value: organizer.boundaries[index], to: today) ?? today },
            set: { date in
                var boundaries = organizer.boundaries
                let minutes = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
                let low = index == 0 ? 15 : boundaries[index - 1] + 15
                let high = index == boundaries.count - 1 ? 24 * 60 - 15 : boundaries[index + 1] - 15
                boundaries[index] = min(max(minutes, low), high)
                organizer.boundaries = boundaries
                save()
            })
    }

    private func save() {
        try? context.save()
        Task { await NotificationService.shared.rescheduleAll() }
    }
}
