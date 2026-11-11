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
        let status: UNAuthorizationStatus = await withCheckedContinuation { continuation in
            center.getNotificationSettings { continuation.resume(returning: $0.authorizationStatus) }
        }
        authorizationStatus = status
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
        let now = Date()
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
        var kept = 0
        var snoozedGroups = Set<String>()
        var remove: [String] = []
        for item in pending {
            if item.identifier.hasPrefix("meal|") {
                kept += 1
            } else if item.identifier.hasPrefix("snooze|"), let group = Self.group(of: item.content.userInfo),
                      Self.isOpen(group, medications: byID, calendar: calendar) {
                kept += 1
                snoozedGroups.insert(group.key)
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
        let slots = DoseScheduler.slots(for: medications, in: window, calendar: calendar).filter { $0.event == nil && !$0.isUnscheduled }
        let plan = ReminderPlanner.plan(slots: slots, now: now, settings: settings, budget: Self.pendingLimit - count - 1,
                                        skipping: snoozedGroups, calendar: calendar)
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
            if medications.count == 1, let medication = medications.first {
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
        content.userInfo = ["day": reminder.dayKey, "minutesOfDay": reminder.minutesOfDay,
                            "medicationIDs": reminder.medicationIDs.map(\.uuidString)]
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
                  fire > now else { continue }
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
        guard let id = slot.medication.id else { return }
        let calendar = Calendar.current
        let minutes = calendar.component(.hour, from: slot.scheduledAt) * 60 + calendar.component(.minute, from: slot.scheduledAt)
        let group = DoseGroup(dayKey: ReminderPlanner.dayKey(for: slot.scheduledAt, calendar: calendar), minutesOfDay: minutes, medicationIDs: [id])
        snooze(group, medications: [slot.medication])
    }

    /// "Snooze": the reminder comes back after the snooze time and repeats from there like a fresh
    /// one. The planned follow-ups of the group make way for it.
    private func snooze(_ group: DoseGroup, medications: [Medication]) {
        let settings = ReminderPlanner.Settings(snoozeMinutes: AppSettings.snoozeMinutes, repeatCount: AppSettings.repeatCount,
                                                missedAfterMinutes: AppSettings.missedAfterMinutes)
        let calendar = Calendar.current
        let base = Date().addingTimeInterval(TimeInterval(settings.snoozeMinutes * 60))
        let stale = (0...3).flatMap { ["dose|\(group.key)|\($0)", "snooze|\(group.key)|\($0)"] }
        center.removePendingNotificationRequests(withIdentifiers: stale)
        for attempt in 0...max(0, settings.repeatCount) {
            let fireAt = base.addingTimeInterval(TimeInterval(attempt * settings.snoozeMinutes * 60))
            let reminder = PlannedReminder(dayKey: group.dayKey, minutesOfDay: group.minutesOfDay, attempt: attempt,
                                           fireAt: fireAt, medicationIDs: group.medicationIDs)
            add(id: "snooze|\(group.key)|\(attempt)", content: doseContent(for: medications, reminder: reminder, totalAttempts: settings.repeatCount),
                at: fireAt, calendar: calendar)
        }
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

    /// The doses one notification stands for.
    struct DoseGroup: Sendable {
        let dayKey: String
        let minutesOfDay: Int
        let medicationIDs: [UUID]
        var key: String { "\(dayKey)|\(minutesOfDay)" }
    }

    nonisolated static func group(of userInfo: [AnyHashable: Any], fallbackDay: Date? = nil) -> DoseGroup? {
        guard let minutes = userInfo["minutesOfDay"] as? Int else { return nil }
        let ids = (userInfo["medicationIDs"] as? [String] ?? (userInfo["medicationID"] as? String).map { [$0] } ?? [])
            .compactMap(UUID.init(uuidString:))
        guard !ids.isEmpty else { return nil }
        let dayKey = userInfo["day"] as? String ?? fallbackDay.map { ReminderPlanner.dayKey(for: $0) }
        guard let dayKey else { return nil }
        return DoseGroup(dayKey: dayKey, minutesOfDay: minutes, medicationIDs: ids)
    }

    /// True while at least one dose of the group has no record yet.
    private static func isOpen(_ group: DoseGroup, medications: [UUID: Medication], calendar: Calendar) -> Bool {
        guard let day = ReminderPlanner.day(fromKey: group.dayKey, calendar: calendar) else { return false }
        return group.medicationIDs.contains { id in
            guard let medication = medications[id] else { return false }
            return DoseScheduler.slots(for: [medication], on: day, calendar: calendar).contains { slot in
                !slot.isUnscheduled && slot.event == nil
                    && calendar.component(.hour, from: slot.scheduledAt) * 60 + calendar.component(.minute, from: slot.scheduledAt) == group.minutesOfDay
            }
        }
    }

    // MARK: Responses

    private func handle(action: String, group: DoseGroup) {
        guard let context, let day = ReminderPlanner.day(fromKey: group.dayKey) else { return }
        let calendar = Calendar.current
        let request = Medication.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", group.medicationIDs)
        let medications = (try? context.fetch(request)) ?? []
        guard !medications.isEmpty else { return }

        if action == Action.snooze {
            snooze(group, medications: medications)
            return
        }
        let logger = DoseLogger(context: context, notifier: self)
        for medication in medications {
            let scheduledAt = calendar.date(bySettingHour: group.minutesOfDay / 60, minute: group.minutesOfDay % 60, second: 0, of: day) ?? day
            let slot = DoseScheduler.slots(for: [medication], on: day, calendar: calendar)
                .first { calendar.isDate($0.scheduledAt, equalTo: scheduledAt, toGranularity: .minute) && !$0.isUnscheduled }
                ?? DoseSlot(medication: medication, scheduledAt: scheduledAt, event: nil)
            guard slot.event == nil else { continue }
            switch action {
            case Action.taken: logger.markTaken(slot, source: .notification)
            case Action.skip: logger.markSkipped(slot, source: .notification)
            default: break
            }
        }
        scheduleReplan()
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let action = response.actionIdentifier
        let group = Self.group(of: response.notification.request.content.userInfo, fallbackDay: response.notification.date)
        nonisolated(unsafe) let completion = completionHandler
        Task { @MainActor in
            if let group { self.handle(action: action, group: group) }
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
