// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// Short how-tos in numbered steps, built into the app so they work without internet.
/// The same guides with pictures are on vzato.app.
struct HelpView: View {
    struct Topic: Identifiable {
        let id: String
        let title: LocalizedStringResource
        let symbol: String
        let steps: [LocalizedStringResource]
    }

    static let topics: [Topic] = [
        Topic(id: "add", title: "Add a medication", symbol: "plus.circle", steps: [
            "Open Medications and tap Add medication.",
            "Write the name and how much you take at once.",
            "Under Schedule, set when you take it. Add time adds another one.",
            "If Vzato should count your tablets, turn on Track supply and enter how many you have.",
            "Tap Save.",
        ]),
        Topic(id: "reminder", title: "When a reminder comes", symbol: "bell", steps: [
            "At dose time you hear a sound and see the reminder, also on the lock screen and on Apple Watch.",
            "Tap Taken in the reminder or in the app. That is all.",
            "Not now? Tap Snooze. Vzato reminds you again in a few minutes.",
            "Not taking this dose? Tap Skip.",
            "Tapped by mistake? Tap Undo right away. Later, touch and hold the dose in the Whole day list and choose Reset.",
        ]),
        Topic(id: "button", title: "Why there is no Taken button", symbol: "hand.raised", steps: [
            "The Taken button appears from 30 minutes before the dose. This protects you from taking a dose twice.",
            "If you have to take a later dose now, touch and hold it in the Whole day list and choose Taken. Vzato asks before it records it.",
        ]),
        Topic(id: "supply", title: "Supply", symbol: "shippingbox", steps: [
            "Every dose you take is subtracted from the supply.",
            "Medications shows how much is left and by when to get more.",
            "Bought a new package? Open the medication, tap Edit and change Amount at home.",
            "Not sure the number is right? Count your tablets, tap Count and check supply and enter the number. Vzato shows whether it matches the records.",
        ]),
        Topic(id: "photos", title: "Photos", symbol: "camera", steps: [
            "Open the medication. Under Photos add the pill, the package or the leaflet.",
            "Under Photo on Today choose which photo appears on the big card.",
        ]),
        Topic(id: "history", title: "History and your doctor", symbol: "calendar", steps: [
            "History shows every day in a calendar: green is taken, red is missed.",
            "Tap a day to see it or correct it.",
            "At the bottom of History is Summary for the doctor. Choose 7, 30 or 90 days and tap Export PDF to print or send it.",
        ]),
        Topic(id: "devices", title: "iPhone, iPad and Mac", symbol: "ipad.and.iphone", steps: [
            "Sign in with the same Apple Account on all devices and turn on iCloud. Vzato syncs by itself.",
            "A dose confirmed on one device shows as taken on the others.",
        ]),
        Topic(id: "noReminder", title: "I did not get a reminder", symbol: "bell.slash", steps: [
            "If Today shows Reminders are off, tap Allow notifications or Open settings.",
            "Check that Focus or Do Not Disturb is off, or that it allows Vzato.",
            "Check that the iPhone is not on silent and the volume is up.",
            "In Settings › Sounds you can choose a different sound.",
        ]),
    ]

    var body: some View {
        List {
            Section {
                ForEach(Self.topics) { topic in
                    NavigationLink {
                        TopicView(topic: topic)
                    } label: {
                        Label { Text(topic.title).font(.title3) } icon: { Image(systemName: topic.symbol) }
                            .padding(.vertical, 6)
                    }
                    .accessibilityIdentifier("help-\(topic.id)")
                }
            }
            Section {
                if let guide = Self.webGuideURL {
                    Link(destination: guide) {
                        Label("Guide with pictures on vzato.app", systemImage: "safari")
                    }
                }
                if let mail = URL(string: "mailto:info@vzato.app") {
                    Link(destination: mail) {
                        Label("Write to us: info@vzato.app", systemImage: "envelope")
                    }
                }
            } footer: {
                Text("Vzato is not a medical device. Ask your doctor or pharmacist about your medications.")
            }
        }
        .navigationTitle(Text("Help"))
    }

    /// The guide in the language the app runs in.
    static var webGuideURL: URL? {
        let language = Bundle.main.preferredLocalizations.first ?? "en"
        let code = ["cs", "sk", "hu"].contains(language) ? language : "en"
        return URL(string: "https://vzato.app/\(code)/help/")
    }

    struct TopicView: View {
        let topic: Topic

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Array(topic.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .firstTextBaseline, spacing: 14) {
                            Text(verbatim: "\(index + 1)")
                                .font(.title2.weight(.heavy))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(Palette.taken, in: Circle())
                                .accessibilityHidden(true)
                            Text(step)
                                .font(.title3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: 600, alignment: .leading)
                .padding(24)
            }
            .navigationTitle(Text(topic.title))
        }
    }
}

#Preview {
    NavigationStack { HelpView() }
}
