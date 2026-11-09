// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import Vzato

struct MedicineIndexTests {
    private func index(_ lines: [String]) -> MedicineIndex {
        let text = (["#vzato-medicines\t1\tcz=2026-10-27\tsk=2026-11-07"] + lines).joined(separator: "\n")
        let data = try! (Data(text.utf8) as NSData).compressed(using: .zlib) as Data
        return MedicineIndex.load(compressed: data)!
    }

    private var sample: MedicineIndex {
        index([
            "cz\t0254294\tIBALGIN\t400MG\tPotahovaná tableta\t100\t0",
            "cz\t0254299\tIBALGIN\t400MG\tPotahovaná tableta\t24\t1",
            "cz\t0254097\tIBALGIN RAPIDCAPS\t400MG\tMěkká tobolka\t30\t1",
            "cz\t0187427\tLETROX\t100MCG\tTableta\t100\t1",
            "cz\t0000001\tOLD IBALGIN\t200MG\tTableta\t10\t0",
            "sk\t2620E\tIbalgin 400\t400 mg\tFilmom obalená tableta\t96\t",
        ])
    }

    @Test func readsDatesAndMergesPacks() {
        let index = sample
        #expect(index.dates == ["cz": "2026-10-27", "sk": "2026-11-07"])
        let ibalgin = index.entries.first { $0.name == "IBALGIN" }!
        #expect(ibalgin.packs == ["24", "100"])
        // The marketed pack represents the medicine, so the leaflet is the current one.
        #expect(ibalgin.code == "0254299")
        #expect(ibalgin.marketed == true)
        #expect(index.entries.first { $0.source == .sk }?.marketed == nil)
    }

    @Test func searchIgnoresCaseAndAccentsAndRanksPrefixesFirst() {
        let results = sample.search("ibal")
        #expect(results.map(\.name).prefix(3) == ["IBALGIN", "Ibalgin 400", "IBALGIN RAPIDCAPS"])
        #expect(results.last?.name == "OLD IBALGIN")
        #expect(sample.search("letrox 100").map(\.name) == ["LETROX"])
        #expect(sample.search("i").isEmpty)
    }

    @Test func preferredCountryComesFirstAmongEquals() {
        let results = sample.search("ibalgin 400", prefer: .sk)
        #expect(results.first?.source == .sk)
    }

    @Test func strengthAndUnitFitTheForm() {
        #expect(MedicineEntry.normalizedStrength("400MG") == "400 mg")
        #expect(MedicineEntry.normalizedStrength("450MG/50MG") == "450 mg/50 mg")
        #expect(MedicineEntry.normalizedStrength("100MCG") == "100 µg")
        #expect(MedicineEntry.normalizedStrength("400 mg") == "400 mg")
        #expect(MedicineEntry.normalizedStrength("50MG/G") == "50 mg/g")
        #expect(MedicineEntry.normalizedStrength("20MG/ML") == "20 mg/ml")
        #expect(MedicineEntry.unit(forForm: "Potahovaná tableta") == .tablet)
        #expect(MedicineEntry.unit(forForm: "Mäkká kapsula") == .capsule)
        #expect(MedicineEntry.unit(forForm: "Oční kapky, roztok") == .drop)
        #expect(MedicineEntry.unit(forForm: "Injekční roztok v předplněném peru") == .injection)
        #expect(MedicineEntry.unit(forForm: "Krém") == .piece)
    }

    @Test func bundledIndexHasBothCountries() {
        // The real file in the app bundle, built by Scripts/build-medicines-index.py.
        guard let index = MedicineIndex.bundled else { Issue.record("Medicines.index missing from the app"); return }
        #expect(index.entries.contains { $0.source == .cz })
        #expect(index.entries.contains { $0.source == .sk })
        #expect(!index.search("ibalgin").isEmpty)
    }
}

struct LeafletServiceTests {
    @Test func czechLeafletsComeFromSUKLByCode() {
        #expect(LeafletService.downloadURL(source: .cz, code: "0254299")?.absoluteString
                == "https://prehledy.sukl.gov.cz/dlp/v1/dokumenty/0254299/pil")
        #expect(LeafletService.downloadURL(source: .sk, code: "2620E") == nil)
        #expect(LeafletService.webURL(source: .sk, code: "2620E")?.absoluteString
                == "https://www.sukl.sk/vysledky-vyhladavania?search=2620E")
    }

    @Test func onlyPDFsAreKept() {
        #expect(LeafletService.isPDF(Data("%PDF-1.7\n...".utf8)))
        #expect(!LeafletService.isPDF(Data("{\"error\":404}".utf8)))
    }
}
