// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// Shown instead of the app when the data could not be opened. Nothing is deleted or changed, and
/// reminders already scheduled keep coming.
struct StoreErrorView: View {
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label("Your data could not be opened", systemImage: "exclamationmark.triangle")
        } description: {
            VStack(spacing: 12) {
                Text("Nothing was deleted. Close Vzato completely and open it again. If this keeps happening, check that the device has free space, or write to info@vzato.app.")
                if !message.isEmpty {
                    Text(verbatim: message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        } actions: {
            if let mail = URL(string: "mailto:info@vzato.app") {
                Link("Write to us: info@vzato.app", destination: mail)
            }
        }
    }
}
