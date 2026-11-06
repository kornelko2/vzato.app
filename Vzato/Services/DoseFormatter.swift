// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Shows tablet counts the way people say them: 1, ½, 1¼, 2½. Other values fall back to a plain number.
enum DoseFormatter {
    nonisolated static func units(_ value: Double) -> String {
        let quarters = (value * 4).rounded()
        guard abs(value * 4 - quarters) < 0.001, quarters >= 0 else {
            return value.formatted(.number.precision(.fractionLength(0...2)))
        }
        let whole = Int(quarters) / 4
        let fraction: String
        switch Int(quarters) % 4 {
        case 1: fraction = "¼"
        case 2: fraction = "½"
        case 3: fraction = "¾"
        default: fraction = ""
        }
        if fraction.isEmpty { return String(whole) }
        return whole == 0 ? fraction : "\(whole)\(fraction)"
    }
}
