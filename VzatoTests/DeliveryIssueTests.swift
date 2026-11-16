// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Testing
import UserNotifications
@testable import Vzato

struct DeliveryIssueTests {
    private func issues(authorization: UNAuthorizationStatus = .authorized, alert: UNNotificationSetting = .enabled,
                        lockScreen: UNNotificationSetting = .enabled, sound: UNNotificationSetting = .enabled,
                        timeSensitive: UNNotificationSetting = .enabled, wantsTimeSensitive: Bool = true) -> [DeliveryIssue] {
        DeliveryIssue.issues(authorization: authorization, alert: alert, lockScreen: lockScreen, sound: sound,
                             timeSensitive: timeSensitive, wantsTimeSensitive: wantsTimeSensitive)
    }

    @Test func nothingWhenEverythingIsOn() {
        #expect(issues().isEmpty)
    }

    @Test func reportsEverySettingSwitchedOff() {
        #expect(issues(alert: .disabled, lockScreen: .disabled, sound: .disabled, timeSensitive: .disabled)
            == [.timeSensitiveOff, .alertsOff, .lockScreenOff, .soundOff])
    }

    @Test func timeSensitiveOnlyMattersWhenTheAppAsksForIt() {
        #expect(issues(timeSensitive: .disabled, wantsTimeSensitive: false).isEmpty)
        #expect(issues(timeSensitive: .notSupported).isEmpty)
    }

    @Test func silentWhileNotificationsAreNotAllowed() {
        #expect(issues(authorization: .denied, alert: .disabled, sound: .disabled).isEmpty)
        #expect(issues(authorization: .notDetermined, timeSensitive: .disabled).isEmpty)
    }
}

/// A dose confirmed in the widget: which medications of a shared reminder still need it.
@MainActor
struct WidgetResolvedDoseTests {
    @Test func sharedReminderKeepsOnlyTheOpenDoses() {
        let store = TestStore()
        let a = store.medication(name: "A", times: [8 * 60])
        let b = store.medication(name: "B", times: [8 * 60])
        let c = store.medication(name: "C", times: [8 * 60])
        let logger = DoseLogger(context: store.context, now: at(monday, 8, 5), notifier: SpyNotifier())
        for medication in [a, c] {
            let slot = DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar).first!
            logger.markTaken(slot)
        }
        let group = NotificationService.DoseGroup(dayKey: ReminderPlanner.dayKey(for: monday, calendar: testCalendar),
                                                  minutesOfDay: 8 * 60, medicationIDs: [a.id!, b.id!, c.id!])
        #expect(NotificationService.stillOpen(group, excluding: a.id!, in: store.context, calendar: testCalendar).ids == [b.id!])
        #expect(NotificationService.stillOpen(group, excluding: b.id!, in: store.context, calendar: testCalendar).ids.isEmpty)
    }
}
