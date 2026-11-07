// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Combine
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
    @State private var confirming: PendingTake?
    @State private var undo: UndoTake?
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

    /// "Before a meal" doses taken today whose waiting time is still running.
    private var mealWaits: [(name: String, readyAt: Date)] {
        slots.compactMap { slot in
            guard let event = slot.event, let readyAt = DoseScheduler.mealReadyTime(for: event), readyAt > now else { return nil }
            return (slot.medication.name, readyAt)
        }
        .sorted { $0.readyAt < $1.readyAt }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if NotificationService.shared.remindersOff, !medications.isEmpty {
                        RemindersOffBanner(denied: NotificationService.shared.authorizationStatus == .denied)
                    }

                    if let featured {
                        NextDoseCard(slot: featured, now: now, grace: grace, snoozeMinutes: snoozeMinutes,
                                     onTaken: { requestTake(featured) },
                                     onSnooze: { snooze(featured) },
                                     onSkip: { skip(featured) },
                                     takeMode: takeMode(for: featured),
                                     onTakeEarly: { requestTake(featured) })
                    } else if slots.isEmpty {
                        emptyState
                    } else {
                        allDoneCard
                    }

                    if let last = mealWaits.last {
                        MealWaitBanner(readyAt: last.readyAt, names: mealWaits.map(\.name).uniqued())
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
            .safeAreaInset(edge: .bottom) {
                if let undo {
                    UndoBanner(info: undo) {
                        DoseLogger(context: context).reset(undo.slot)
                        self.undo = nil
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.default, value: undo?.id)
            .confirmationDialog(Text("Take this dose?"), isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }),
                                titleVisibility: .visible, presenting: confirming) { pending in
                Button("Take anyway", role: .destructive) { take(pending.slot) }
                Button("Cancel", role: .cancel) {}
            } message: { pending in
                Text(pending.message)
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
                        onTaken: { requestTake(slot) }, onSkipped: { skip(slot) }, onReset: { reset(slot) })
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
            Text(medications.isEmpty
                 ? "Add your first medication with its dose and times. Vzato then reminds you."
                 : "Nothing is scheduled for today.")
        } actions: {
            if medications.isEmpty {
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
            }
        }
    }

    private func takeMode(for slot: DoseSlot) -> NextDoseCard.TakeMode {
        switch DoseGuard.verdict(for: slot, now: now) {
        case .ok: .direct
        case .tooEarly: .notYet
        case .recentlyTaken:
            slot.scheduledAt.timeIntervalSince(now) > DoseGuard.earlyWindow ? .notYet : .askFirst
        }
    }

    /// Every "Taken" in Today goes through here: one tap when safe, a question when not.
    private func requestTake(_ slot: DoseSlot) {
        let verdict = DoseGuard.verdict(for: slot, now: Date())
        if verdict == .ok {
            take(slot)
        } else {
            confirming = PendingTake(slot: slot, verdict: verdict)
        }
    }

    private func take(_ slot: DoseSlot) {
        let event = DoseLogger(context: context).markTaken(slot)
        NotificationService.shared.clearDelivered(for: slot.medication)
        let info = UndoTake(slot: DoseSlot(medication: slot.medication, scheduledAt: slot.scheduledAt, event: event),
                            takenAt: event.takenAt ?? Date())
        undo = info
        Task {
            try? await Task.sleep(for: .seconds(8))
            if undo?.id == info.id { undo = nil }
        }
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

/// Shown while the waiting time after a "before a meal" dose runs.
struct MealWaitBanner: View {
    let readyAt: Date
    let names: [String]

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "fork.knife")
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Eat from \(readyAt.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline.weight(.semibold))
                Text(names.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text(readyAt, style: .timer)
                .font(.subheadline.monospacedDigit().weight(.semibold))
        }
        .foregroundStyle(Color(hex: "2E5FA3"))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(hex: "3B7DD8").opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

/// Shown on Today while the system blocks reminders, so a silent 12:00 does not come as a surprise.
struct RemindersOffBanner: View {
    /// Refused in the system settings; otherwise the app has not asked yet.
    let denied: Bool
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reminders are off")
                        .font(.subheadline.weight(.bold))
                    Text("Without notifications you will not hear or see a reminder at dose time, not even on the lock screen.")
                        .font(.caption)
                }
            } icon: {
                Image(systemName: "bell.slash.fill")
            }
            Button {
                if denied {
                    if let url = URL(string: Self.settingsURL) { openURL(url) }
                } else {
                    Task { await NotificationService.shared.requestAuthorization() }
                }
            } label: {
                Text(denied ? "Open settings" : "Allow notifications")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.missed)
            .accessibilityIdentifier("allowNotifications")
        }
        .foregroundStyle(Palette.missed)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Palette.missed.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    static var settingsURL: String {
        #if os(iOS)
        UIApplication.openNotificationSettingsURLString
        #else
        "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=app.vzato"
        #endif
    }
}

struct LowStockBanner: View {
    let medications: [Medication]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(medications) { medication in
                Label {
                    Text("\(medication.name): \(medication.stockAmountText) left")
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

struct PendingTake: Identifiable {
    let id = UUID()
    let slot: DoseSlot
    let verdict: DoseGuard.Verdict

    var message: String {
        switch verdict {
        case .recentlyTaken(let at):
            return String(localized: "\(slot.medication.name) was already taken at \(at.formatted(date: .omitted, time: .shortened)). Take another dose now?")
        case .tooEarly(let at):
            return String(localized: "This dose is planned for \(at.formatted(date: .omitted, time: .shortened)). Take it now, early?")
        case .ok:
            return ""
        }
    }
}

struct UndoTake: Identifiable {
    let id = UUID()
    let slot: DoseSlot
    let takenAt: Date
}

/// A few seconds to take back a tap on "Taken".
struct UndoBanner: View {
    let info: UndoTake
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.taken)
            Text("Taken: \(info.slot.medication.name) at \(info.takenAt.formatted(date: .omitted, time: .shortened))")
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
            Spacer(minLength: 8)
            Button("Undo", action: onUndo)
                .font(.subheadline.weight(.bold))
                .accessibilityIdentifier("undoTaken")
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
    }
}

extension Array where Element: Hashable {
    /// Keeps the first occurrence of each element, in order.
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
