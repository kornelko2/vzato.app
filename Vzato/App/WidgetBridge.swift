// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData
import WidgetKit

/// Tells WidgetKit to rebuild the widgets whenever the app saves, so a dose confirmed in the app,
/// from a notification or by sync shows up on the home screen right away.
@MainActor
final class WidgetBridge {
    static let shared = WidgetBridge()

    private var observer: (any NSObjectProtocol)?
    private var pending: Task<Void, Never>?

    private init() {}

    func start(context: NSManagedObjectContext) {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextDidSave, object: context, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reloadSoon() }
        }
    }

    /// Saves come in bursts (dose + stock + notification bookkeeping); reload once afterwards.
    func reloadSoon() {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func reloadNow() {
        pending?.cancel()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
