// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import Vzato

/// Several profiles: you, a child, a dog with a monthly deworming tablet.
@MainActor
struct ProfileTests {
    private func dog(_ store: TestStore) -> Profile {
        let profile = Profile(context: store.context)
        profile.name = "Mentík"
        profile.kind = .pet
        try! store.context.save()
        return profile
    }

    @Test func singleProfileKeepsPlainNames() {
        let store = TestStore()
        let medication = store.medication(name: "Letrox")
        #expect(!Profile.several(in: store.context))
        #expect(medication.nameWithProfile == "Letrox")
    }

    @Test func severalProfilesNameWhoseDoseItIs() {
        let store = TestStore()
        let mine = store.medication(name: "Letrox")
        let milbemax = store.medication(name: "Milbemax", times: [8 * 60], repeat: .months, profile: dog(store))
        #expect(Profile.several(in: store.context))
        #expect(milbemax.nameWithProfile == "Mentík · Milbemax")
        #expect(mine.nameWithProfile.hasSuffix(" · Letrox"))
    }

    @Test func filterShowsOneProfile() {
        let store = TestStore()
        let pet = dog(store)
        store.medication(name: "Letrox")
        store.medication(name: "Milbemax", repeat: .months, profile: pet)
        let all = [Medication](try! store.context.fetch(Medication.fetchRequest()))
        #expect(all.of(profile: nil).count == 2)
        #expect(all.of(profile: pet.id).map(\.name) == ["Milbemax"])
    }

    @Test func petsGetAPawByDefault() {
        let store = TestStore()
        #expect(dog(store).symbol == "pawprint.fill")
        #expect(store.controller.ensureDefaultProfile().symbol == "person.fill")
    }

    @Test func exportNamesTheProfile() {
        let store = TestStore()
        let milbemax = store.medication(name: "Milbemax", times: [8 * 60], repeat: .months, profile: dog(store))
        let slot = DoseScheduler.slots(for: [milbemax], on: monday, calendar: testCalendar)[0]
        let event = DoseLogger(context: store.context).markTaken(slot, at: at(monday, 8))
        let csv = CSVExport.make(events: [event])
        #expect(csv.hasPrefix("medication,dosage,scheduled_at,status,taken_at,source,unscheduled,profile\n"))
        #expect(csv.contains(",Mentík\n"))
    }
}

@MainActor
struct CSVMissedTests {
    @Test func missedDosesAreExportedInTimeOrder() {
        let store = TestStore()
        let medication = store.medication(name: "Letrox", times: [8 * 60, 20 * 60])
        let logger = DoseLogger(context: store.context, now: at(monday, 8, 5), notifier: SpyNotifier())
        logger.markTaken(DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar)[0])
        let now = at(days(1, after: monday), 12)
        let missed = CSVExport.missedSlots(for: [medication], now: now, grace: 2 * 3600, calendar: testCalendar)
        // Monday 20:00 and Tuesday 8:00 are missed; Tuesday 20:00 is still ahead.
        #expect(missed.map(\.scheduledAt) == [at(monday, 20), at(days(1, after: monday), 8)])
        let lines = CSVExport.make(events: medication.eventList, missed: missed).split(separator: "\n")
        #expect(lines.count == 4)
        #expect(lines[1].contains(",taken,"))
        #expect(lines[2].contains(",missed,") && lines[3].contains(",missed,"))
    }
}

@MainActor
struct CSVFileTests {
    @Test func writesACSVFileExcelReadsAsUTF8() throws {
        let url = try #require(CSVExport.writeFile("medication\nŽelezo\n", on: monday))
        #expect(url.pathExtension == "csv")
        let data = try Data(contentsOf: url)
        #expect(data.prefix(3) == Data([0xEF, 0xBB, 0xBF]))
        #expect(String(decoding: data.dropFirst(3), as: UTF8.self) == "medication\nŽelezo\n")
    }
}
