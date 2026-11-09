// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Which national register an entry comes from.
enum MedicineSource: String, Sendable {
    case cz, sk
}

/// One medicine of the bundled register: all packs of the same name, strength and form together.
struct MedicineEntry: Identifiable, Hashable, Sendable {
    let source: MedicineSource
    /// SÚKL or ŠÚKL code of a representative pack (a marketed one when there is one).
    let code: String
    let name: String
    /// As published: "400MG" (CZ) or "400 mg" (SK).
    let strength: String
    let form: String
    let packs: [String]
    /// Supplied to Czech pharmacies in the last 6 months; nil when the register does not say.
    let marketed: Bool?
    fileprivate let key: String

    var id: String { source.rawValue + code }

    /// "400 mg", "450 mg/50 mg", "100 µg": the strength in the app's style for the Dose field.
    var dosageText: String { Self.normalizedStrength(strength) }

    /// The dose unit that fits the pharmaceutical form; pieces when nothing fits.
    var unit: DoseUnit { Self.unit(forForm: form) }

    static func normalizedStrength(_ text: String) -> String {
        let units: [(String, String)] = [("MCG", "µg"), ("UG", "µg"), ("MG", "mg"), ("ML", "ml"), ("G", "g"), ("IU", "IU"), ("TU", "TU"), ("MU", "MU")]
        var result = text
        for (code, replacement) in units {
            result = result.replacingOccurrences(of: "(\\d)\\s*\(code)\\b", with: "$1 \(replacement)", options: .regularExpression)
        }
        // "50MG/G", "20MG/ML": the unit after the slash has no number in front.
        for (code, replacement) in [("ML", "ml"), ("G", "g"), ("MCG", "µg"), ("MG", "mg")] {
            result = result.replacingOccurrences(of: "/\(code)\\b", with: "/\(replacement)", options: .regularExpression)
        }
        return result
    }

    static func unit(forForm form: String) -> DoseUnit {
        let text = form.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        func has(_ parts: String...) -> Bool { parts.contains { text.contains($0) } }
        if has("kapk", "kvapk") { return .drop }
        if has("tobolk", "kapsul") { return .capsule }
        if has("tablet") { return .tablet }
        if has("injek", "infuz") { return .injection }
        if has("inhal") { return .puff }
        if has("granul", "sacek", "prasek pro peroral", "prasok na peroral") { return .sachet }
        if has("sirup", "peroralni roztok", "peroralny roztok", "peroralni suspenz", "peroralna suspenz") { return .milliliter }
        return .piece
    }
}

/// The offline register built by `Scripts/build-medicines-index.py` from SÚKL and ŠÚKL open data.
/// Searching never leaves the device.
final class MedicineIndex: Sendable {
    let entries: [MedicineEntry]
    /// Dates of the source data, e.g. ["cz": "2026-10-27", "sk": "2026-11-07"].
    let dates: [String: String]

    init(entries: [MedicineEntry], dates: [String: String]) {
        self.entries = entries
        self.dates = dates
    }

    /// Parses the raw-DEFLATE index file; packs of one medicine are merged into one entry.
    static func load(compressed data: Data) -> MedicineIndex? {
        guard let raw = try? (data as NSData).decompressed(using: .zlib) as Data,
              let text = String(data: raw, encoding: .utf8) else { return nil }
        var dates: [String: String] = [:]
        struct Group { var codes: [(String, Bool?)] = []; var packs: [String] = [] }
        var order: [String] = []
        var groups: [String: (source: MedicineSource, name: String, strength: String, form: String, group: Group)] = [:]
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            if line.hasPrefix("#") {
                for field in line.split(separator: "\t") where field.contains("=") {
                    let pair = field.split(separator: "=", maxSplits: 1).map(String.init)
                    dates[pair[0]] = pair[1]
                }
                continue
            }
            let f = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 7, let source = MedicineSource(rawValue: f[0]) else { continue }
            let marketed: Bool? = f[6] == "1" ? true : f[6] == "0" ? false : nil
            let groupKey = [f[0], f[2], f[3], f[4]].joined(separator: "\t")
            if groups[groupKey] == nil {
                groups[groupKey] = (source, f[2], f[3], f[4], Group())
                order.append(groupKey)
            }
            groups[groupKey]?.group.codes.append((f[1], marketed))
            if !f[5].isEmpty { groups[groupKey]?.group.packs.append(f[5]) }
        }
        let entries = order.compactMap { key -> MedicineEntry? in
            guard let g = groups[key] else { return nil }
            let code = g.group.codes.first { $0.1 == true }?.0 ?? g.group.codes.first?.0 ?? ""
            let marketed: Bool? = g.group.codes.contains { $0.1 == true } ? true
                : g.group.codes.allSatisfy { $0.1 == nil } ? nil : false
            var seen = Set<String>()
            // Smallest pack first: "10, 12, 24, 30".
            let packs = g.group.packs.filter { seen.insert($0).inserted }.sorted { a, b in
                let na = Int(a.prefix { $0.isNumber }) ?? .max, nb = Int(b.prefix { $0.isNumber }) ?? .max
                return na != nb ? na < nb : a < b
            }
            return MedicineEntry(source: g.source, code: code, name: g.name, strength: g.strength, form: g.form,
                                 packs: packs, marketed: marketed, key: Self.fold("\(g.name) \(g.strength)"))
        }
        return MedicineIndex(entries: entries, dates: dates)
    }

    /// The index shipped in the app, loaded once (about 100 000 lines; call off the main thread).
    static let bundled: MedicineIndex? = {
        guard let url = Bundle.main.url(forResource: "Medicines", withExtension: "index"),
              let data = try? Data(contentsOf: url) else { return nil }
        return load(compressed: data)
    }()

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    /// Medicines whose name (or name and strength) matches every typed word. Names that start with the
    /// query come first, then marketed ones, then the preferred country.
    func search(_ query: String, limit: Int = 40, prefer: MedicineSource? = nil) -> [MedicineEntry] {
        let words = Self.fold(query).split(whereSeparator: { $0 == " " || $0 == "," }).map(String.init)
        guard let first = words.first, first.count >= 2 else { return [] }
        func rank(_ entry: MedicineEntry) -> Int {
            var score = 0
            if !entry.key.hasPrefix(first) { score += entry.key.contains(" " + first) ? 10 : 20 }
            if entry.marketed == false { score += 4 }
            if let prefer, entry.source != prefer { score += 2 }
            return score
        }
        let matches = entries.filter { entry in words.allSatisfy { entry.key.contains($0) } }
        return matches
            .map { ($0, rank($0)) }
            .sorted { a, b in
                if a.1 != b.1 { return a.1 < b.1 }
                if a.0.name.count != b.0.name.count { return a.0.name.count < b.0.name.count }
                return a.0.key < b.0.key
            }
            .prefix(limit)
            .map(\.0)
    }
}
