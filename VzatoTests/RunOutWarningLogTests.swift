// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import Vzato

struct RunOutWarningLogTests {
    private func should(fire: Date, previous: Date?, now: Date) -> Bool {
        RunOutWarningLog.shouldSchedule(fire: fire, previous: previous, now: now, windowDays: 7, calendar: testCalendar)
    }

    @Test func firstWarningAndRescheduledPendingOnesAreAllowed() {
        #expect(should(fire: at(monday, 9), previous: nil, now: at(monday, 7)))
        // Not gone off yet: a rebuild may move it.
        #expect(should(fire: at(days(1, after: monday), 9), previous: at(monday, 9), now: at(monday, 7)))
    }

    @Test func aDelayedRunOutDoesNotWarnAgain() {
        // Warned Monday 9:00; a late dose moved the run-out a day, so the warning would be Tuesday.
        #expect(!should(fire: at(days(1, after: monday), 9), previous: at(monday, 9), now: at(days(1, after: monday), 8)))
    }

    @Test func aRefillWarnsAgainLater() {
        #expect(should(fire: at(days(30, after: monday), 9), previous: at(monday, 9), now: at(days(2, after: monday), 8)))
    }
}
