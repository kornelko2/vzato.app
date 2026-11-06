// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

extension Color {
    /// Parses "RRGGBB" (with or without a leading #). Falls back to the accent color.
    init(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let number = UInt32(value, radix: 16) else {
            self = .accentColor
            return
        }
        self.init(
            red: Double((number >> 16) & 0xFF) / 255,
            green: Double((number >> 8) & 0xFF) / 255,
            blue: Double(number & 0xFF) / 255
        )
    }
}

enum Palette {
    /// Medication colors. Each differs in lightness as well as hue.
    static let medicationHexes = ["D9534F", "E0A526", "3B7DD8", "1E7B46", "7B52AB", "C2185B", "00838F", "6D4C41"]
    static let taken = Color(hex: "1E7B46")
    static let overdue = Color(hex: "B4530A")
    static let missed = Color(hex: "C0392B")
    static let skipped = Color(hex: "8A7F5A")
}

extension DoseStatus {
    var color: Color {
        switch self {
        case .pending: .secondary
        case .taken: Palette.taken
        case .skipped: Palette.skipped
        case .missed: Palette.missed
        }
    }
}

extension View {
    /// Number pad on iPhone; no-op elsewhere.
    func numericKeyboard() -> some View {
        #if os(iOS)
        return keyboardType(.numberPad)
        #else
        return self
        #endif
    }

    /// Decimal pad on iPhone (for counts like 10.5); no-op elsewhere.
    func decimalKeyboard() -> some View {
        #if os(iOS)
        return keyboardType(.decimalPad)
        #else
        return self
        #endif
    }
}
