// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#if os(iOS)
import BackgroundTasks
import Foundation

/// Once a day, when iOS allows, rebuild the reminders so they keep reaching two weeks ahead even
/// when nobody opens the app. Not guaranteed by iOS; the "open Vzato" reminder covers the rest.
enum BackgroundRefresh {
    static let identifier = "app.vzato.refresh"

    /// Must run before the app finishes launching.
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            guard let refresh = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handle(refresh)
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date().addingTimeInterval(12 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(_ task: BGAppRefreshTask) {
        schedule()
        nonisolated(unsafe) let task = task
        let work = Task { @MainActor in
            await NotificationService.shared.rescheduleAll()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { work.cancel() }
    }
}
#endif
