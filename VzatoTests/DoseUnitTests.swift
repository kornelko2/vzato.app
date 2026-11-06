// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import Vzato

/// Bundle and locale are passed explicitly so the results do not depend on the simulator's language.
struct DoseUnitTests {
    @Test func wholeAmountsUsePluralRules() {
        #expect(DoseFormatter.amount(1, unit: .tablet, bundle: lproj("en"), locale: Locale(identifier: "en")) == "1 tablet")
        #expect(DoseFormatter.amount(2, unit: .tablet, bundle: lproj("en"), locale: Locale(identifier: "en")) == "2 tablets")
        #expect(DoseFormatter.amount(20, unit: .drop, bundle: lproj("en"), locale: Locale(identifier: "en")) == "20 drops")
        #expect(DoseFormatter.amount(1, unit: .drop, bundle: lproj("en"), locale: Locale(identifier: "en")) == "1 drop")
        #expect(DoseFormatter.amount(5, unit: .milliliter, bundle: lproj("en"), locale: Locale(identifier: "en")) == "5 ml")
    }

    @Test func czechSlovakHungarianPlurals() {
        #expect(DoseFormatter.amount(1, unit: .tablet, bundle: lproj("cs"), locale: Locale(identifier: "cs")) == "1 tableta")
        #expect(DoseFormatter.amount(2, unit: .tablet, bundle: lproj("cs"), locale: Locale(identifier: "cs")) == "2 tablety")
        #expect(DoseFormatter.amount(5, unit: .tablet, bundle: lproj("cs"), locale: Locale(identifier: "cs")) == "5 tablet")
        #expect(DoseFormatter.amount(20, unit: .drop, bundle: lproj("cs"), locale: Locale(identifier: "cs")) == "20 kapek")
        #expect(DoseFormatter.amount(3, unit: .drop, bundle: lproj("sk"), locale: Locale(identifier: "sk")) == "3 kvapky")
        #expect(DoseFormatter.amount(7, unit: .drop, bundle: lproj("sk"), locale: Locale(identifier: "sk")) == "7 kvapiek")
        #expect(DoseFormatter.amount(20, unit: .drop, bundle: lproj("hu"), locale: Locale(identifier: "hu")) == "20 csepp")
    }

    @Test func fractionsReadNaturally() {
        #expect(DoseFormatter.amount(0.5, unit: .tablet, bundle: lproj("en"), locale: Locale(identifier: "en")) == "½ tablet")
        #expect(DoseFormatter.amount(0.25, unit: .capsule, bundle: lproj("en"), locale: Locale(identifier: "en")) == "¼ capsule")
        #expect(DoseFormatter.amount(1.5, unit: .tablet, bundle: lproj("en"), locale: Locale(identifier: "en")) == "1½ tablets")
        #expect(DoseFormatter.amount(2.5, unit: .milliliter, bundle: lproj("en"), locale: Locale(identifier: "en")) == "2½ ml")
        #expect(DoseFormatter.amount(0.5, unit: .tablet, bundle: lproj("cs"), locale: Locale(identifier: "cs")) == "½ tablety")
        #expect(DoseFormatter.amount(1.5, unit: .tablet, bundle: lproj("sk"), locale: Locale(identifier: "sk")) == "1½ tablety")
    }

    @Test func unitsDecideSteps() {
        #expect(DoseUnit.tablet.allowsFractions)
        #expect(!DoseUnit.drop.allowsFractions)
        #expect(DoseUnit.drop.step == 1)
        #expect(DoseUnit.tablet.step == 0.25)
        #expect(DoseUnit.drop.maximumPerDose >= 50)
    }
}

@MainActor
struct MedicationUnitTests {
    @Test func medicationTextsFollowItsUnit() {
        let store = TestStore()
        let medication = store.medication(stock: 400, unitsPerDose: 20)
        medication.unitKind = .drop
        #expect(DoseFormatter.amount(medication.effectiveUnitsPerDose, unit: medication.unitKind, bundle: lproj("en"), locale: Locale(identifier: "en")) == "20 drops")
        #expect(DoseFormatter.amount(medication.stockCount, unit: medication.unitKind, bundle: lproj("en"), locale: Locale(identifier: "en")) == "400 drops")
        #expect(medication.dosesInStock == 20)

        medication.unitKind = .tablet
        medication.unitsPerDose = 0.5
        medication.stockCount = 3
        #expect(DoseFormatter.amount(medication.effectiveUnitsPerDose, unit: medication.unitKind, bundle: lproj("en"), locale: Locale(identifier: "en")) == "½ tablet")
        #expect(DoseFormatter.amount(medication.stockCount, unit: medication.unitKind, bundle: lproj("en"), locale: Locale(identifier: "en")) == "3 tablets")
        #expect(medication.dosesInStock == 6)
    }

    @Test func defaultUnitIsTablet() {
        let store = TestStore()
        let medication = store.medication()
        #expect(medication.unitKind == .tablet)
        #expect(DoseFormatter.amount(medication.effectiveUnitsPerDose, unit: medication.unitKind, bundle: lproj("en"), locale: Locale(identifier: "en")) == "1 tablet")
    }
}
