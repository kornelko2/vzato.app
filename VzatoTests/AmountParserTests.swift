// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import Vzato

struct AmountParserTests {
    @Test func acceptsWhatPeopleType() {
        #expect(AmountParser.parse("10") == 10)
        #expect(AmountParser.parse("10,5") == 10.5)
        #expect(AmountParser.parse("10.5") == 10.5)
        #expect(AmountParser.parse(" 7 ") == 7)
        #expect(AmountParser.parse("1 000") == 1000)
        #expect(AmountParser.parse("½") == 0.5)
        #expect(AmountParser.parse("2½") == 2.5)
        #expect(AmountParser.parse("0") == 0)
    }

    @Test func rejectsHalfTypedOrInvalidInput() {
        #expect(AmountParser.parse("") == nil)
        #expect(AmountParser.parse("abc") == nil)
        #expect(AmountParser.parse("-3") == nil)
        #expect(AmountParser.parse(",") == nil)
    }

    @Test func formatsForTheField() {
        #expect(AmountParser.format(10, locale: Locale(identifier: "cs")) == "10")
        #expect(AmountParser.format(10.5, locale: Locale(identifier: "cs")) == "10,5")
        #expect(AmountParser.format(10.5, locale: Locale(identifier: "en")) == "10.5")
        #expect(AmountParser.format(1000, locale: Locale(identifier: "cs")) == "1000")
    }
}
