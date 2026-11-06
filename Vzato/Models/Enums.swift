// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

enum DoseStatus: String, CaseIterable, Sendable {
    case pending, taken, skipped, missed
}

enum DoseSource: String, Sendable {
    case app, notification, widget, health, reconciliation, caregiver
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

enum ProfileKind: String, Sendable {
    case person, pet
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
