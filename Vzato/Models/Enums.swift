// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

enum DoseStatus: String, CaseIterable, Sendable {
    case pending, taken, skipped, missed
}

enum DoseSource: String, Sendable {
    case app, notification, widget, health, reconciliation, caregiver

    var label: LocalizedStringResource {
        switch self {
        case .app: "App"
        case .notification: "Notification"
        case .widget: "Widget"
        case .health: "Health"
        case .reconciliation: "Supply check"
        case .caregiver: "Caregiver"
        }
    }
}

enum MealRelation: String, CaseIterable, Identifiable, Sendable {
    case any, before, with, after
    var id: String { rawValue }

    var label: LocalizedStringResource {
        switch self {
        case .any: "Any time"
        case .before: "Before a meal"
        case .with: "With a meal"
        case .after: "After a meal"
        }
    }
}

/// How a schedule repeats. Raw values are stored in Core Data: never rename an existing case.
enum RepeatKind: String, CaseIterable, Identifiable, Sendable {
    /// On chosen weekdays (every day by default).
    case weekdays
    /// Every N days, every N weeks or every N months, counted from the start date.
    case days, weeks, months
    var id: String { rawValue }

    var label: LocalizedStringResource {
        switch self {
        case .weekdays: "On chosen days"
        case .days: "Every few days"
        case .weeks: "Every few weeks"
        case .months: "Every few months"
        }
    }
}

enum ProfileKind: String, CaseIterable, Identifiable, Sendable {
    case person, pet
    var id: String { rawValue }

    var label: LocalizedStringResource {
        switch self {
        case .person: "Person"
        case .pet: "Animal"
        }
    }

    var defaultSymbol: String {
        switch self {
        case .person: "person.fill"
        case .pet: "pawprint.fill"
        }
    }

    /// Icons offered in the profile editor.
    var symbols: [String] {
        switch self {
        case .person: ["person.fill", "figure.child", "figure.and.child.holdinghands", "figure.2", "heart.fill"]
        case .pet: ["pawprint.fill", "dog.fill", "cat.fill", "bird.fill", "fish.fill", "hare.fill", "tortoise.fill", "lizard.fill"]
        }
    }
}

extension DoseStatus {
    var label: LocalizedStringResource {
        switch self {
        case .pending: "Pending"
        case .taken: "Taken"
        case .skipped: "Skipped"
        case .missed: "Missed"
        }
    }

    /// Merge priority across devices: a taken dose must never be hidden by a skip.
    var mergeRank: Int {
        switch self {
        case .taken: 3
        case .skipped: 2
        case .missed: 1
        case .pending: 0
        }
    }

    var symbolName: String {
        switch self {
        case .pending: "clock"
        case .taken: "checkmark.circle.fill"
        case .skipped: "forward.circle"
        case .missed: "xmark.circle"
        }
    }
}

// Identifiable via the `id` attribute so SwiftUI lists and pickers can use the objects directly.
extension Profile: Identifiable {}
extension Medication: Identifiable {}
extension Schedule: Identifiable {}
extension DoseEvent: Identifiable {}
extension ActivityEntry: Identifiable {}
