// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import Vzato

@MainActor
struct MedicationArchiveTests {
    @Test func restoredMedicationHasNoMissedDosesFromTheArchivedTime() {
        let store = TestStore()
        let medication = store.medication(times: [8 * 60])
        // Taken on Monday, archived on Monday evening, restored on Thursday at noon.
        let monday8 = DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar)[0]
        DoseLogger(context: store.context).markTaken(monday8, at: at(monday, 8))
        MedicationArchive.archive(medication, now: at(monday, 20))
        #expect(DoseScheduler.slots(for: [medication], on: days(1, after: monday), calendar: testCalendar).isEmpty)

        MedicationArchive.restore(medication, now: at(days(3, after: monday), 12))
        #expect(!medication.isArchived)
        // Tuesday and Wednesday stay empty instead of turning into missed doses.
        #expect(DoseScheduler.slots(for: [medication], on: days(1, after: monday), calendar: testCalendar).isEmpty)
        #expect(DoseScheduler.slots(for: [medication], on: days(2, after: monday), calendar: testCalendar).isEmpty)
        // The dose taken before archiving is still in the history.
        #expect(DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar).first?.event?.status == .taken)
        // From Friday on it is planned again.
        #expect(DoseScheduler.slots(for: [medication], on: days(4, after: monday), calendar: testCalendar).count == 1)
    }
}
