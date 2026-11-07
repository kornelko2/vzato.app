// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import Vzato

struct SyncActivityTests {
    @Test func idleUntilAnEventStarts() {
        #expect(SyncActivity().isIdle)
    }

    @Test func busyUntilEveryStartedEventEnds() {
        var activity = SyncActivity()
        let export = UUID(), importing = UUID()
        activity.update(event: export, finished: false)
        activity.update(event: importing, finished: false)
        activity.update(event: export, finished: true)
        #expect(!activity.isIdle)
        activity.update(event: importing, finished: true)
        #expect(activity.isIdle)
    }

    @Test func anEndWithoutAStartKeepsItIdle() {
        var activity = SyncActivity()
        activity.update(event: UUID(), finished: true)
        #expect(activity.isIdle)
    }
}
