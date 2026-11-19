// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// The big card on Today when the dose that needs attention comes from the pill organizer: the whole
/// compartment, one button for all of it (specification 15.1).
struct OrganizerCard: View {
    @Environment(\.showsProfiles) private var showsProfiles
    let group: OrganizerGroup
    let now: Date
    let grace: TimeInterval
    let snoozeMinutes: Int
    let takeMode: NextDoseCard.TakeMode
    let onTaken: () -> Void
    let onSnooze: () -> Void
    let onSkip: () -> Void

    /// The compartment is due, overdue and missed by its earliest open dose.
    private var lead: DoseSlot? { group.openSlots.first ?? group.slots.first }
    private var isOverdue: Bool { lead?.isOverdue(now: now, grace: grace) ?? false }
    private var isMissed: Bool { lead?.status(now: now, grace: grace) == .missed }
    private var accent: Color { isMissed ? Palette.missed : (isOverdue ? Palette.overdue : .primary) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Text(lead?.scheduledAt ?? group.scheduledAt, style: .time)
                Text(verbatim: "·")
                if isMissed {
                    Text("Missed")
                } else if isOverdue {
                    Text("Overdue")
                } else {
                    Text("Next")
                }
                Spacer()
                Text("\(group.slots.count) medications")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.bold))
            .textCase(.uppercase)
            .foregroundStyle(isMissed ? Palette.missed : (isOverdue ? Palette.overdue : .secondary))

            VStack(alignment: .leading, spacing: 4) {
                if showsProfiles, let profile = group.slots.first?.medication.profile {
                    ProfileBadge(profile: profile, font: .headline)
                }
                Label { Text(group.compartment.label) } icon: { Image(systemName: group.compartment.symbolName) }
                    .font(.largeTitle.weight(.heavy))
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(group.slots) { slot in
                    row(slot)
                }
            }

            if takeMode == .direct {
                Button(action: onTaken) {
                    Text(group.compartment.takenLabel)
                        .font(.title2.weight(.heavy))
                        .textCase(.uppercase)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 64)
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.taken)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("takenCompartment")
                .accessibilityHint(Text("Records every open dose of this compartment as taken now"))

                let secondary = Group {
                    Button(action: onSnooze) {
                        Text("Snooze \(snoozeMinutes) min")
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    Button(action: onSkip) {
                        Text("Skip")
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { secondary }
                    VStack(spacing: 10) { secondary }
                }
                .buttonStyle(.bordered)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "clock")
                        .font(.title2)
                    Text("Next dose at \((lead?.scheduledAt ?? group.scheduledAt).formatted(date: .omitted, time: .shortened))")
                        .font(.title3.weight(.bold))
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                .accessibilityElement(children: .combine)

                if takeMode == .askFirst {
                    Button(action: onTaken) {
                        Text("Taken…")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("takeCompartmentEarly")
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20).strokeBorder(accent, lineWidth: 2))
        .accessibilityElement(children: .contain)
    }

    private func row(_ slot: DoseSlot) -> some View {
        let status = slot.status(now: now, grace: grace)
        let detail = slot.medication.dosageText.isEmpty
            ? slot.medication.doseAmountText
            : "\(slot.medication.doseAmountText) · \(slot.medication.dosageText)"
        return HStack(spacing: 10) {
            if let photo = slot.medication.photos(of: .pill).first {
                PhotoThumbnail(photo: photo, size: 36)
            } else {
                Circle().fill(Color(hex: slot.medication.colorHex)).frame(width: 12, height: 12)
                    .frame(width: 36)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(slot.medication.name).font(.title3.weight(.bold))
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if slot.event != nil {
                Image(systemName: status.symbolName)
                    .font(.title3)
                    .foregroundStyle(status.color)
                    .accessibilityLabel(Text(status.label))
            }
        }
        .accessibilityElement(children: .combine)
    }
}
