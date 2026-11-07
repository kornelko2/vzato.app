// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Reads amounts the way people type them: "10", "10,5", "10.5", " 7 ", "½". Returns nil for
/// anything that is not a non-negative number, so a half-typed field never becomes a wrong value.
enum AmountParser {
    static func parse(_ text: String) -> Double? {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
        guard !cleaned.isEmpty else { return nil }
        let fractions: [Character: Double] = ["¼": 0.25, "½": 0.5, "¾": 0.75]
        var extra = 0.0
        if let last = cleaned.last, let fraction = fractions[last] {
            extra = fraction
            cleaned.removeLast()
            if cleaned.isEmpty { return extra }
        }
        cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value.isFinite, value >= 0 else { return nil }
        return value + extra
    }

    /// The inverse for showing a stored value in a field: "10", "10,5" in Czech, "10.5" in English.
    static func format(_ value: Double, locale: Locale = .current) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never).locale(locale))
    }
}
