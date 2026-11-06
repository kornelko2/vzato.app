// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

@main
struct VzatoApp: App {
    private let persistence: PersistenceController

    init() {
        persistence = PersistenceController.shared
        #if DEBUG
        // `--sample-data` fills an empty store with demo medications (simulator screenshots, UI work).
        if CommandLine.arguments.contains("--sample-data") {
            let request = Medication.fetchRequest()
            request.fetchLimit = 1
            if (try? persistence.viewContext.count(for: request)) == 0 {
                SampleData.populate(in: persistence.viewContext)
            }
        }
        #endif
        NotificationService.shared.configure(context: persistence.viewContext)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistence.viewContext)
        }
    }
}
