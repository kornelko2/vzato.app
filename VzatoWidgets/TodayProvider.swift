// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData
import WidgetKit

extension TodayEntry: TimelineEntry {
    /// Shown in the widget gallery and while loading.
    static var placeholder: TodayEntry {
        let now = Date()
        let next = WidgetDose(id: "placeholder-1", medicationID: nil, name: "Ibuprofen",
                              amount: DoseFormatter.amount(1, unit: .tablet), strength: "400 mg", colorHex: "D9534F",
                              scheduledAt: now, status: .pending, isOverdue: false, isOpen: true, canTakeNow: true)
        let later = WidgetDose(id: "placeholder-2", medicationID: nil, name: "Vitamin D",
                               amount: DoseFormatter.amount(20, unit: .drop), strength: "", colorHex: "E0A526",
                               scheduledAt: now.addingTimeInterval(3 * 60 * 60), status: .pending, isOverdue: false, isOpen: true, canTakeNow: false)
        return TodayEntry(date: now, featured: next, upcoming: [later], taken: 1, total: 3)
    }
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (TodayEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        Task { @MainActor in
            completion(Self.loadEntries().first ?? .placeholder)
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<TodayEntry>) -> Void) {
        Task { @MainActor in
            let entries = Self.loadEntries()
            let calendar = Calendar.current
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date().addingTimeInterval(86_400)
            completion(Timeline(entries: entries.isEmpty ? [.placeholder] : entries, policy: .after(tomorrow)))
        }
    }

    @MainActor
    private static func loadEntries() -> [TodayEntry] {
        guard PersistenceController.shared.isStoreLoaded else { return [] }
        let context = PersistenceController.shared.viewContext
        // The extension process may live on between timelines; drop cached objects so the app's
        // latest writes are read from the store.
        context.refreshAllObjects()
        let request = Medication.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == NO")
        let medications = (try? context.fetch(request)) ?? []
        return TodaySnapshot.entries(for: medications, now: Date(), grace: AppSettings.missedAfterInterval)
    }
}
