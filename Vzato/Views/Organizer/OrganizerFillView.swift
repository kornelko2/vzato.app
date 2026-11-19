// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData
import SwiftUI

/// "Fill the organizer": what goes into each compartment for the coming days, with a picture of
/// each pill, ticks while filling, and how many pieces that takes next to the supply.
struct OrganizerFillView: View {
    @ObservedObject var profile: Profile
    @State private var start = OrganizerFillView.defaultStart()
    @State private var checking: Medication?
    /// Ticked cells, kept on this device for the chosen start day.
    @AppStorage("organizerFilled") private var filledRaw = ""

    private var organizer: Organizer? { profile.organizer }
    private var plan: [OrganizerFillCell] {
        guard let organizer else { return [] }
        return OrganizerService.fillPlan(for: organizer, medications: profile.medicationList, from: start)
    }

    var body: some View {
        let plan = plan
        Form {
            Section {
                DatePicker("From", selection: $start, displayedComponents: .date)
            } footer: {
                if organizer?.layout.days == 1 {
                    Text("A daily organizer: one day to fill.")
                }
            }

            let needs = OrganizerService.needs(in: plan)
            if !needs.isEmpty {
                Section {
                    ForEach(needs) { need in
                        needRow(need)
                    }
                } header: {
                    Text("You need")
                } footer: {
                    Text("Filling the organizer is a good moment to count the supply.")
                }
            }

            let days = Dictionary(grouping: plan, by: \.day)
            ForEach(days.keys.sorted(), id: \.self) { day in
                Section {
                    ForEach(days[day] ?? []) { cell in
                        cellRow(cell)
                    }
                } header: {
                    Text(day.formatted(.dateTime.weekday(.wide).day().month()))
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Text("Fill the organizer"))
        .sheet(item: $checking) { medication in
            ReconciliationView(medication: medication)
        }
    }

    @ViewBuilder
    private func needRow(_ need: OrganizerNeed) -> some View {
        let content = HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(need.medication.name)
                if let stock = need.stock {
                    Text("Supply: \(DoseFormatter.amount(stock, unit: need.medication.unitKind))")
                        .font(.caption)
                        .foregroundStyle(need.isShort ? Palette.missed : .secondary)
                }
            }
            Spacer()
            Text(DoseFormatter.amount(need.units, unit: need.medication.unitKind))
                .font(.body.weight(.semibold))
                .foregroundStyle(need.isShort ? Palette.missed : .primary)
            if need.stock != nil {
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        if need.stock != nil {
            Button { checking = need.medication } label: { content }
                .buttonStyle(.plain)
                .accessibilityHint(Text("Opens the supply check"))
        } else {
            content
        }
    }

    private func cellRow(_ cell: OrganizerFillCell) -> some View {
        let key = "\(Int(start.timeIntervalSince1970))|\(cell.id)"
        let filled = filledKeys.contains(key)
        return Button {
            toggle(key)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: filled ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(filled ? Palette.taken : .secondary)
                VStack(alignment: .leading, spacing: 6) {
                    Label { Text(cell.compartment.label).font(.headline) } icon: { Image(systemName: cell.compartment.symbolName) }
                        .foregroundStyle(.primary)
                    if cell.items.isEmpty {
                        Text("Empty").foregroundStyle(.secondary)
                    }
                    ForEach(cell.items) { item in
                        HStack(spacing: 8) {
                            if let photo = item.medication.photos(of: .pill).first {
                                PhotoThumbnail(photo: photo, size: 32)
                            }
                            Text(item.medication.name).foregroundStyle(.primary)
                            Spacer()
                            Text(DoseFormatter.amount(item.units, unit: item.medication.unitKind))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .opacity(filled ? 0.6 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(cell.items.isEmpty)
        .accessibilityAddTraits(filled ? .isSelected : [])
    }

    private var filledKeys: Set<String> { Set(filledRaw.split(separator: "\n").map(String.init)) }

    private func toggle(_ key: String) {
        var keys = filledKeys
        if keys.contains(key) { keys.remove(key) } else { keys.insert(key) }
        // Only the current fill is worth keeping.
        let prefix = "\(Int(start.timeIntervalSince1970))|"
        filledRaw = keys.filter { $0.hasPrefix(prefix) }.sorted().joined(separator: "\n")
    }

    /// Organizers are usually filled for a week starting Monday: today if it is Monday, otherwise
    /// the coming Monday.
    static func defaultStart(calendar: Calendar = .current, now: Date = Date()) -> Date {
        let today = calendar.startOfDay(for: now)
        var monday = DateComponents()
        monday.weekday = 2
        if calendar.component(.weekday, from: today) == 2 { return today }
        return calendar.nextDate(after: today, matching: monday, matchingPolicy: .nextTime) ?? today
    }
}
