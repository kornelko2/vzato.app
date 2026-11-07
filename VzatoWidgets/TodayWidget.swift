// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import WidgetKit

@main
struct VzatoWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        #if os(iOS)
        NextDoseAccessoryWidget()
        #endif
    }
}

/// Home screen (iPhone, iPad) and Notification Centre / desktop (Mac): the next dose with a big button.
struct TodayWidget: Widget {
    let kind = "VzatoToday"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName(Text("Today"))
        .description(Text("Your next dose with a Taken button."))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    var body: some View {
        switch family {
        case .systemMedium:
            HStack(alignment: .top, spacing: 14) {
                FeaturedDoseView(entry: entry)
                if !entry.upcoming.isEmpty {
                    Divider()
                    UpcomingListView(doses: Array(entry.upcoming.prefix(3)))
                }
            }
        default:
            FeaturedDoseView(entry: entry)
        }
    }
}

/// The widget version of the big card: time and state, name, amount, one button.
struct FeaturedDoseView: View {
    let entry: TodayEntry

    var body: some View {
        if let dose = entry.featured {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(dose.scheduledAt, style: .time)
                    Text(verbatim: "·")
                    stateLabel(dose)
                }
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(stateColor(dose))
                .lineLimit(1)

                HStack(spacing: 6) {
                    Circle().fill(Color(hex: dose.colorHex)).frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                    Text(dose.name).font(.headline).lineLimit(1)
                }
                Text(dose.amount)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                if !dose.strength.isEmpty {
                    Text(dose.strength).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 4)
                takenButton(for: dose)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: entry.total > 0 ? "checkmark.circle.fill" : "pills")
                    .font(.title)
                    .foregroundStyle(entry.total > 0 ? Palette.taken : .secondary)
                if entry.total > 0 {
                    Text("All done for today").font(.headline)
                    Text(verbatim: "\(entry.taken) / \(entry.total)").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("No doses today").font(.headline)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func takenButton(for dose: WidgetDose) -> some View {
        if !dose.canTakeNow {
            // Not due yet, or the same medication was just taken: no one-tap button.
            HStack(spacing: 4) {
                Image(systemName: "clock")
                Text("Next at \(dose.scheduledAt.formatted(date: .omitted, time: .shortened))")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 32)
        } else if let id = dose.medicationID {
            Button(intent: MarkDoseTakenIntent(medicationID: id, scheduledAt: dose.scheduledAt)) {
                Label("Taken", systemImage: "checkmark")
                    .font(.subheadline.weight(.heavy))
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.taken)
        } else {
            Label("Taken", systemImage: "checkmark")
                .font(.subheadline.weight(.heavy))
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(Palette.taken, in: Capsule())
                .foregroundStyle(.white)
        }
    }
}

struct UpcomingListView: View {
    let doses: [WidgetDose]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if doses.contains(where: { !$0.isCurrent }) || doses.isEmpty {
                Text("Later").font(.caption.weight(.bold)).foregroundStyle(.secondary).textCase(.uppercase)
            }
            ForEach(doses) { dose in
                HStack(alignment: .center, spacing: 6) {
                    Circle().fill(Color(hex: dose.colorHex)).frame(width: 7, height: 7)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(dose.name).font(.caption.weight(.semibold)).lineLimit(1)
                        HStack(spacing: 4) {
                            Text(dose.scheduledAt, style: .time)
                            Text(verbatim: "·")
                            Text(dose.amount)
                        }
                        .font(.caption2)
                        .foregroundStyle(dose.isCurrent ? stateColor(dose) : .secondary)
                        .lineLimit(1)
                    }
                    Spacer(minLength: 2)
                    if dose.isCurrent, dose.canTakeNow, let id = dose.medicationID {
                        Button(intent: MarkDoseTakenIntent(medicationID: id, scheduledAt: dose.scheduledAt)) {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.heavy))
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.circle)
                        .tint(Palette.taken)
                        .accessibilityLabel(Text("Taken"))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@ViewBuilder
func stateLabel(_ dose: WidgetDose) -> some View {
    if dose.status == .missed {
        Text("Missed")
    } else if dose.isOverdue {
        Text("Overdue")
    } else {
        Text("Next")
    }
}

func stateColor(_ dose: WidgetDose) -> Color {
    if dose.status == .missed { return Palette.missed }
    if dose.isOverdue { return Palette.overdue }
    return .secondary
}

#if os(iOS)
/// Lock Screen: the next dose at a glance.
struct NextDoseAccessoryWidget: Widget {
    let kind = "VzatoNextDose"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
            AccessoryDoseView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName(Text("Next dose"))
        .description(Text("The next dose on the Lock Screen."))
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

struct AccessoryDoseView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            if let dose = entry.featured {
                Label {
                    Text("\(dose.scheduledAt.formatted(date: .omitted, time: .shortened)) \(dose.name)")
                } icon: {
                    Image(systemName: "pill")
                }
            } else {
                Label("All done for today", systemImage: "checkmark.circle")
            }
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                if let dose = entry.featured, dose.isCurrent, dose.canTakeNow, let id = dose.medicationID {
                    Button(intent: MarkDoseTakenIntent(medicationID: id, scheduledAt: dose.scheduledAt)) {
                        VStack(spacing: 0) {
                            Image(systemName: "checkmark").font(.title3.weight(.heavy))
                            Text(dose.scheduledAt, style: .time).font(.caption2.weight(.semibold)).minimumScaleFactor(0.6)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Taken"))
                } else if let dose = entry.featured {
                    VStack(spacing: 0) {
                        Image(systemName: "pill.fill").font(.caption)
                        Text(dose.scheduledAt, style: .time).font(.caption2.weight(.semibold)).minimumScaleFactor(0.6)
                    }
                } else {
                    Image(systemName: "checkmark").font(.title3.weight(.bold))
                }
            }
        default:
            if let dose = entry.featured {
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Image(systemName: "pill.fill")
                            Text(dose.scheduledAt, style: .time)
                            if dose.isCurrent {
                                Text(verbatim: "·")
                                stateLabel(dose)
                            }
                        }
                        .font(.headline)
                        .lineLimit(1)
                        Text(dose.name).font(.body.weight(.semibold)).lineLimit(1)
                        Text(dose.amount).font(.caption).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if dose.isCurrent, dose.canTakeNow, let id = dose.medicationID {
                        Button(intent: MarkDoseTakenIntent(medicationID: id, scheduledAt: dose.scheduledAt)) {
                            Image(systemName: "checkmark")
                                .font(.title3.weight(.heavy))
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .accessibilityLabel(Text("Taken"))
                    }
                }
            } else {
                Label("All done for today", systemImage: "checkmark.circle")
                    .font(.headline)
            }
        }
    }
}
#endif
