// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// A number field built for typing a count on the number pad:
/// - the value updates on every keystroke (`TextField(value:format:)` only commits on Return, and
///   the number pad has none);
/// - tapping a field that shows a number clears it for the new entry and keeps the old number as
///   the hint, so typing "79" over "30" never becomes "7930" or "3079";
/// - leaving the field without typing restores the old number.
struct AmountField: View {
    let title: LocalizedStringKey
    @Binding var value: Double?
    @State private var text: String
    @State private var previous: Double?
    @FocusState private var focused: Bool

    init(_ title: LocalizedStringKey, value: Binding<Double?>) {
        self.title = title
        _value = value
        _text = State(initialValue: value.wrappedValue.map { AmountParser.format($0) } ?? "")
    }

    var body: some View {
        TextField(text: $text) {
            if let hint = previous ?? value {
                Text(verbatim: AmountParser.format(hint))
            } else {
                Text(title)
            }
        }
        .decimalKeyboard()
        .focused($focused)
        .toolbar {
            // The number pad has no Return key: give it a way to close.
            ToolbarItemGroup(placement: .keyboard) {
                if focused {
                    Spacer()
                    Button("Done") { focused = false }
                }
            }
        }
        .onChange(of: focused) { _, isFocused in
            if isFocused {
                previous = value
                text = ""
            } else if text.isEmpty, let previous {
                value = previous
                text = AmountParser.format(previous)
                self.previous = nil
            } else {
                previous = nil
            }
        }
        .onChange(of: text) { _, newText in
            if let parsed = AmountParser.parse(newText) {
                value = parsed
            } else if newText.isEmpty, !focused {
                value = nil
            }
        }
    }
}
