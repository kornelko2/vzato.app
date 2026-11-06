// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// What one "unit" of a medication is. Decides how amounts read ("2 tablets", "20 drops")
/// and how the dose stepper moves.
enum DoseUnit: String, CaseIterable, Identifiable, Sendable {
    case tablet, capsule, drop, milliliter, teaspoon, puff, sachet, injection, piece
    var id: String { rawValue }

    /// Picker label.
    var label: LocalizedStringResource {
        switch self {
        case .tablet: "Tablets"
        case .capsule: "Capsules"
        case .drop: "Drops"
        case .milliliter: "Millilitres"
        case .teaspoon: "Teaspoons"
        case .puff: "Puffs"
        case .sachet: "Sachets"
        case .injection: "Injections"
        case .piece: "Pieces"
        }
    }

    var symbolName: String {
        switch self {
        case .tablet: "pill"
        case .capsule: "capsule"
        case .drop: "drop"
        case .milliliter: "testtube.2"
        case .teaspoon: "fork.knife"
        case .puff: "wind"
        case .sachet: "bag"
        case .injection: "syringe"
        case .piece: "circle.grid.2x2"
        }
    }

    /// Tablets and capsules are split; everything else is counted whole.
    var allowsFractions: Bool { self == .tablet || self == .capsule }
    var step: Double { allowsFractions ? 0.25 : 1 }
    var maximumPerDose: Double {
        switch self {
        case .drop, .milliliter: 100
        default: 20
        }
    }

    // MARK: Localized amounts

    /// Whole amounts, with plural rules from the String Catalog ("1 tablet", "20 drops").
    nonisolated func whole(_ count: Int, bundle: Bundle = .main, locale: Locale = .current) -> String {
        switch self {
        case .tablet: String(localized: "\(count) tablets", bundle: bundle, locale: locale)
        case .capsule: String(localized: "\(count) capsules", bundle: bundle, locale: locale)
        case .drop: String(localized: "\(count) drops", bundle: bundle, locale: locale)
        case .milliliter: String(localized: "\(count) ml", bundle: bundle, locale: locale)
        case .teaspoon: String(localized: "\(count) teaspoons", bundle: bundle, locale: locale)
        case .puff: String(localized: "\(count) puffs", bundle: bundle, locale: locale)
        case .sachet: String(localized: "\(count) sachets", bundle: bundle, locale: locale)
        case .injection: String(localized: "\(count) injections", bundle: bundle, locale: locale)
        case .piece: String(localized: "\(count) pieces", bundle: bundle, locale: locale)
        }
    }

    /// Fractions below one ("½ tablet").
    nonisolated func fractionBelowOne(_ text: String, bundle: Bundle = .main, locale: Locale = .current) -> String {
        switch self {
        case .tablet: String(localized: "\(text) tablet", bundle: bundle, locale: locale)
        case .capsule: String(localized: "\(text) capsule", bundle: bundle, locale: locale)
        case .drop: String(localized: "\(text) drop", bundle: bundle, locale: locale)
        case .milliliter: String(localized: "\(text) ml", bundle: bundle, locale: locale)
        case .teaspoon: String(localized: "\(text) teaspoon", bundle: bundle, locale: locale)
        case .puff: String(localized: "\(text) puff", bundle: bundle, locale: locale)
        case .sachet: String(localized: "\(text) sachet", bundle: bundle, locale: locale)
        case .injection: String(localized: "\(text) injection", bundle: bundle, locale: locale)
        case .piece: String(localized: "\(text) piece", bundle: bundle, locale: locale)
        }
    }

    /// Mixed numbers ("1½ tablets").
    nonisolated func fractionAboveOne(_ text: String, bundle: Bundle = .main, locale: Locale = .current) -> String {
        switch self {
        case .tablet: String(localized: "\(text) tablets", bundle: bundle, locale: locale)
        case .capsule: String(localized: "\(text) capsules", bundle: bundle, locale: locale)
        case .drop: String(localized: "\(text) drops", bundle: bundle, locale: locale)
        case .milliliter: String(localized: "\(text) ml", bundle: bundle, locale: locale)
        case .teaspoon: String(localized: "\(text) teaspoons", bundle: bundle, locale: locale)
        case .puff: String(localized: "\(text) puffs", bundle: bundle, locale: locale)
        case .sachet: String(localized: "\(text) sachets", bundle: bundle, locale: locale)
        case .injection: String(localized: "\(text) injections", bundle: bundle, locale: locale)
        case .piece: String(localized: "\(text) pieces", bundle: bundle, locale: locale)
        }
    }
}
