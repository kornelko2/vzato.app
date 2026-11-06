// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData
import Foundation
@testable import Vzato

/// Fixed calendar so tests do not depend on the machine's time zone or first weekday.
let testCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Prague")!
    calendar.firstWeekday = 2
    return calendar
}()

/// Monday 2 November 2026, 00:00 Prague time.
let monday = testCalendar.date(from: DateComponents(year: 2026, month: 11, day: 2))!

func at(_ day: Date, _ hour: Int, _ minute: Int = 0) -> Date {
    testCalendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
}

func days(_ count: Int, after day: Date) -> Date {
    testCalendar.date(byAdding: .day, value: count, to: day)!
}

@MainActor
final class TestStore {
    let controller = PersistenceController(inMemory: true)
    var context: NSManagedObjectContext { controller.viewContext }

    @discardableResult
    func medication(name: String = "Ibuprofen", times: [Int] = [8 * 60, 20 * 60], weekdays: [Int] = Array(1...7),
                    start: Date = monday, end: Date? = nil, stock: Double? = nil, unitsPerDose: Double = 1) -> Medication {
        let medication = Medication(context: context)
        medication.name = name
        medication.profile = controller.ensureDefaultProfile()
        let schedule = Schedule(context: context)
        schedule.minutesOfDay = times
        schedule.weekdays = weekdays
        schedule.startDate = start
        schedule.endDate = end
        schedule.medication = medication
        if let stock {
            medication.unitsPerDose = unitsPerDose
            StockService.setStock(medication, count: stock, at: start)
        }
        try! context.save()
        return medication
    }
}

@MainActor
final class SpyNotifier: DoseNotifying {
    var lowStockNames: [String] = []
    func notifyLowStock(_ medication: Medication) {
        lowStockNames.append(medication.name)
    }
}

/// The app bundle's `.lproj` folder for one language, so localized output can be asserted
/// regardless of the simulator's language.
func lproj(_ code: String) -> Bundle {
    let main = Bundle(for: Medication.self)
    guard let path = main.path(forResource: code, ofType: "lproj"), let bundle = Bundle(path: path) else {
        fatalError("No \(code).lproj in the app bundle")
    }
    return bundle
}
