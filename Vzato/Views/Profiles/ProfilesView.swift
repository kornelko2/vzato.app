// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData
import SwiftUI

/// Settings › Profiles: you, your children, your animals. Each medication belongs to one profile.
struct ProfilesView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(sortDescriptors: [SortDescriptor(\Profile.createdAt)]) private var profiles: FetchedResults<Profile>
    @State private var editing: Profile?
    @State private var adding = false

    var body: some View {
        Form {
            Section {
                ForEach(profiles) { profile in
                    Button {
                        editing = profile
                    } label: {
                        HStack {
                            Image(systemName: profile.symbol)
                                .foregroundStyle(Color(hex: profile.colorHex ?? Palette.medicationHexes[3]))
                                .frame(width: 28)
                            Text(profile.name).foregroundStyle(.primary)
                            Spacer()
                            Text("\(profile.medicationList.filter { !$0.isArchived }.count) medications")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("profile-\(profile.name)")
                }
                Button {
                    adding = true
                } label: {
                    Label("Add profile", systemImage: "plus.circle")
                }
                .accessibilityIdentifier("addProfile")
            } footer: {
                Text("Add your children or your animals, for example a dog that gets a deworming tablet once a month. Today then shows whose dose it is, and you can show one profile at a time.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Text("Profiles"))
        .sheet(item: $editing) { profile in
            ProfileEditor(profile: profile)
        }
        .sheet(isPresented: $adding) {
            ProfileEditor(profile: nil)
        }
    }
}

struct ProfileEditor: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    let profile: Profile?

    @State private var name = ""
    @State private var kind = ProfileKind.person
    @State private var symbol = ProfileKind.person.defaultSymbol
    @State private var colorHex = Palette.medicationHexes[3]
    @State private var confirmingDelete = false

    init(profile: Profile?) {
        self.profile = profile
        guard let profile else { return }
        _name = State(initialValue: profile.name)
        _kind = State(initialValue: profile.kind)
        _symbol = State(initialValue: profile.symbol)
        _colorHex = State(initialValue: profile.colorHex ?? Palette.medicationHexes[3])
    }

    /// The default profile ("Me") stays; others can go once they have no medications left.
    private var canDelete: Bool {
        guard let profile, !profile.isDefault else { return false }
        return profile.medicationList.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .accessibilityIdentifier("profileName")
                    Picker("Kind", selection: $kind) {
                        ForEach(ProfileKind.allCases) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: kind) { _, kind in
                        if !kind.symbols.contains(symbol) { symbol = kind.defaultSymbol }
                    }
                }
                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 10) {
                        ForEach(kind.symbols, id: \.self) { name in
                            Button {
                                symbol = name
                            } label: {
                                Image(systemName: name)
                                    .font(.title3)
                                    .frame(width: 44, height: 44)
                                    .background(name == symbol ? Color(hex: colorHex) : Color.secondary.opacity(0.15), in: Circle())
                                    .foregroundStyle(name == symbol ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(name == symbol ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                    HStack(spacing: 10) {
                        ForEach(Palette.medicationHexes, id: \.self) { hex in
                            Button {
                                colorHex = hex
                            } label: {
                                Circle().fill(Color(hex: hex)).frame(width: 30, height: 30)
                                    .overlay {
                                        if hex == colorHex {
                                            Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("Color"))
                            .accessibilityAddTraits(hex == colorHex ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }
                if let profile, !profile.isDefault {
                    Section {
                        Button("Delete profile", role: .destructive) { confirmingDelete = true }
                            .disabled(!canDelete)
                    } footer: {
                        if !canDelete {
                            Text("Move this profile's medications to another profile or delete them first.")
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(profile == nil ? Text("New profile") : Text("Edit profile"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityIdentifier("saveProfile")
                }
            }
            .confirmationDialog("Delete this profile?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { delete() }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 420)
        #endif
    }

    private func save() {
        // Make sure "Me" exists first, so a new profile never becomes the only one.
        _ = PersistenceController.shared.ensureDefaultProfile()
        let target = profile ?? Profile(context: context)
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.kind = kind
        target.symbolName = symbol == kind.defaultSymbol ? nil : symbol
        target.colorHex = colorHex
        try? context.save()
        Task { await NotificationService.shared.rescheduleAll() }
        dismiss()
    }

    private func delete() {
        guard let profile, canDelete else { return }
        context.delete(profile)
        try? context.save()
        Task { await NotificationService.shared.rescheduleAll() }
        dismiss()
    }
}
