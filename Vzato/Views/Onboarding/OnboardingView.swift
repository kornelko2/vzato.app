// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData
import SwiftUI
import UserNotifications

/// First-start guide: welcome, notifications, then the first medication in three small steps.
/// One thing per screen, large type, a big Continue button; every step can be skipped.
struct OnboardingView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.openURL) private var openURL
    let onFinish: () -> Void

    enum Step: Int, CaseIterable {
        case welcome, notifications, name, amount, times, done
    }

    struct TimeChoice: Identifiable {
        let id: Int
        let label: LocalizedStringResource
        var minutes: Int
        var isOn: Bool
    }

    @State private var step = Step.welcome
    @State private var draft = MedicationDraft(colorHex: Palette.medicationHexes[3])
    @State private var times: [TimeChoice] = [
        TimeChoice(id: 0, label: "Morning", minutes: 8 * 60, isOn: true),
        TimeChoice(id: 1, label: "Noon", minutes: 12 * 60, isOn: false),
        TimeChoice(id: 2, label: "Evening", minutes: 18 * 60, isOn: false),
        TimeChoice(id: 3, label: "Night", minutes: 22 * 60, isOn: false),
    ]
    @State private var saveFailed = false
    @FocusState private var nameFocused: Bool
    private var notifications: NotificationService { .shared }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    content
                }
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(24)
            }
            footer
        }
        .task { await notifications.refreshAuthorizationStatus() }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 620)
        #endif
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding")
    }

    // MARK: Parts

    private var header: some View {
        HStack {
            if step != .welcome && step != .done {
                Button {
                    back()
                } label: {
                    Label("Back", systemImage: "chevron.backward")
                }
                .accessibilityIdentifier("onboardingBack")
            }
            Spacer()
            HStack(spacing: 8) {
                ForEach(Step.allCases, id: \.self) { item in
                    Circle()
                        .fill(item.rawValue <= step.rawValue ? Palette.taken : Color.secondary.opacity(0.3))
                        .frame(width: 9, height: 9)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(Text("Step \(step.rawValue + 1) of \(Step.allCases.count)"))
            Spacer()
            if step != .done {
                Button("Skip") { onFinish() }
                    .accessibilityIdentifier("onboardingSkip")
            }
        }
        .font(.body.weight(.semibold))
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(minHeight: 52)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            Image("IconPreviewPill")
                .resizable()
                .frame(width: 110, height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .accessibilityHidden(true)
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
            title("Vzato reminds you of your medications.")
            Text("When it is time, you only tap Taken. Vzato remembers that you took it, counts your supply and shows the history.")
                .font(.title3)
            Text("Let's set it up together. It takes about a minute.")
                .font(.title3)
                .foregroundStyle(.secondary)

        case .notifications:
            Image(systemName: notificationsAllowed ? "bell.badge.fill" : "bell.fill")
                .font(.system(size: 64))
                .foregroundStyle(Palette.taken)
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
            title("Allow notifications")
            Text("Without them you will not hear a reminder and nothing appears on the lock screen.")
                .font(.title3)
            if notificationsAllowed {
                Label("Notifications are allowed", systemImage: "checkmark.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Palette.taken)
            } else if notifications.authorizationStatus == .denied {
                Text("Notifications are turned off for Vzato. Turn them on in the system settings.")
                    .font(.title3)
                    .foregroundStyle(Palette.missed)
            } else {
                Text("On the next screen the system asks. Tap Allow.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

        case .name:
            title("What is the medication called?")
            TextField(text: $draft.name, prompt: Text("e.g. Ibuprofen")) { Text("Name") }
                .font(.title2)
                .textFieldStyle(.roundedBorder)
                .focused($nameFocused)
                .submitLabel(.next)
                .onSubmit { if canContinue { next() } }
                .accessibilityIdentifier("onboardingName")
            Text("Strength, if it is on the package (optional)")
                .font(.headline)
            TextField(text: $draft.dosageText, prompt: Text("e.g. 400 mg")) { Text("Strength") }
                .font(.title3)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("onboardingStrength")

        case .amount:
            title("How much do you take at once?")
            Picker(selection: $draft.unit) {
                ForEach(DoseUnit.allCases) { unit in
                    Label { Text(unit.label) } icon: { Image(systemName: unit.symbolName) }.tag(unit)
                }
            } label: {
                Text("Unit")
            }
            .pickerStyle(.menu)
            .font(.title3)
            .onChange(of: draft.unit) { _, unit in
                draft.unitsPerDose = min(max(draft.unitsPerDose.rounded(), 1), unit.maximumPerDose)
            }
            HStack(spacing: 16) {
                stepButton("minus", label: Text("Less")) { changeAmount(by: -amountStep) }
                    .disabled(draft.unitsPerDose <= minimumAmount)
                Text(DoseFormatter.amount(draft.unitsPerDose, unit: draft.unit))
                    .font(.system(size: 34, weight: .heavy))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("onboardingAmount")
                stepButton("plus", label: Text("More")) { changeAmount(by: amountStep) }
                    .disabled(draft.unitsPerDose >= draft.unit.maximumPerDose)
            }
            Text("A quarter tablet or a different amount can be set later in Medications.")
                .font(.callout)
                .foregroundStyle(.secondary)

        case .times:
            title("When do you take it?")
            Text("Every day. Turn on one or more times; tap a time to change it.")
                .font(.title3)
                .foregroundStyle(.secondary)
            VStack(spacing: 12) {
                ForEach($times) { $choice in
                    HStack {
                        Toggle(isOn: $choice.isOn) {
                            Text(choice.label).font(.title3.weight(.semibold))
                        }
                        .accessibilityIdentifier("onboardingTime\(choice.id)")
                        if choice.isOn {
                            DatePicker(selection: timeBinding($choice.minutes), displayedComponents: .hourAndMinute) {
                                Text(choice.label)
                            }
                            .labelsHidden()
                        }
                    }
                    .padding(14)
                    .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                }
            }

        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Palette.taken)
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
            title("All set")
            Text(verbatim: "\(DoseFormatter.amount(draft.unitsPerDose, unit: draft.unit)) \(draft.trimmedName)")
                .font(.title2.weight(.bold))
            Text("Every day at \(timesText)")
                .font(.title3)
            Text("When it is time, Vzato reminds you. Then tap Taken.")
                .font(.title3)
            Text("Supply, photos and meals can be added in Medications. Help is in Settings.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        if saveFailed {
            Text("The medication could not be saved. Try again.")
                .foregroundStyle(Palette.missed)
        }
    }

    private var footer: some View {
        Button(action: primaryAction) {
            Text(primaryTitle)
                .font(.title3.weight(.heavy))
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.borderedProminent)
        .tint(Palette.taken)
        .disabled(!canContinue)
        .keyboardShortcut(.defaultAction)
        .accessibilityIdentifier("onboardingContinue")
        .frame(maxWidth: 560)
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .padding(.top, 8)
    }

    private func title(_ text: LocalizedStringResource) -> some View {
        Text(text)
            .font(.system(.largeTitle, weight: .heavy))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private func stepButton(_ symbol: String, label: Text, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title.weight(.bold))
                .frame(width: 64, height: 64)
        }
        .buttonStyle(.bordered)
        .clipShape(Circle())
        .accessibilityLabel(label)
    }

    // MARK: Logic

    private var notificationsAllowed: Bool {
        notifications.authorizationStatus != .denied && notifications.authorizationStatus != .notDetermined
    }

    private var amountStep: Double { draft.unit.allowsFractions ? 0.5 : 1 }
    private var minimumAmount: Double { amountStep }

    private var canContinue: Bool {
        switch step {
        case .name: !draft.trimmedName.isEmpty
        case .times: times.contains(where: \.isOn)
        default: true
        }
    }

    private var primaryTitle: LocalizedStringResource {
        switch step {
        case .welcome: "Let's start"
        case .notifications:
            if notificationsAllowed { "Continue" }
            else if notifications.authorizationStatus == .denied { "Open settings" }
            else { "Allow notifications" }
        case .times: "Save"
        case .done: "Done"
        default: "Continue"
        }
    }

    private var timesText: String {
        let calendar = Calendar.current
        let dates = draft.minutes.sorted().compactMap {
            calendar.date(bySettingHour: $0 / 60, minute: $0 % 60, second: 0, of: Date())
        }
        return dates.map { $0.formatted(date: .omitted, time: .shortened) }.formatted(.list(type: .and))
    }

    private func primaryAction() {
        switch step {
        case .notifications where !notificationsAllowed:
            if notifications.authorizationStatus == .denied {
                if let url = URL(string: RemindersOffBanner.settingsURL) { openURL(url) }
                go(to: .name)
            } else {
                Task {
                    await notifications.requestAuthorization()
                    go(to: .name)
                }
            }
        case .times:
            draft.minutes = times.filter(\.isOn).map(\.minutes)
            let profile = PersistenceController.shared.ensureDefaultProfile()
            if MedicationFactory.create(draft, profile: profile, in: context) != nil {
                saveFailed = false
                Task { await notifications.rescheduleAll() }
                go(to: .done)
            } else {
                saveFailed = true
            }
        case .done:
            onFinish()
        default:
            next()
        }
    }

    private func next() {
        guard let following = Step(rawValue: step.rawValue + 1) else { return }
        go(to: following)
    }

    private func back() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        go(to: previous)
    }

    private func go(to target: Step) {
        withAnimation { step = target }
        nameFocused = target == .name
    }

    private func changeAmount(by delta: Double) {
        draft.unitsPerDose = min(draft.unit.maximumPerDose, max(minimumAmount, draft.unitsPerDose + delta))
    }

    private func timeBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: minutes.wrappedValue / 60, minute: minutes.wrappedValue % 60, second: 0, of: Date()) ?? Date()
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            minutes.wrappedValue = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }
    }
}
