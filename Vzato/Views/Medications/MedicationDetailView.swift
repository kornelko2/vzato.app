// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData
import SwiftUI

struct MedicationDetailView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var medication: Medication

    @State private var editing = false
    @State private var checkingSupply = false
    @State private var confirmingDelete = false

    private var schedule: Schedule? { medication.allSchedules.first }
    private var runOut: Date? { StockService.projectedRunOutDate(for: medication) }
    private var recentEvents: [DoseEvent] {
        medication.eventList
            .sorted { ($0.scheduledAt ?? .distantPast) > ($1.scheduledAt ?? .distantPast) }
            .prefix(20)
            .map { $0 }
    }

    var body: some View {
        List {
            Section {
                if !medication.dosageText.isEmpty {
                    LabeledContent("Dose") { Text(medication.dosageText) }
                }
                LabeledContent("Per dose") { Text(medication.doseAmountText) }
                if let schedule {
                    LabeledContent("Days") { Text(weekdaysText(schedule)) }
                    LabeledContent("Times") { Text(timesText(schedule)) }
                    if schedule.mealRelation != .any {
                        LabeledContent("Meals") { Text(schedule.mealRelation.label) }
                    }
                    if let end = schedule.endDate {
                        LabeledContent("Until") { Text(end, style: .date) }
                    }
                }
                if !medication.notes.isEmpty {
                    Text(medication.notes).foregroundStyle(.secondary)
                }
            }

            MedicationPhotosSection(medication: medication)

            Section("Supply") {
                if medication.tracksStock {
                    LabeledContent("Amount at home") { Text(medication.stockAmountText) }
                        .accessibilityElement(children: .combine).accessibilityIdentifier("amountAtHome")
                    LabeledContent("Doses left") { Text(medication.dosesInStock, format: .number) }
                        .accessibilityElement(children: .combine).accessibilityIdentifier("dosesLeft")
                    if let runOut {
                        LabeledContent("Runs out") { Text(runOut, style: .date) }
                            .accessibilityElement(children: .combine).accessibilityIdentifier("runsOut")
                        if let reorder = StockService.reorderDate(for: medication) {
                            LabeledContent("Get more by") { Text(reorder, style: .date) }
                                .foregroundStyle(reorder <= Date() ? Palette.overdue : .primary)
                                .accessibilityElement(children: .combine).accessibilityIdentifier("getMoreBy")
                        }
                    }
                    if let counted = medication.stockCountedAt {
                        LabeledContent("Last counted") { Text(counted, style: .date) }
                    }
                    if medication.isLowStock {
                        Label("Running low. Time to get more.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(Palette.overdue)
                    }
                    Button {
                        checkingSupply = true
                    } label: {
                        Label("Count and check supply", systemImage: "checklist")
                    }
                    .accessibilityIdentifier("checkSupply")
                } else {
                    Button {
                        checkingSupply = true
                    } label: {
                        Label("Track supply", systemImage: "shippingbox")
                    }
                }
            }

            Section("Recent doses") {
                if recentEvents.isEmpty {
                    Text("No doses recorded yet").foregroundStyle(.secondary)
                } else {
                    ForEach(recentEvents) { event in
                        HStack {
                            Image(systemName: event.status.symbolName).foregroundStyle(event.status.color)
                            if let at = event.scheduledAt {
                                Text(at, format: .dateTime.day().month().hour().minute())
                            }
                            if event.isUnscheduled { Text("extra").font(.caption).foregroundStyle(.secondary) }
                            Spacer()
                            Text(event.status.label).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                Button("Archive medication") { archive() }
                Button("Delete medication", role: .destructive) { confirmingDelete = true }
            } footer: {
                Text("Archiving keeps the history. Deleting removes the medication and all its records.")
            }
        }
        .navigationTitle(medication.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { editing = true }
            }
        }
        .onAppear { if LaunchArguments.opensEditor { editing = true } }
        .sheet(isPresented: $editing) {
            MedicationFormView(medication: medication)
        }
        .sheet(isPresented: $checkingSupply) {
            ReconciliationView(medication: medication)
        }
        .confirmationDialog("Delete this medication and its history?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { delete() }
        }
    }

    private func weekdaysText(_ schedule: Schedule) -> String {
        if schedule.isEveryDay { return String(localized: "Every day") }
        let calendar = Calendar.current
        let order = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
        return order.filter { schedule.weekdays.contains($0) }
            .map { calendar.shortStandaloneWeekdaySymbols[$0 - 1] }
            .joined(separator: ", ")
    }

    private func timesText(_ schedule: Schedule) -> String {
        let calendar = Calendar.current
        return schedule.minutesOfDay.sorted().compactMap { minutes -> String? in
            guard let date = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) else { return nil }
            return date.formatted(date: .omitted, time: .shortened)
        }.joined(separator: ", ")
    }

    private func archive() {
        medication.isArchived = true
        medication.archivedAt = Date()
        try? context.save()
        Task { await NotificationService.shared.rescheduleAll() }
        dismiss()
    }

    private func delete() {
        context.delete(medication)
        try? context.save()
        Task { await NotificationService.shared.rescheduleAll() }
        dismiss()
    }
}
