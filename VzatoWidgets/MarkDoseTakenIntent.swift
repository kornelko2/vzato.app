// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppIntents
import CoreData
import WidgetKit

/// The "Vzato" button in the widget. Runs in the widget process and writes to the shared store;
/// the app merges the change and syncs it.
struct MarkDoseTakenIntent: AppIntent {
    static let title: LocalizedStringResource = "Mark dose as taken"
    static let isDiscoverable = false

    @Parameter(title: "Medication") var medicationID: String
    @Parameter(title: "Time") var scheduledAt: Date

    init() {}

    init(medicationID: UUID, scheduledAt: Date) {
        self.medicationID = medicationID.uuidString
        self.scheduledAt = scheduledAt
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard PersistenceController.shared.isStoreLoaded else { return .result() }
        let context = PersistenceController.shared.viewContext
        context.refreshAllObjects()
        guard let id = UUID(uuidString: medicationID) else { return .result() }
        let request = Medication.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        guard let medication = try? context.fetch(request).first else { return .result() }

        let calendar = Calendar.current
        let slot = DoseScheduler.slots(for: [medication], on: scheduledAt, calendar: calendar).first {
            !$0.isUnscheduled && calendar.isDate($0.scheduledAt, equalTo: scheduledAt, toGranularity: .minute)
        }
        // Already confirmed in the app or on another device: nothing to do.
        guard let slot, slot.event?.status != .taken else { return .result() }
        DoseLogger(context: context).markTaken(slot, source: .widget)
        NotificationService.shared.clearDelivered(for: medication)
        return .result()
    }
}
