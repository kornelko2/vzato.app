// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// A number field that updates its value on every keystroke. `TextField(value:format:)` only
/// commits on Return, and the iPhone number pad has no Return key, so typed amounts were lost.
struct AmountField: View {
    let title: LocalizedStringKey
    @Binding var value: Double?
    @State private var text: String

    init(_ title: LocalizedStringKey, value: Binding<Double?>) {
        self.title = title
        _value = value
        _text = State(initialValue: value.wrappedValue.map { AmountParser.format($0) } ?? "")
    }

    var body: some View {
        TextField(title, text: $text)
            .decimalKeyboard()
            .onChange(of: text) { _, newText in
                value = AmountParser.parse(newText)
            }
    }
}

extension Binding where Value == Double {
    /// Lets a non-optional amount use `AmountField`; an empty field keeps the last valid value.
    var optional: Binding<Double?> {
        Binding<Double?>(get: { wrappedValue }, set: { if let new = $0 { wrappedValue = new } })
    }
}
