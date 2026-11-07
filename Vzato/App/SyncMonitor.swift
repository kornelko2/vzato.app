// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CloudKit
import CoreData
import Foundation
import Observation
#if os(iOS)
import UIKit
#endif

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
    private var activity = SyncActivity()
    #if os(iOS)
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    #endif

    private init() {}

    func start(controller: PersistenceController) {
        isEnabled = controller.isCloudKitEnabled
        guard isEnabled, observers.isEmpty else { return }

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSPersistentCloudKitContainer.eventChangedNotification, object: controller.container, queue: .main) { [weak self] notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else { return }
            let id = event.identifier
            let ended = event.endDate
            let succeeded = event.succeeded
            let message = event.error.map(SyncMonitor.describe)
            MainActor.assumeIsolated {
                self?.activity.update(event: id, finished: ended != nil)
                if let ended {
                    self?.record(succeeded: succeeded, message: message, at: ended)
                }
                self?.releaseBackgroundTimeIfIdle()
            }
        })
        observers.append(center.addObserver(forName: .NSPersistentStoreRemoteChange, object: controller.container.persistentStoreCoordinator, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.scheduleReminderRefresh()
            }
        })
    }

    /// Called when the app goes to the background. A dose confirmed just before leaving the app
    /// starts a CloudKit export that writes to the store; ask iOS for time to finish it, because a
    /// suspended app holding the store's file lock is killed (0xdead10cc).
    func keepRunningWhileSyncing() {
        #if os(iOS)
        guard isEnabled, backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Finish iCloud sync") { [weak self] in
            MainActor.assumeIsolated { self?.releaseBackgroundTime() }
        }
        // The export starts shortly after the last save; if nothing has started by then, let go.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            self?.releaseBackgroundTimeIfIdle()
        }
        #endif
    }

    private func releaseBackgroundTimeIfIdle() {
        if activity.isIdle { releaseBackgroundTime() }
    }

    private func releaseBackgroundTime() {
        #if os(iOS)
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
        #endif
    }

    /// Turns CloudKit's terse errors into something a person can act on. Partial failures are
    /// unpacked to the first per-record error, which carries the real reason.
    nonisolated static func describe(_ error: any Error) -> String {
        var ckError = error as? CKError
        if let partial = ckError, partial.code == .partialFailure,
           let first = partial.partialErrorsByItemID?.values.first as? CKError {
            ckError = first
        }
        guard let ckError else { return error.localizedDescription }
        switch ckError.code {
        case .quotaExceeded:
            return String(localized: "Your iCloud storage is full. Free up space or upgrade your iCloud plan; sync continues automatically afterwards.")
        case .notAuthenticated:
            return String(localized: "Sign in to iCloud in the system settings to sync.")
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy:
            return String(localized: "iCloud is not reachable right now. Sync will retry on its own.")
        case .accountTemporarilyUnavailable:
            return String(localized: "Your iCloud account needs attention in the system settings.")
        default:
            return ckError.localizedDescription
        }
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
