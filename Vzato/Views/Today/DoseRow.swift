// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// One dose in a list: time, status, medication. Used in Today's timeline and in History.
struct DoseRow: View {
    let slot: DoseSlot
    let now: Date
    let grace: TimeInterval
    var compact = false
    let onTaken: () -> Void
    let onSkipped: () -> Void
    let onReset: () -> Void

    private var status: DoseStatus { slot.status(now: now, grace: grace) }
    private var isOverdue: Bool { slot.isOverdue(now: now, grace: grace) }

    var body: some View {
        HStack(spacing: 12) {
            Text(slot.scheduledAt, style: .time)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
                .monospacedDigit()

            Image(systemName: isOverdue ? "exclamationmark.circle" : status.symbolName)
                .font(.title3)
                .foregroundStyle(isOverdue ? Palette.overdue : status.color)
                .accessibilityLabel(Text(isOverdue ? "Overdue" : status.label))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Circle().fill(Color(hex: slot.medication.colorHex)).frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                    Text(slot.medication.name).font(.body.weight(.semibold)).lineLimit(1)
                    if slot.isUnscheduled {
                        Text("extra").font(.caption).foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 6) {
                    Text(slot.medication.doseAmountText).font(.subheadline).foregroundStyle(.secondary)
                    if !slot.medication.dosageText.isEmpty {
                        Text(verbatim: "·").foregroundStyle(.secondary)
                        Text(slot.medication.dosageText).font(.subheadline).foregroundStyle(.secondary)
                    }
                    statusLine
                }
            }
            Spacer(minLength: 8)
            if !compact, status == .pending || status == .missed {
                Button(action: onTaken) {
                    Text("Taken").frame(minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.taken)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .swipeActions(edge: .leading) {
            if status != .taken {
                Button(action: onTaken) { Label("Taken", systemImage: "checkmark") }.tint(Palette.taken)
            }
        }
        .swipeActions(edge: .trailing) {
            if status != .skipped && !slot.isUnscheduled {
                Button(action: onSkipped) { Label("Skip", systemImage: "forward") }.tint(Palette.skipped)
            }
            if slot.event != nil {
                Button(action: onReset) { Label("Reset", systemImage: "arrow.uturn.backward") }
            }
        }
        .contextMenu {
            if status != .taken { Button(action: onTaken) { Label("Taken", systemImage: "checkmark") } }
            if status != .skipped && !slot.isUnscheduled { Button(action: onSkipped) { Label("Skip", systemImage: "forward") } }
            if slot.event != nil { Button(action: onReset) { Label("Reset", systemImage: "arrow.uturn.backward") } }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var statusLine: some View {
        switch status {
        case .taken:
            if let takenAt = slot.event?.takenAt {
                HStack(spacing: 4) {
                    Text("Taken at")
                    Text(takenAt, style: .time)
                }
                .font(.caption).foregroundStyle(Palette.taken)
            }
        case .skipped:
            Text("Skipped").font(.caption).foregroundStyle(Palette.skipped)
        case .missed:
            Text("Missed").font(.caption).foregroundStyle(Palette.missed)
        case .pending:
            if isOverdue {
                Text("Overdue").font(.caption).foregroundStyle(Palette.overdue)
            }
        }
    }
}
