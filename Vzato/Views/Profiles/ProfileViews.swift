// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

extension EnvironmentValues {
    /// True when there is more than one profile: dose rows, the big card and lists then say whose
    /// dose it is. With a single profile nothing about profiles is shown.
    @Entry var showsProfiles = false
}

/// "🐕 Mentík" above a medication name.
struct ProfileBadge: View {
    let profile: Profile?
    var font: Font = .caption.weight(.semibold)

    var body: some View {
        if let profile {
            Label {
                Text(profile.name)
            } icon: {
                Image(systemName: profile.symbol)
            }
            .font(font)
            .foregroundStyle(Color(hex: profile.colorHex ?? Palette.medicationHexes[3]))
            .lineLimit(1)
        }
    }
}

/// Chips at the top of Today and History: everyone, or one profile.
struct ProfileFilterBar: View {
    let profiles: [Profile]
    @Binding var selection: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: Text("Everyone"), symbol: nil, id: nil)
                ForEach(profiles) { profile in
                    chip(title: Text(profile.name), symbol: profile.symbol, id: profile.id)
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityIdentifier("profileFilter")
    }

    private func chip(title: Text, symbol: String?, id: UUID?) -> some View {
        let on = selection == id
        return Button {
            selection = id
        } label: {
            HStack(spacing: 4) {
                if let symbol { Image(systemName: symbol) }
                title
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(on ? Color.accentColor : Color.secondary.opacity(0.15), in: Capsule())
            .foregroundStyle(on ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

extension Collection where Element == Medication {
    /// Medications of one profile, or all of them when `profileID` is nil.
    func of(profile profileID: UUID?) -> [Medication] {
        guard let profileID else { return Array(self) }
        return filter { $0.profile?.id == profileID }
    }
}
