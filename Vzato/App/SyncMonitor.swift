// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData
import Foundation
import Observation

/// Watches the CloudKit container so Settings can show the sync state, and refreshes reminders
/// when changes arrive from another device.
@MainActor
@Observable
final class SyncMonitor {
    static let shared = SyncMonitor()

    private(set) var isEnabled = false
    private(set) var lastSuccess: Date?
    private(set) var lastError: String?

    private var observers: [any NSObjectProtocol] = []
    private var rescheduleTask: Task<Void, Never>?

    private init() {}

    func start(controller: PersistenceController) {
        isEnabled = controller.isCloudKitEnabled
        guard isEnabled, observers.isEmpty else { return }

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSPersistentCloudKitContainer.eventChangedNotification, object: controller.container, queue: .main) { [weak self] notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event,
                  event.endDate != nil else { return }
            let succeeded = event.succeeded
            let message = event.error?.localizedDescription
            let ended = event.endDate ?? Date()
            MainActor.assumeIsolated {
                self?.record(succeeded: succeeded, message: message, at: ended)
            }
        })
        observers.append(center.addObserver(forName: .NSPersistentStoreRemoteChange, object: controller.container.persistentStoreCoordinator, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.scheduleReminderRefresh()
            }
        })
    }

    private func record(succeeded: Bool, message: String?, at date: Date) {
        if succeeded {
            lastSuccess = date
            lastError = nil
        } else {
            lastError = message
        }
    }

    /// Remote changes arrive in bursts; wait a moment, then rebuild the pending notifications once.
    private func scheduleReminderRefresh() {
        rescheduleTask?.cancel()
        rescheduleTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await NotificationService.shared.rescheduleAll()
        }
    }
}
