// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Which CloudKit sync events (setup, import, export) have started and not finished yet.
/// The app keeps running in the background until this is idle: iOS kills a suspended app that
/// still holds the lock on the shared store file (crash code 0xdead10cc).
struct SyncActivity {
    private var running: Set<UUID> = []

    var isIdle: Bool { running.isEmpty }

    /// Records one event notification. CloudKit posts each event twice: when it starts (no end
    /// date) and when it ends.
    mutating func update(event id: UUID, finished: Bool) {
        if finished {
            running.remove(id)
        } else {
            running.insert(id)
        }
    }
}
