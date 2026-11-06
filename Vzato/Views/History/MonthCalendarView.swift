// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// Month grid with a status dot per day: green when every dose was taken, red when something was missed.
struct MonthCalendarView: View {
    @Binding var monthStart: Date
    @Binding var selectedDay: Date
    let summaries: [Date: DaySummary]

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var weekdayOrder: [Int] {
        (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
    }

    private var days: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<range.count {
            cells.append(calendar.date(byAdding: .day, value: offset, to: monthStart))
        }
        return cells
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button { shift(by: -1) } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel(Text("Previous month"))
                Spacer()
                Text(monthStart, format: .dateTime.month(.wide).year())
                    .font(.headline)
                Spacer()
                Button { shift(by: 1) } label: { Image(systemName: "chevron.right") }
                    .accessibilityLabel(Text("Next month"))
            }
            .buttonStyle(.borderless)

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(weekdayOrder, id: \.self) { weekday in
                    Text(calendar.veryShortStandaloneWeekdaySymbols[weekday - 1])
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(Text(calendar.standaloneWeekdaySymbols[weekday - 1]))
                }
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        DayCell(day: day, isSelected: calendar.isDate(day, inSameDayAs: selectedDay),
                                isToday: calendar.isDateInToday(day), summary: summaries[day]) {
                            selectedDay = day
                        }
                    } else {
                        Color.clear.frame(height: 40)
                    }
                }
            }
        }
    }

    private func shift(by months: Int) {
        if let next = calendar.date(byAdding: .month, value: months, to: monthStart) {
            monthStart = next
        }
    }
}

private struct DayCell: View {
    let day: Date
    let isSelected: Bool
    let isToday: Bool
    let summary: DaySummary?
    let action: () -> Void

    private var dotColor: Color? {
        guard let summary, summary.total > 0 else { return nil }
        if summary.missed > 0 { return Palette.missed }
        if summary.pending > 0 { return .secondary.opacity(0.5) }
        if summary.taken > 0 { return Palette.taken }
        return Palette.skipped
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(day, format: .dateTime.day())
                    .font(.body.weight(isToday ? .bold : .regular))
                    .monospacedDigit()
                Circle()
                    .fill(dotColor ?? .clear)
                    .frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(isSelected ? Color.accentColor.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(isToday ? Color.accentColor : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: Text {
        var text = Text(day, format: .dateTime.day().month(.wide))
        if let summary, summary.total > 0 {
            text = text + Text(verbatim: ", ") + Text("Taken \(summary.taken) of \(summary.total)")
        }
        return text
    }
}
