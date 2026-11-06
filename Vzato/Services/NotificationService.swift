// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData
import Foundation
import Observation
import UserNotifications

/// Local notifications for scheduled doses and low stock. No push server; everything is scheduled on device.
@MainActor
@Observable
final class NotificationService: NSObject, UNUserNotificationCenterDelegate, LowStockNotifying {
    static let shared = NotificationService()

    enum Category {
        static let dose = "DOSE_REMINDER"
        static let lowStock = "LOW_STOCK"
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
    private(set) var hitLimit = false

    private var context: NSManagedObjectContext?
    private let center = UNUserNotificationCenter.current()

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
        center.setNotificationCategories([dose, lowStock])
    }

    // MARK: Scheduling

    /// Drops every pending request and schedules repeating reminders for all active medications.
    /// Called at launch and after any change to medications or schedules.
    func rescheduleAll() async {
        guard let context else { return }
        center.removeAllPendingNotificationRequests()
        let request = Medication.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == NO")
        let medications = (try? context.fetch(request)) ?? []

        var count = 0
        var limited = false
        let now = Date()
        outer: for medication in medications {
            for schedule in medication.activeSchedules {
                if let end = schedule.endDate, end < now { continue }
                for minutes in schedule.minutesOfDay {
                    let content = doseContent(for: medication, minutesOfDay: minutes)
                    var components = DateComponents()
                    components.hour = minutes / 60
                    components.minute = minutes % 60
                    if schedule.isEveryDay {
                        if count >= Self.pendingLimit { limited = true; break outer }
                        add(id: "dose|\(medication.id?.uuidString ?? "")|0|\(minutes)", content: content, components: components)
                        count += 1
                    } else {
                        for weekday in schedule.weekdays {
                            if count >= Self.pendingLimit { limited = true; break outer }
                            components.weekday = weekday
                            add(id: "dose|\(medication.id?.uuidString ?? "")|\(weekday)|\(minutes)", content: content, components: components)
                            count += 1
                        }
                    }
                }
            }
        }
        scheduledCount = count
        hitLimit = limited
    }

    private func add(id: String, content: UNNotificationContent, components: DateComponents) {
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger)) { _ in }
    }

    private func doseContent(for medication: Medication, minutesOfDay: Int) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = medication.name
        content.body = medication.dosageText.isEmpty
            ? String(localized: "Time to take your dose.")
            : String(localized: "Time to take \(medication.dosageText).")
        content.sound = .default
        content.categoryIdentifier = Category.dose
        content.threadIdentifier = medication.id?.uuidString ?? "dose"
        content.userInfo = ["medicationID": medication.id?.uuidString ?? "", "minutesOfDay": minutesOfDay]
        return content
    }

    func snooze(medication: Medication, minutesOfDay: Int, after minutes: Int) {
        let content = doseContent(for: medication, minutesOfDay: minutesOfDay)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(1, minutes) * 60), repeats: false)
        let id = "snooze|\(medication.id?.uuidString ?? "")|\(minutesOfDay)|\(Int(Date().timeIntervalSince1970))"
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger)) { _ in }
    }

    func notifyLowStock(_ medication: Medication) {
        guard AppSettings.lowStockNotificationsEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Running low: \(medication.name)")
        content.body = medication.isOutOfStock
            ? String(localized: "You are out. Get more as soon as you can.")
            : String(localized: "Only \(medication.stockCount) left. Time to get more.")
        content.sound = .default
        content.categoryIdentifier = Category.lowStock
        content.threadIdentifier = "lowstock"
        let id = "lowstock|\(medication.id?.uuidString ?? "")"
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil)) { _ in }
    }

    func clearDelivered(for medication: Medication) {
        center.getDeliveredNotifications { notifications in
            let ids = notifications
                .filter { ($0.request.content.userInfo["medicationID"] as? String) == medication.id?.uuidString }
                .map(\.request.identifier)
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
        }
    }

    // MARK: Responses

    private func handle(action: String, medicationID: UUID?, minutesOfDay: Int?, fireDate: Date) {
        guard let context, let medicationID, let minutesOfDay else { return }
        let request = Medication.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", medicationID as CVarArg)
        request.fetchLimit = 1
        guard let medication = try? context.fetch(request).first else { return }

        let calendar = Calendar.current
        let day = calendar.startOfDay(for: fireDate)
        let scheduledAt = calendar.date(bySettingHour: minutesOfDay / 60, minute: minutesOfDay % 60, second: 0, of: day) ?? fireDate
        let slot = DoseScheduler.slots(for: [medication], on: day, calendar: calendar)
            .first { calendar.isDate($0.scheduledAt, equalTo: scheduledAt, toGranularity: .minute) && !$0.isUnscheduled }
            ?? DoseSlot(medication: medication, scheduledAt: scheduledAt, event: nil)

        let logger = DoseLogger(context: context, notifier: self)
        switch action {
        case Action.taken:
            logger.markTaken(slot, source: .notification)
        case Action.skip:
            logger.markSkipped(slot, source: .notification)
        case Action.snooze:
            snooze(medication: medication, minutesOfDay: minutesOfDay, after: AppSettings.snoozeMinutes)
        default:
            break
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let action = response.actionIdentifier
        let info = response.notification.request.content.userInfo
        let medicationID = (info["medicationID"] as? String).flatMap { UUID(uuidString: $0) }
        let minutesOfDay = info["minutesOfDay"] as? Int
        let fireDate = response.notification.date
        nonisolated(unsafe) let completion = completionHandler
        Task { @MainActor in
            self.handle(action: action, medicationID: medicationID, minutesOfDay: minutesOfDay, fireDate: fireDate)
            completion()
        }
    }
}
