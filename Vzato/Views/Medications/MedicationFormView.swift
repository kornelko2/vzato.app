// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData
import SwiftUI

/// Add or edit a medication together with its (single, for now) schedule and supply settings.
struct MedicationFormView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    let medication: Medication?

    @State private var name = ""
    @State private var dosageText = ""
    @State private var notes = ""
    @State private var colorHex = Palette.medicationHexes[3]
    @State private var weekdays: Set<Int> = Set(1...7)
    @State private var times: [TimeEntry] = [TimeEntry(minutes: 8 * 60)]
    @State private var mealRelation = MealRelation.any
    @State private var mealWaitMinutes = 30
    @State private var startDate = Calendar.current.startOfDay(for: Date())
    @State private var hasEndDate = false
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var tracksStock = false
    /// nil until the person enters how much they have; a preset number would be easy to save by mistake.
    @State private var stockCount: Double?
    @State private var unitsPerDose: Double = 1
    @State private var unitKind = DoseUnit.tablet
    @State private var lowStockThreshold: Double = 5

    private let calendar = Calendar.current

    struct TimeEntry: Identifiable {
        let id = UUID()
        var minutes: Int
    }

    init(medication: Medication?) {
        self.medication = medication
        guard let medication else { return }
        _name = State(initialValue: medication.name)
        _dosageText = State(initialValue: medication.dosageText)
        _notes = State(initialValue: medication.notes)
        _colorHex = State(initialValue: medication.colorHex)
        _tracksStock = State(initialValue: medication.tracksStock)
        _stockCount = State(initialValue: medication.tracksStock ? medication.stockCount : nil)
        _unitsPerDose = State(initialValue: medication.effectiveUnitsPerDose)
        _unitKind = State(initialValue: medication.unitKind)
        _lowStockThreshold = State(initialValue: medication.lowStockThreshold)
        if let schedule = medication.allSchedules.first {
            _weekdays = State(initialValue: Set(schedule.weekdays))
            _times = State(initialValue: schedule.minutesOfDay.sorted().map { TimeEntry(minutes: $0) })
            _mealRelation = State(initialValue: schedule.mealRelation)
            _mealWaitMinutes = State(initialValue: max(15, schedule.mealWaitMinutes))
            _startDate = State(initialValue: schedule.startDate ?? Date())
            _hasEndDate = State(initialValue: schedule.endDate != nil)
            if let end = schedule.endDate { _endDate = State(initialValue: end) }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !weekdays.isEmpty && !times.isEmpty
            && (!tracksStock || stockCount != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Medication") {
                    TextField("Name", text: $name)
                        .accessibilityIdentifier("name")
                    TextField("Dose, e.g. 400 mg", text: $dosageText)
                    colorPicker
                    TextField("Notes", text: $notes, axis: .vertical)
                }

                Section("Schedule") {
                    weekdayPicker
                    ForEach($times) { $entry in
                        DatePicker("Time", selection: binding(for: $entry), displayedComponents: .hourAndMinute)
                    }
                    .onDelete { times.remove(atOffsets: $0) }
                    Button {
                        times.append(TimeEntry(minutes: Schedule.nextSuggestedMinutes(after: times.map(\.minutes))))
                    } label: {
                        Label("Add time", systemImage: "plus.circle")
                    }
                    .accessibilityIdentifier("addTime")
                    Picker("Meals", selection: $mealRelation) {
                        ForEach(MealRelation.allCases) { relation in
                            Text(relation.label).tag(relation)
                        }
                    }
                    if mealRelation == .before {
                        Stepper(value: $mealWaitMinutes, in: 15...120, step: 15) {
                            LabeledContent("Eat after") { Text("\(mealWaitMinutes) min") }
                        }
                    }
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    Toggle("End date", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
                }

                Section {
                    Picker("Unit", selection: $unitKind) {
                        ForEach(DoseUnit.allCases) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                    .onChange(of: unitKind) { _, unit in
                        if !unit.allowsFractions { unitsPerDose = max(1, unitsPerDose.rounded()) }
                        unitsPerDose = min(unitsPerDose, unit.maximumPerDose)
                    }
                    Stepper(value: $unitsPerDose, in: (unitKind.allowsFractions ? Medication.minimumDoseUnits : 1)...unitKind.maximumPerDose, step: unitKind.step) {
                        LabeledContent("Amount per dose") { Text(DoseFormatter.amount(unitsPerDose, unit: unitKind)) }
                    }
                    Toggle("Track supply", isOn: $tracksStock)
                        .accessibilityIdentifier("trackSupply")
                    if tracksStock {
                        LabeledContent("Amount at home") {
                            AmountField("Amount at home", value: $stockCount)
                                .accessibilityIdentifier("stockAmount")
                                .multilineTextAlignment(.trailing)
                                .labelsHidden()
                        }
                        Stepper(value: $lowStockThreshold, in: 0...500, step: unitKind.allowsFractions ? 1 : 5) {
                            LabeledContent("Warn when below") { Text(DoseFormatter.amount(lowStockThreshold, unit: unitKind)) }
                        }
                    }
                } header: {
                    Text("Dose and supply")
                } footer: {
                    Text("Pick the unit: tablets, drops, millilitres and more. Half or quarter tablets work too. Each confirmed dose lowers the amount at home and you get a notification when it runs low.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle(medication == nil ? Text("New medication") : Text("Edit medication"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!canSave)
                        .accessibilityIdentifier("save")
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 620)
        #endif
    }

    private var colorPicker: some View {
        HStack(spacing: 10) {
            ForEach(Palette.medicationHexes, id: \.self) { hex in
                Button {
                    colorHex = hex
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 30, height: 30)
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

    private var weekdayOrder: [Int] {
        (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
    }

    private var weekdayPicker: some View {
        HStack(spacing: 6) {
            ForEach(weekdayOrder, id: \.self) { weekday in
                let on = weekdays.contains(weekday)
                Button {
                    if on { weekdays.remove(weekday) } else { weekdays.insert(weekday) }
                } label: {
                    Text(calendar.veryShortStandaloneWeekdaySymbols[weekday - 1])
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(on ? Color.accentColor : Color.secondary.opacity(0.15), in: Circle())
                        .foregroundStyle(on ? .white : .primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(calendar.standaloneWeekdaySymbols[weekday - 1]))
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }

    private func binding(for entry: Binding<TimeEntry>) -> Binding<Date> {
        Binding(
            get: {
                calendar.date(bySettingHour: entry.wrappedValue.minutes / 60, minute: entry.wrappedValue.minutes % 60, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let components = calendar.dateComponents([.hour, .minute], from: date)
                entry.wrappedValue.minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
            }
        )
    }

    private func save() {
        let target = medication ?? Medication(context: context)
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.dosageText = dosageText.trimmingCharacters(in: .whitespaces)
        target.notes = notes
        target.colorHex = colorHex
        if target.profile == nil {
            target.profile = PersistenceController.shared.ensureDefaultProfile()
        }

        let schedule = target.allSchedules.first ?? {
            let schedule = Schedule(context: context)
            schedule.medication = target
            return schedule
        }()
        schedule.weekdays = Array(weekdays)
        schedule.minutesOfDay = times.map(\.minutes)
        schedule.mealRelation = mealRelation
        schedule.mealWaitMinutes = mealWaitMinutes
        schedule.startDate = calendar.startOfDay(for: startDate)
        schedule.endDate = hasEndDate ? calendar.startOfDay(for: endDate) : nil

        target.unitKind = unitKind
        target.unitsPerDose = max(Medication.minimumDoseUnits, unitsPerDose)
        if tracksStock {
            target.lowStockThreshold = max(0, lowStockThreshold)
            if let stockCount, !target.tracksStock || target.stockCount != stockCount {
                StockService.setStock(target, count: stockCount)
            }
        } else {
            target.tracksStock = false
        }

        do {
            try context.save()
        } catch {
            context.rollback()
        }
        Task { await NotificationService.shared.rescheduleAll() }
        dismiss()
    }
}
