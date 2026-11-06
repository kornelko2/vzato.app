# Vzato

Free, open source medication reminder for iPhone, iPad and Mac. One SwiftUI code
base, no server, no accounts: your data stays on your devices and in your iCloud.
Czech, Slovak and English.

**Vzato is not a medical device and does not replace your doctor or pharmacist.**
It reminds you and keeps your own notes, nothing more.

## What it does (v1)

- Medications with a weekly schedule and several times per day.
- Local notifications with *Taken* / *Snooze* / *Skip* actions.
- Today screen built around one question: *did I take it already?* One big card
  for the dose that needs attention, the rest of the day as a timeline.
- History with a month calendar, per-day corrections and CSV export.
- Supply tracking: pill count, low-supply warning and notification, projected
  run-out date.
- Supply check: count what you have at home and compare it with what the app
  recorded, to catch doses taken without confirming (or confirmed without taking).

Planned, in order of interest: photos of the package and leaflet, iCloud sync,
widgets, Apple Health, family sharing, profiles for children and pets. See
`specification.md` and `implementation-plan.md` (Czech).

## Building

Requires Xcode 16 or newer and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
cp Config/Local.xcconfig.example Config/Local.xcconfig   # add your team, or leave the placeholder
xcodegen generate
open Vzato.xcodeproj
```

Simulator builds need no Apple developer team. Device builds, TestFlight and
macOS do; set `DEVELOPMENT_TEAM` in `Config/Local.xcconfig` (gitignored).

Command line:

```bash
xcodebuild -project Vzato.xcodeproj -scheme Vzato -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project Vzato.xcodeproj -scheme Vzato -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Debug builds accept `--sample-data` as a launch argument to fill an empty store
with demo medications.

## TestFlight

1. In App Store Connect create the app record once: name *Vzato*, bundle ID
   `app.vzato`, primary language Czech.
2. Make sure `Config/Local.xcconfig` contains your `DEVELOPMENT_TEAM`.
3. In Xcode: Product › Archive (scheme *Vzato*, destination *Any iOS Device*),
   then Distribute App › TestFlight & App Store. Automatic signing registers the
   App ID and creates the profiles.
4. In App Store Connect add yourself (and testers) to the internal group; the
   build appears in the TestFlight app within minutes.

Command line equivalent:

```bash
xcodebuild -project Vzato.xcodeproj -scheme Vzato -destination 'generic/platform=iOS' \
  -archivePath build/Vzato.xcarchive archive
xcodebuild -exportArchive -archivePath build/Vzato.xcarchive \
  -exportOptionsPlist Config/ExportOptions.plist -exportPath build/export
```

## Privacy

No analytics, no ads, no third parties, no server. Everything is stored in the
app's local database and, once sync ships, in the user's private iCloud
database, which the developer cannot access.

## License

[Mozilla Public License 2.0](LICENSE). The name *Vzato* and the app icon are not
covered by the license and may only be used by official builds.
