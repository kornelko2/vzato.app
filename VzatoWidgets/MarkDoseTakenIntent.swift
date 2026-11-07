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
        guard let (slot, medication, context) = WidgetDoseLookup.openSlot(medicationID: medicationID, scheduledAt: scheduledAt) else {
            return .result()
        }
        // The widget only shows the button when one tap is safe; check again in case the state
        // changed since it was drawn.
        guard DoseGuard.verdict(for: slot, now: Date()) == .ok else { return .result() }
        DoseLogger(context: context).markTaken(slot, source: .widget)
        NotificationService.shared.clearDelivered(for: medication)
        return .result()
    }
}

/// The "Skip" button next to "Vzato" in the widget.
struct MarkDoseSkippedIntent: AppIntent {
    static let title: LocalizedStringResource = "Skip dose"
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
        guard let (slot, medication, context) = WidgetDoseLookup.openSlot(medicationID: medicationID, scheduledAt: scheduledAt) else {
            return .result()
        }
        DoseLogger(context: context).markSkipped(slot, source: .widget)
        NotificationService.shared.clearDelivered(for: medication)
        return .result()
    }
}

enum WidgetDoseLookup {
    /// The scheduled dose the button was drawn for, if it still has no record. Already confirmed or
    /// skipped in the app or on another device: nothing to do.
    @MainActor
    static func openSlot(medicationID: String, scheduledAt: Date) -> (DoseSlot, Medication, NSManagedObjectContext)? {
        guard PersistenceController.shared.isStoreLoaded, let id = UUID(uuidString: medicationID) else { return nil }
        let context = PersistenceController.shared.viewContext
        context.refreshAllObjects()
        let request = Medication.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        guard let medication = try? context.fetch(request).first else { return nil }

        let calendar = Calendar.current
        let slot = DoseScheduler.slots(for: [medication], on: scheduledAt, calendar: calendar).first {
            !$0.isUnscheduled && calendar.isDate($0.scheduledAt, equalTo: scheduledAt, toGranularity: .minute)
        }
        guard let slot, slot.event == nil else { return nil }
        return (slot, medication, context)
    }
}
