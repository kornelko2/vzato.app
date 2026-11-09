// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData
import Foundation

/// Archiving hides a medication from Today and stops its reminders; the history stays.
@MainActor
enum MedicationArchive {
    static func archive(_ medication: Medication, now: Date = Date()) {
        medication.isArchived = true
        medication.archivedAt = now
        try? medication.managedObjectContext?.save()
    }

    /// Back to the active list. Doses from the time it was archived were never asked for, so they
    /// must not show up as missed: the medication counts as added again now. Doses recorded
    /// before still show in the history.
    static func restore(_ medication: Medication, now: Date = Date()) {
        medication.isArchived = false
        medication.archivedAt = nil
        medication.createdAt = now
        try? medication.managedObjectContext?.save()
    }
}
