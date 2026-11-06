// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// The large card at the top of Today: one dose, one big button.
struct NextDoseCard: View {
    let slot: DoseSlot
    let now: Date
    let grace: TimeInterval
    let snoozeMinutes: Int
    let onTaken: () -> Void
    let onSnooze: () -> Void
    let onSkip: () -> Void

    @State private var showingPill = false
    private var pillPhotos: [MedicationPhoto] { slot.medication.photos(of: .pill) }
    private var isOverdue: Bool { slot.isOverdue(now: now, grace: grace) }
    private var isMissed: Bool { slot.status(now: now, grace: grace) == .missed }
    private var needsAttention: Bool { isOverdue || isMissed }
    private var mealRelation: MealRelation? {
        slot.medication.activeSchedules.first { schedule in
            DoseScheduler.times(for: schedule, on: slot.scheduledAt, calendar: .current)
                .contains { Calendar.current.isDate($0, equalTo: slot.scheduledAt, toGranularity: .minute) }
        }?.mealRelation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Text(slot.scheduledAt, style: .time)
                    Text(verbatim: "·")
                    if isMissed {
                        Text("Missed")
                    } else if isOverdue {
                        Text("Overdue")
                    } else {
                        Text("Next")
                    }
                }
                .font(.subheadline.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(isMissed ? Palette.missed : (isOverdue ? Palette.overdue : .secondary))
                Spacer()
                Circle()
                    .fill(Color(hex: slot.medication.colorHex))
                    .frame(width: 14, height: 14)
                    .accessibilityHidden(true)
            }

            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(slot.medication.name)
                        .font(.system(size: 32, weight: .heavy))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 6) {
                        if !slot.medication.dosageText.isEmpty {
                            Text(slot.medication.dosageText)
                        }
                        if let mealRelation, mealRelation != .any {
                            if !slot.medication.dosageText.isEmpty { Text(verbatim: "·") }
                            Text(mealRelation.label)
                        }
                    }
                    .font(.title3)
                    .foregroundStyle(.secondary)
                }
                if let pill = pillPhotos.first {
                    Spacer(minLength: 0)
                    Button {
                        showingPill = true
                    } label: {
                        PhotoThumbnail(photo: pill, size: 72)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Show pill photo"))
                }
            }

            Button(action: onTaken) {
                Text("Taken")
                    .font(.title2.weight(.heavy))
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity, minHeight: 64)
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.taken)
            .accessibilityHint(Text("Records this dose as taken now"))

            HStack(spacing: 10) {
                Button(action: onSnooze) {
                    Text("Snooze \(snoozeMinutes) min")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                Button(action: onSkip) {
                    Text("Skip")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(isMissed ? Palette.missed : (isOverdue ? Palette.overdue : Color.primary), lineWidth: 2)
        )
        .accessibilityElement(children: .contain)
        .photoViewer(isPresented: $showingPill, photos: pillPhotos, title: Text("Pill photo"))
    }
}
