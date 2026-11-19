// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData
import Foundation
import Observation
import UserNotifications

/// Local notifications. No push server; everything is scheduled on the device.
///
/// The rule: at dose time one reminder with every medication due then. Not confirmed? It repeats
/// `repeatCount` times every `snoozeMinutes`, never after the dose counts as missed, then stops.
/// Confirming anywhere (app, widget, another device) removes what is left. Reminders are planned
/// per concrete dose up to two weeks ahead; the plan is rebuilt whenever the app runs, after every
/// change, and once a day in the background.
@MainActor
@Observable
final class NotificationService: NSObject, UNUserNotificationCenterDelegate, DoseNotifying {
    static let shared = NotificationService()

    enum Category {
        static let dose = "DOSE_REMINDER"
        static let lowStock = "LOW_STOCK"
        static let plan = "PLAN"
    }

    enum Action {
        static let taken = "TAKEN"
        static let snooze = "SNOOZE"
        static let skip = "SKIP"
    }

    /// iOS keeps at most 64 pending local notifications per app.
    static let pendingLimit = 60

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var scheduledCount = 0
    /// Doses up to this time have their reminders scheduled; nil when nothing is scheduled.
    private(set) var plannedUntil: Date?
    /// The budget ran out before the two-week horizon; a "open Vzato" reminder is set for the end.
    private(set) var hitLimit = false

    /// System settings that silently weaken reminders although notifications are allowed.
    private(set) var deliveryIssues: [DeliveryIssue] = []

    /// True when reminders cannot reach the user: permission refused, or never asked yet.
    var remindersOff: Bool { authorizationStatus == .denied || authorizationStatus == .notDetermined }

    private var context: NSManagedObjectContext?
    private let center = UNUserNotificationCenter.current()
    private var rescheduling: Task<Void, Never>?
    private var replan: Task<Void, Never>?

    private override init() {
        super.init()
    }

    func configure(context: NSManagedObjectContext) {
        self.context = context
        center.delegate = self
        registerCategories()
        // Travelling to another time zone moves every dose time; a new day widens the plan.
        for name in [Notification.Name.NSSystemTimeZoneDidChange, .NSCalendarDayChanged] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { NotificationService.shared.scheduleReplan() }
            }
        }
        Task {
            await refreshAuthorizationStatus()
            await rescheduleAll()
        }
    }

    // MARK: Authorization

    func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        await refreshAuthorizationStatus()
    }

    func refreshAuthorizationStatus() async {
        let snapshot: (UNAuthorizationStatus, [DeliveryIssue]) = await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: (settings.authorizationStatus, DeliveryIssue.issues(in: settings)))
            }
        }
        authorizationStatus = snapshot.0
        deliveryIssues = snapshot.1
    }

    private func registerCategories() {
        let taken = UNNotificationAction(identifier: Action.taken, title: String(localized: "Taken"), options: [])
        let snooze = UNNotificationAction(identifier: Action.snooze, title: String(localized: "Snooze \(AppSettings.snoozeMinutes) min"), options: [])
        let skip = UNNotificationAction(identifier: Action.skip, title: String(localized: "Skip"), options: [.destructive])
        let dose = UNNotificationCategory(identifier: Category.dose, actions: [taken, snooze, skip], intentIdentifiers: [], options: [])
        let lowStock = UNNotificationCategory(identifier: Category.lowStock, actions: [], intentIdentifiers: [], options: [])
        let plan = UNNotificationCategory(identifier: Category.plan, actions: [], intentIdentifiers: [], options: [])
        center.setNotificationCategories([dose, lowStock, plan])
    }

    // MARK: Scheduling

    /// Rebuilds every reminder from the current data. Called at launch, when the app becomes active,
    /// after any change and from the background refresh. Calls run one after another, so two
    /// overlapping rebuilds cannot remove each other's requests.
    func rescheduleAll() async {
        let previous = rescheduling
        let task = Task { @MainActor in
            await previous?.value
            await performReschedule()
        }
        rescheduling = task
        await task.value
    }

    /// Several changes in a row (a dose confirmed, the widget's write merged, sync) become one rebuild.
    func scheduleReplan() {
        replan?.cancel()
        replan = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await self?.rescheduleAll()
        }
    }

    private func performReschedule() async {
        guard let context else { return }
        // The widget plans follow-ups and meal reminders with the same settings, and the Snooze
        // button names the current snooze time.
        AppSettings.shareWithWidgets()
        registerCategories()
        let calendar = Calendar.current
        let request = Medication.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == NO")
        let medications = (try? context.fetch(request)) ?? []
        let byID = Dictionary(medications.compactMap { medication in medication.id.map { ($0, medication) } }, uniquingKeysWith: { a, _ in a })

        // Without permission iOS accepts the requests but never shows them. Ask as soon as there is
        // something to remind of; the system shows its prompt only once.
        await refreshAuthorizationStatus()
        if authorizationStatus == .notDetermined,
           medications.contains(where: { !$0.activeSchedules.isEmpty }) {
            await requestAuthorization()
        }

        // Meal reminders belong to doses already taken and stay. Snoozes stay while their dose is
        // open: the person asked for them, and a rebuild must not take them away.
        let pending = await center.pendingNotificationRequests()
        // Read the time only now: the permission prompt above can wait for the person for a while.
        let now = Date()
        var kept = 0
        var snoozed: [String: Set<UUID>] = [:]
        var remove: [String] = []
        for item in pending {
            if item.identifier.hasPrefix("meal|") {
                kept += 1
            } else if item.identifier.hasPrefix("snooze|"), let group = Self.group(of: item.content.userInfo),
                      Self.isOpen(group, medications: byID, calendar: calendar) {
                kept += 1
                for dose in group.doses { snoozed["\(group.dayKey)|\(dose.minutes)", default: []].insert(dose.id) }
            } else {
                remove.append(item.identifier)
            }
        }
        center.removePendingNotificationRequests(withIdentifiers: remove)

        var count = kept
        // Supply warnings first: few, and far-away dose reminders must not squeeze them out.
        count += scheduleRunOutWarnings(for: medications, now: now, calendar: calendar)

        let settings = ReminderPlanner.Settings(snoozeMinutes: AppSettings.snoozeMinutes, repeatCount: AppSettings.repeatCount,
                                                missedAfterMinutes: AppSettings.missedAfterMinutes)
        let window = DateInterval(start: now.addingTimeInterval(-TimeInterval(settings.missedAfterMinutes * 60)),
                                  end: now.addingTimeInterval(TimeInterval(ReminderPlanner.horizonDays * 24 * 60 * 60)))
        let slots = DoseScheduler.slots(for: medications, in: window, calendar: calendar).filter { $0.event == nil && !$0.isUnscheduled && !DoseScheduler.isCoveredByMovedDose($0, calendar: calendar) }
        let plan = ReminderPlanner.plan(slots: slots, now: now, settings: settings, budget: Self.pendingLimit - count - 1,
                                        skipping: snoozed, organizer: { slot in
                                            OrganizerService.compartment(of: slot, calendar: calendar).map { compartment in
                                                ("\(slot.medication.profile?.objectID.uriRepresentation().absoluteString ?? "")|\(compartment.rawValue)", compartment)
                                            }
                                        }, calendar: calendar)
        for reminder in plan.reminders {
            let content = doseContent(for: reminder.medicationIDs.compactMap { byID[$0] }, reminder: reminder, totalAttempts: settings.repeatCount)
            add(id: reminder.identifier, content: content, at: reminder.fireAt, calendar: calendar)
            count += 1
        }
        if plan.limited, let until = plan.plannedUntil {
            addPlanReminder(after: until, calendar: calendar)
            count += 1
        }
        scheduledCount = count
        plannedUntil = plan.plannedUntil
        hitLimit = plan.limited
        pruneDelivered(calendar: calendar)
    }

    /// Title, lines and sound for one reminder of a group of doses.
    private func doseContent(for medications: [Medication], reminder: PlannedReminder, totalAttempts: Int) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let lines = medications.map { medication in
            medication.dosageText.isEmpty
                ? "\(medication.nameWithProfile) · \(medication.doseAmountText)"
                : "\(medication.nameWithProfile) · \(medication.doseAmountText) (\(medication.dosageText))"
        }
        if reminder.attempt == 0 {
            if let compartment = reminder.compartment {
                content.title = compartment.reminderTitle(medications.map(\.nameWithProfile).formatted(.list(type: .and)))
                content.body = lines.joined(separator: "\n")
            } else if medications.count == 1, let medication = medications.first {
                content.title = medication.nameWithProfile
                content.body = medication.dosageText.isEmpty
                    ? String(localized: "Time to take \(medication.doseAmountText).")
                    : String(localized: "Time to take \(medication.doseAmountText) (\(medication.dosageText)).")
            } else {
                content.title = String(localized: "\(medications.count) medications")
                content.body = lines.joined(separator: "\n")
            }
        } else {
            content.title = String(localized: "Not confirmed yet")
            content.subtitle = String(localized: "Reminder \(reminder.attempt) of \(totalAttempts)")
            content.body = (lines + [String(localized: "Tap Taken when you have taken it.")]).joined(separator: "\n")
        }
        content.sound = AppSettings.doseSound.notificationSound
        content.interruptionLevel = AppSettings.breaksThroughFocus ? .timeSensitive : .active
        content.categoryIdentifier = Category.dose
        content.threadIdentifier = "dose|\(reminder.groupKey)"
        var info: [String: Any] = ["day": reminder.dayKey, "minutesOfDay": reminder.minutesOfDay,
                                   "medicationIDs": reminder.medicationIDs.map(\.uuidString),
                                   "doseMinutes": reminder.resolvedDoseMinutes]
        if let compartment = reminder.compartment { info["compartment"] = compartment.rawValue }
        content.userInfo = info
        return content
    }

    /// Planned reminders end before the horizon: say so, half an hour after the last one.
    private func addPlanReminder(after until: Date, calendar: Calendar) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Reminders are planned until \(until.formatted(date: .abbreviated, time: .omitted))")
        content.body = String(localized: "Open Vzato so they continue after that.")
        content.categoryIdentifier = Category.plan
        content.threadIdentifier = "plan"
        content.interruptionLevel = .active
        add(id: "plan", content: content, at: until.addingTimeInterval(30 * 60), calendar: calendar)
    }

    /// One silent notification per tracked medication, `runOutWarningDays` before the projected
    /// run-out, at 9:00. Returns how many were scheduled.
    private func scheduleRunOutWarnings(for medications: [Medication], now: Date, calendar: Calendar) -> Int {
        let days = AppSettings.runOutWarningDays
        guard days > 0, AppSettings.lowStockNotificationsEnabled else { return 0 }
        var count = 0
        for medication in medications where medication.tracksStock {
            guard let runOut = StockService.projectedRunOutDate(for: medication, from: now, calendar: calendar),
                  let warnDay = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: runOut)),
                  let fire = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: warnDay),
                  fire > now, let id = medication.id,
                  RunOutWarningLog.shouldSchedule(fire: fire, previous: RunOutWarningLog.previousFire(for: id), now: now,
                                                  windowDays: days, calendar: calendar) else { continue }
            RunOutWarningLog.record(fire, for: id)
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Supply of \(medication.name) is running out")
            content.body = String(localized: "Runs out on \(runOut.formatted(date: .long, time: .omitted)). Time to get more.")
            content.categoryIdentifier = Category.lowStock
            content.threadIdentifier = "lowstock"
            content.interruptionLevel = .passive
            add(id: "runout|\(medication.id?.uuidString ?? "")", content: content, at: fire, calendar: calendar)
            count += 1
        }
        return count
    }

    private func add(id: String, content: UNNotificationContent, at date: Date, calendar: Calendar) {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger)) { _ in }
    }

    // MARK: Meals, stock, snooze

    static func mealReadyID(medicationID: UUID?, scheduledAt: Date) -> String {
        "meal|\(medicationID?.uuidString ?? "")|\(Int(scheduledAt.timeIntervalSince1970))"
    }

    func scheduleMealReady(medicationID: UUID?, name: String, scheduledAt: Date, at readyAt: Date, waitMinutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "You can eat now")
        content.body = String(localized: "\(waitMinutes) minutes have passed since \(name).")
        content.sound = AppSettings.mealSound.notificationSound
        content.threadIdentifier = "meal"
        let interval = max(1, readyAt.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.add(UNNotificationRequest(identifier: Self.mealReadyID(medicationID: medicationID, scheduledAt: scheduledAt),
                                         content: content, trigger: trigger)) { _ in }
    }

    func cancelMealReady(medicationID: UUID?, scheduledAt: Date) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.mealReadyID(medicationID: medicationID, scheduledAt: scheduledAt)])
    }

    /// A dose was recorded (anywhere): the plan is rebuilt, which drops its follow-ups and clears
    /// delivered reminders that have nothing open left.
    func doseResolved(medicationID: UUID?, scheduledAt: Date) {
        scheduleReplan()
    }

    func notifyLowStock(_ medication: Medication) {
        guard AppSettings.lowStockNotificationsEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Running low: \(medication.name)")
        content.body = medication.isOutOfStock
            ? String(localized: "You are out. Get more as soon as you can.")
            : String(localized: "Only \(medication.stockAmountText) left. Time to get more.")
        content.categoryIdentifier = Category.lowStock
        content.threadIdentifier = "lowstock"
        content.interruptionLevel = .passive
        let id = "lowstock|\(medication.id?.uuidString ?? "")"
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil)) { _ in }
    }

    /// Snooze from the Today card: one dose, its own group.
    func snooze(_ slot: DoseSlot) {
        snooze([slot], compartment: nil)
    }

    /// Snooze a whole organizer compartment from the Today card: one snoozed reminder for all of it.
    func snooze(_ slots: [DoseSlot], compartment: Compartment?) {
        let calendar = Calendar.current
        func minutes(_ date: Date) -> Int { calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date) }
        let doses = slots.sorted { $0.scheduledAt < $1.scheduledAt }
            .compactMap { slot in slot.medication.id.map { DoseGroup.Dose(id: $0, minutes: minutes(slot.scheduledAt)) } }
        guard let first = slots.map(\.scheduledAt).min(), !doses.isEmpty else { return }
        enqueueSnooze(DoseGroup(dayKey: ReminderPlanner.dayKey(for: first, calendar: calendar), minutesOfDay: minutes(first),
                                doses: doses, compartment: compartment))
    }

    /// Snoozes run in the same queue as rebuilds, so a rebuild never sees half a snooze.
    private func enqueueSnooze(_ group: DoseGroup) {
        let previous = rescheduling
        let task = Task { @MainActor in
            await previous?.value
            await snooze(group)
            await performReschedule()
        }
        rescheduling = task
    }

    /// "Snooze": the reminder comes back after the snooze time and repeats from there like a fresh
    /// one. Medications of the same time snoozed earlier and still open come along, so a time keeps
    /// one snoozed reminder. The rebuild that follows plans the rest of the group without them.
    private func snooze(_ group: DoseGroup) async {
        guard let context else { return }
        let settings = ReminderPlanner.Settings(snoozeMinutes: AppSettings.snoozeMinutes, repeatCount: AppSettings.repeatCount,
                                                missedAfterMinutes: AppSettings.missedAfterMinutes)
        let calendar = Calendar.current
        var doses = group.doses
        var compartment = group.compartment
        for item in await center.pendingNotificationRequests() where item.identifier.hasPrefix("snooze|") {
            guard let earlier = Self.group(of: item.content.userInfo), earlier.key == group.key else { continue }
            doses += earlier.doses.filter { !doses.contains($0) }
            compartment = compartment ?? earlier.compartment
        }
        let byID = Self.medications(for: doses.map(\.id), in: context)
        let open = doses.filter { dose in
            group.doses.contains(dose) || Self.isOpen(group.single(dose), medications: byID, calendar: calendar)
        }.filter { byID[$0.id] != nil }
        let medications = open.compactMap { byID[$0.id] }
        center.removePendingNotificationRequests(withIdentifiers: (0...3).map { "snooze|\(group.key)|\($0)" })
        guard !medications.isEmpty else { return }
        let base = Date().addingTimeInterval(TimeInterval(settings.snoozeMinutes * 60))
        for attempt in 0...max(0, settings.repeatCount) {
            let fireAt = base.addingTimeInterval(TimeInterval(attempt * settings.snoozeMinutes * 60))
            let reminder = PlannedReminder(dayKey: group.dayKey, minutesOfDay: group.minutesOfDay, attempt: attempt,
                                           fireAt: fireAt, medicationIDs: open.map(\.id), doseMinutes: open.map(\.minutes),
                                           compartment: compartment)
            // Awaited, so the rebuild right after sees the snooze and plans around it.
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireAt)
            try? await center.add(UNNotificationRequest(
                identifier: "snooze|\(group.key)|\(attempt)",
                content: doseContent(for: medications, reminder: reminder, totalAttempts: settings.repeatCount),
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)))
        }
    }

    /// The widget recorded a dose. Its process cannot rebuild the plan (only the app does, the next
    /// time it runs), so it updates the pending reminders of that time on its own: a reminder with
    /// nothing open left is removed, one shared with other medications is rewritten for the rest.
    /// Without this, "Not confirmed yet" would follow a dose confirmed in the widget.
    func widgetResolvedDose(of medication: Medication, scheduledAt: Date, in context: NSManagedObjectContext) async {
        guard let id = medication.id else { return }
        let calendar = Calendar.current
        let dayKey = ReminderPlanner.dayKey(for: scheduledAt, calendar: calendar)
        let minutes = calendar.component(.hour, from: scheduledAt) * 60 + calendar.component(.minute, from: scheduledAt)
        let resolved = DoseGroup.Dose(id: id, minutes: minutes)
        for item in await center.pendingNotificationRequests()
        where item.identifier.hasPrefix("dose|") || item.identifier.hasPrefix("snooze|") {
            guard let group = Self.group(of: item.content.userInfo), group.dayKey == dayKey,
                  group.doses.contains(resolved) else { continue }
            let (open, byID) = Self.stillOpen(group, excluding: resolved, in: context, calendar: calendar)
            if open.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: [item.identifier])
            } else {
                let attempt = item.identifier.split(separator: "|").last.flatMap { Int($0) } ?? 0
                let reminder = PlannedReminder(dayKey: dayKey, minutesOfDay: group.minutesOfDay, attempt: attempt, fireAt: Date(),
                                               medicationIDs: open.map(\.id), doseMinutes: open.map(\.minutes),
                                               compartment: group.compartment)
                let content = doseContent(for: open.compactMap { byID[$0.id] }, reminder: reminder, totalAttempts: AppSettings.repeatCount)
                // The same identifier replaces the pending request and keeps its time.
                try? await center.add(UNNotificationRequest(identifier: item.identifier, content: content, trigger: item.trigger))
            }
        }
    }

    /// The doses of a reminder that still have no record, leaving out one just recorded (its write
    /// may not be visible to every fetch yet).
    static func stillOpen(_ group: DoseGroup, excluding resolved: DoseGroup.Dose, in context: NSManagedObjectContext,
                          calendar: Calendar) -> (doses: [DoseGroup.Dose], medications: [UUID: Medication]) {
        let byID = medications(for: group.medicationIDs, in: context)
        let open = group.doses.filter { dose in
            dose != resolved && isOpen(group.single(dose), medications: byID, calendar: calendar)
        }
        return (open, byID)
    }

    static func medications(for ids: [UUID], in context: NSManagedObjectContext) -> [UUID: Medication] {
        let request = Medication.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", ids)
        return Dictionary(((try? context.fetch(request)) ?? []).compactMap { medication in medication.id.map { ($0, medication) } },
                          uniquingKeysWith: { a, _ in a })
    }

    // MARK: Delivered reminders

    /// Removes a delivered reminder that was only about this medication (the widget confirmed it).
    /// Reminders shared with other medications are cleaned up by the next plan rebuild.
    func clearDelivered(for medication: Medication) {
        guard let medicationID = medication.id?.uuidString else { return }
        center.getDeliveredNotifications { notifications in
            let ids = notifications.filter { notification in
                let info = notification.request.content.userInfo
                let group = info["medicationIDs"] as? [String] ?? (info["medicationID"] as? String).map { [$0] } ?? []
                return group == [medicationID]
            }.map(\.request.identifier)
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
        }
    }

    /// Takes delivered dose reminders off the lock screen once none of their doses is open any more.
    private func pruneDelivered(calendar: Calendar) {
        center.getDeliveredNotifications { [weak self] notifications in
            // Only plain values leave this queue; the managed objects stay on the main actor.
            let groups: [(id: String, group: DoseGroup)] = notifications.compactMap { notification in
                guard notification.request.content.categoryIdentifier == Category.dose,
                      let group = NotificationService.group(of: notification.request.content.userInfo, fallbackDay: notification.date) else { return nil }
                return (notification.request.identifier, group)
            }
            guard !groups.isEmpty else { return }
            Task { @MainActor in self?.removeStaleDelivered(groups, calendar: calendar) }
        }
    }

    private func removeStaleDelivered(_ groups: [(id: String, group: DoseGroup)], calendar: Calendar) {
        guard let context else { return }
        let request = Medication.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == NO")
        let medications = (try? context.fetch(request)) ?? []
        let byID = Dictionary(medications.compactMap { medication in medication.id.map { ($0, medication) } }, uniquingKeysWith: { a, _ in a })
        let stale = groups.filter { !Self.isOpen($0.group, medications: byID, calendar: calendar) }.map(\.id)
        if !stale.isEmpty { center.removeDeliveredNotifications(withIdentifiers: stale) }
    }

    /// The doses one notification stands for: usually every medication due at one time, or the
    /// doses of one organizer compartment, each with its own time.
    struct DoseGroup: Sendable {
        struct Dose: Sendable, Hashable {
            let id: UUID
            let minutes: Int
        }
        let dayKey: String
        /// When the notification is about: the earliest dose.
        let minutesOfDay: Int
        let doses: [Dose]
        var compartment: Compartment?

        init(dayKey: String, minutesOfDay: Int, doses: [Dose], compartment: Compartment? = nil) {
            self.dayKey = dayKey
            self.minutesOfDay = minutesOfDay
            self.doses = doses
            self.compartment = compartment
        }

        /// Every medication at the same time.
        init(dayKey: String, minutesOfDay: Int, medicationIDs: [UUID]) {
            self.init(dayKey: dayKey, minutesOfDay: minutesOfDay, doses: medicationIDs.map { Dose(id: $0, minutes: minutesOfDay) })
        }

        var key: String { "\(dayKey)|\(minutesOfDay)" }
        var medicationIDs: [UUID] {
            var seen = Set<UUID>()
            return doses.map(\.id).filter { seen.insert($0).inserted }
        }

        func single(_ dose: Dose) -> DoseGroup {
            DoseGroup(dayKey: dayKey, minutesOfDay: dose.minutes, doses: [dose], compartment: compartment)
        }
    }

    nonisolated static func group(of userInfo: [AnyHashable: Any], fallbackDay: Date? = nil) -> DoseGroup? {
        guard let minutes = userInfo["minutesOfDay"] as? Int else { return nil }
        let ids = (userInfo["medicationIDs"] as? [String] ?? (userInfo["medicationID"] as? String).map { [$0] } ?? [])
            .compactMap(UUID.init(uuidString:))
        guard !ids.isEmpty else { return nil }
        let dayKey = userInfo["day"] as? String ?? fallbackDay.map { ReminderPlanner.dayKey(for: $0) }
        guard let dayKey else { return nil }
        // Older reminders and plain ones: every dose at the reminder's time.
        let doseMinutes = (userInfo["doseMinutes"] as? [Int]).flatMap { $0.count == ids.count ? $0 : nil }
            ?? ids.map { _ in minutes }
        return DoseGroup(dayKey: dayKey, minutesOfDay: minutes,
                         doses: zip(ids, doseMinutes).map { DoseGroup.Dose(id: $0, minutes: $1) },
                         compartment: (userInfo["compartment"] as? String).flatMap(Compartment.init(rawValue:)))
    }

    /// True while at least one dose of the group has no record yet.
    private static func isOpen(_ group: DoseGroup, medications: [UUID: Medication], calendar: Calendar) -> Bool {
        guard let day = ReminderPlanner.day(fromKey: group.dayKey, calendar: calendar) else { return false }
        return group.doses.contains { dose in
            guard let medication = medications[dose.id] else { return false }
            return DoseScheduler.slots(for: [medication], on: day, calendar: calendar).contains { slot in
                !slot.isUnscheduled && slot.event == nil
                    && calendar.component(.hour, from: slot.scheduledAt) * 60 + calendar.component(.minute, from: slot.scheduledAt) == dose.minutes
            }
        }
    }

    // MARK: Responses

    /// Returns once the reminders are rebuilt: after a Taken from the lock screen iOS may suspend the
    /// app right after the completion handler, and the dose's follow-ups must be gone by then.
    private func handle(action: String, group: DoseGroup) async {
        guard let context, let day = ReminderPlanner.day(fromKey: group.dayKey) else { return }
        let calendar = Calendar.current
        let request = Medication.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", group.medicationIDs)
        let medications = (try? context.fetch(request)) ?? []
        guard !medications.isEmpty else { return }

        if action == Action.snooze {
            enqueueSnooze(group)
            await rescheduling?.value
            return
        }
        let logger = DoseLogger(context: context, notifier: self)
        let byID = Dictionary(medications.compactMap { medication in medication.id.map { ($0, medication) } }, uniquingKeysWith: { a, _ in a })
        // A medication twice in one organizer compartment: both doses are in the person's hand.
        var recordedNow = Set<UUID>()
        for dose in group.doses {
            guard let medication = byID[dose.id] else { continue }
            let scheduledAt = calendar.date(bySettingHour: dose.minutes / 60, minute: dose.minutes % 60, second: 0, of: day) ?? day
            let slot = DoseScheduler.slots(for: [medication], on: day, calendar: calendar)
                .first { calendar.isDate($0.scheduledAt, equalTo: scheduledAt, toGranularity: .minute) && !$0.isUnscheduled }
                ?? DoseSlot(medication: medication, scheduledAt: scheduledAt, event: nil)
            guard slot.event == nil else { continue }
            switch action {
            case Action.taken:
                // The Today card asks before a second dose; from the lock screen nobody can be asked,
                // so a dose right after another one is not recorded, and the person is told why.
                if !recordedNow.contains(dose.id), case .recentlyTaken(let last) = DoseGuard.verdict(for: slot, now: Date()) {
                    notifyNotRecorded(medication, takenAt: last)
                    continue
                }
                logger.markTaken(slot, source: .notification)
                recordedNow.insert(dose.id)
            case Action.skip: logger.markSkipped(slot, source: .notification)
            default: break
            }
        }
        await rescheduleAll()
    }

    private func notifyNotRecorded(_ medication: Medication, takenAt: Date) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Not recorded: \(medication.nameWithProfile)")
        content.body = String(localized: "It was already taken at \(takenAt.formatted(date: .omitted, time: .shortened)). If you really took another dose, record it in Vzato.")
        content.threadIdentifier = "dose|notrecorded"
        content.interruptionLevel = .active
        center.add(UNNotificationRequest(identifier: "notrecorded|\(medication.id?.uuidString ?? "")", content: content, trigger: nil)) { _ in }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let action = response.actionIdentifier
        let group = Self.group(of: response.notification.request.content.userInfo, fallbackDay: response.notification.date)
        nonisolated(unsafe) let completion = completionHandler
        Task { @MainActor in
            if let group { await self.handle(action: action, group: group) }
            completion()
        }
    }
}

extension ReminderSound {
    var notificationSound: UNNotificationSound {
        guard let fileName else { return .default }
        return UNNotificationSound(named: UNNotificationSoundName(fileName))
    }
}
