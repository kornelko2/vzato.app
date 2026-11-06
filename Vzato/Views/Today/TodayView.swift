// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData
import SwiftUI

/// Direction C: one large card for the dose that needs attention, the rest of the day as a timeline.
struct TodayView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(AppState.self) private var state
    @FetchRequest(sortDescriptors: [SortDescriptor(\Medication.name)], predicate: NSPredicate(format: "isArchived == NO"))
    private var medications: FetchedResults<Medication>
    // Observed only so the view refreshes when a dose is recorded or reset.
    @FetchRequest(sortDescriptors: [SortDescriptor(\DoseEvent.scheduledAt)])
    private var events: FetchedResults<DoseEvent>

    @AppStorage(AppSettings.missedAfterMinutesKey) private var missedAfterMinutes = AppSettings.defaultMissedAfterMinutes
    @AppStorage(AppSettings.snoozeMinutesKey) private var snoozeMinutes = AppSettings.defaultSnoozeMinutes
    @State private var now = Date()
    private let clock = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var grace: TimeInterval { TimeInterval(missedAfterMinutes * 60) }

    private var slots: [DoseSlot] {
        _ = events.count
        return DoseScheduler.slots(for: Array(medications), on: now)
    }

    /// Oldest overdue dose, else the oldest missed dose without a record (it can still be confirmed late),
    /// else the next upcoming one.
    private var featured: DoseSlot? {
        let open = slots.filter { $0.event == nil }
        let overdue = open.first { $0.status(now: now, grace: grace) == .pending && $0.scheduledAt <= now }
        let missed = open.first { $0.status(now: now, grace: grace) == .missed }
        let upcoming = open.first { $0.scheduledAt > now }
        return overdue ?? missed ?? upcoming
    }

    private var takenCount: Int { slots.filter { $0.status(now: now, grace: grace) == .taken }.count }
    private var lowStock: [Medication] { medications.filter(\.isLowStock) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let featured {
                        NextDoseCard(slot: featured, now: now, grace: grace, snoozeMinutes: snoozeMinutes,
                                     onTaken: { take(featured) },
                                     onSnooze: { snooze(featured) },
                                     onSkip: { skip(featured) })
                    } else if slots.isEmpty {
                        emptyState
                    } else {
                        allDoneCard
                    }

                    if !lowStock.isEmpty {
                        LowStockBanner(medications: lowStock)
                    }

                    if !slots.isEmpty {
                        timeline
                    }
                }
                .padding()
            }
            .navigationTitle(Text("Today"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        state.showingExtraDose = true
                    } label: {
                        Label("Log extra dose", systemImage: "plus")
                    }
                    .disabled(medications.isEmpty)
                }
                ToolbarItem(placement: .automatic) {
                    if !slots.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                            Text(verbatim: "\(takenCount) / \(slots.count)")
                        }
                        .font(.headline)
                        .foregroundStyle(Palette.taken)
                        .accessibilityLabel(Text("Taken \(takenCount) of \(slots.count)"))
                    }
                }
            }
            .onReceive(clock) { now = $0 }
            .onAppear { now = Date() }
        }
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Whole day")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.bottom, 6)
            ForEach(slots) { slot in
                DoseRow(slot: slot, now: now, grace: grace, compact: true,
                        onTaken: { take(slot) }, onSkipped: { skip(slot) }, onReset: { reset(slot) })
                Divider()
            }
        }
    }

    private var allDoneCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("All done for today", systemImage: "checkmark.circle.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(Palette.taken)
            Text("Every scheduled dose is recorded.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.taken, lineWidth: 2))
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No doses today", systemImage: "pills")
        } description: {
            Text("Add a medication in the Medications tab to get reminders.")
        }
    }

    private func take(_ slot: DoseSlot) {
        DoseLogger(context: context).markTaken(slot)
        NotificationService.shared.clearDelivered(for: slot.medication)
    }

    private func skip(_ slot: DoseSlot) {
        DoseLogger(context: context).markSkipped(slot)
        NotificationService.shared.clearDelivered(for: slot.medication)
    }

    private func reset(_ slot: DoseSlot) {
        DoseLogger(context: context).reset(slot)
    }

    private func snooze(_ slot: DoseSlot) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: slot.scheduledAt)
        let minutesOfDay = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        NotificationService.shared.snooze(medication: slot.medication, minutesOfDay: minutesOfDay, after: snoozeMinutes)
        NotificationService.shared.clearDelivered(for: slot.medication)
    }
}

struct LowStockBanner: View {
    let medications: [Medication]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(medications) { medication in
                Label {
                    Text("\(medication.name): \(DoseFormatter.units(medication.stockCount)) left")
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Palette.overdue)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Palette.overdue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    TodayView()
        .environment(AppState())
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
