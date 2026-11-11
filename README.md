# Vzato

Free, open source medication reminder for iPhone, iPad and Mac. One SwiftUI code
base, no server, no accounts. Your data stays on your devices and in your own
iCloud. Czech, Slovak, English and Hungarian.

<a href="https://apps.apple.com/app/id6831807640"><img src="Docs/app-store/download-on-the-app-store.svg" alt="Download on the App Store" height="50"></a>

Free for iPhone, iPad and Mac. Website, user guide and privacy policy:
[vzato.app](https://vzato.app). Contact: info@vzato.app.

**Vzato is not a medical device and does not replace your doctor or pharmacist.**
It reminds you and keeps your own notes, nothing more. It never suggests doses
and never checks interactions.

*Vzato* means "taken" in Czech. That is the whole idea: one tap to say you took
it, and the certainty that you did not take it twice.

<p align="center">
  <img src="Docs/screenshots/today.png" width="200" alt="Today: one large card for the overdue dose with a big Taken button, the rest of the day as a timeline">
  <img src="Docs/screenshots/history.png" width="200" alt="History: month calendar with a status dot per day and the selected day's doses">
  <img src="Docs/screenshots/medication.png" width="200" alt="Medication detail: schedule, supply with run-out date and the supply check">
  <img src="Docs/screenshots/settings.png" width="200" alt="Settings: language, appearance, reminders">
</p>

## Features

**Today.** One large card for the dose that needs attention: overdue, missed, or
the next one. A big *Vzato* button, snooze and skip. The rest of the day as a
timeline with the time each dose was confirmed.

**Reminders.** Local notifications with *Taken / Snooze / Skip* actions. Works
with the app closed. No push server.

**History.** Month calendar with a status dot per day, per-day corrections
(mark as taken late, skip, reset), monthly adherence, CSV export.

**Supply.** Pill count per medication, automatic decrement on each confirmed
dose, warning and notification when running low, projected run-out date. Doses
can be half or quarter tablets; counts are shown as 10½.

**Supply check.** Count what you have at home and compare it with what the app
recorded. Catches doses you took without confirming, or confirmed without
taking, and can backfill the records.

**Widgets.** *Today* on the home screen, in Notification Centre or on the Mac
desktop: the next dose, its amount and a *Vzato* button that confirms it without
opening the app. *Next dose* on the Lock Screen.

**Extra doses.** Log a painkiller or anything outside the plan; it shows in the
history and lowers the supply.

**No double doses.** One tap confirms a dose only from 30 minutes before its
time; taking the same medication again soon after asks first, and *Undo* is
there for a few seconds.

**Photos.** The package, the pill and the leaflet, with the chosen one on the
Today card.

**Repeat.** On chosen weekdays, or every few days, weeks or months, for example
a deworming tablet once a month.

**Children and animals.** Profiles with a name and icon; Today shows whose dose
it is and can show one profile at a time. Nothing changes with a single profile.

**Medicines database.** Search Czech and Slovak registered medicines offline
and fill in name, strength and unit. For Czech medicines, the official package
leaflet from SÚKL on a tap.

**Meals.** For medications taken before a meal, a "you can eat now" reminder
with its own sound.

**Summary for the doctor.** 7, 30 or 90 days of adherence, missed doses and
supply, as an A4 PDF.

**iCloud.** Sync between your iPhone, iPad and Mac through your private iCloud.

**Easy start.** A first-start guide (allow notifications, first medication in
three steps) and help in Settings, also on [vzato.app](https://vzato.app).

**Languages.** Czech, Slovak, English and Hungarian, following the language you
choose for the app in system settings.

Possible later, not promised: family sharing, hand-over of records by QR code
or encrypted export, veterinary medicines in the database. Apple Health is on hold:
HealthKit lets other apps read medications and doses but not write them
(specification 3.8). Reminders still show on Apple Watch with their buttons. The Czech design
documents have the details: [specification.md](specification.md),
[implementation-plan.md](implementation-plan.md),
[design-options.md](design-options.md).

## Requirements

- iOS 17, iPadOS 17 or macOS 14 and newer.
- Building: Xcode 16 or newer and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

## Building

```bash
brew install xcodegen
cp Config/Local.xcconfig.example Config/Local.xcconfig   # optional: your team and CloudKit switches
xcodegen generate
open Vzato.xcodeproj
```

Simulator builds need no Apple developer team. Device builds, TestFlight and
macOS do: set `DEVELOPMENT_TEAM` in `Config/Local.xcconfig`, which is gitignored
and included by `Config/Defaults.xcconfig` when present.

Command line:

```bash
xcodebuild -project Vzato.xcodeproj -scheme Vzato \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project Vzato.xcodeproj -scheme Vzato \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Debug builds accept the launch argument `--sample-data`, which fills an empty
store with demo medications.

## iCloud sync (optional)

Sync is off in a default build. To enable it for your own team:

1. In `Config/Local.xcconfig` set `VZATO_CLOUDKIT = YES` and
   `VZATO_ENTITLEMENTS_VARIANT = CloudKit`, then `xcodegen generate`.
2. Build once for a device with automatic signing (Xcode, or
   `xcodebuild … -destination 'generic/platform=iOS' -allowProvisioningUpdates build`).
   Automatic signing registers the App ID with iCloud and creates the container
   `iCloud.app.vzato` for your team.
3. Run the app on a device signed into iCloud. In the CloudKit development
   environment the record types are created on first use; the debug launch
   argument `--init-cloudkit-schema` creates them all at once.
4. Before the first TestFlight build, open the container in the
   [CloudKit Console](https://icloud.developer.apple.com/) and *Deploy Schema
   Changes* to Production. TestFlight and App Store builds use the production
   environment and will not sync until the schema is there.

Settings shows the sync state. Data goes only to the user's private iCloud
database.

## TestFlight

1. In App Store Connect create the app record once: name *Vzato*, bundle ID
   `app.vzato`, primary language Czech.
2. Make sure `Config/Local.xcconfig` contains your `DEVELOPMENT_TEAM`.
3. In Xcode: Product › Archive (scheme *Vzato*, destination *Any iOS Device*),
   then Distribute App › TestFlight & App Store. Automatic signing registers
   the App ID and creates the profiles.
4. Add testers to an internal group in App Store Connect; the build appears in
   the TestFlight app within minutes.

Command line equivalent:

```bash
xcodebuild -project Vzato.xcodeproj -scheme Vzato -destination 'generic/platform=iOS' \
  -archivePath build/Vzato.xcarchive archive
xcodebuild -exportArchive -archivePath build/Vzato.xcarchive \
  -exportOptionsPlist Config/ExportOptions.plist -exportPath build/export
```

Without an Xcode account (or when the managed development profile lacks a
capability such as Time Sensitive Notifications), sign the archive manually with
App Store profiles from the developer portal:

```bash
xcodebuild -project Vzato.xcodeproj -scheme Vzato -destination 'generic/platform=iOS' \
  -archivePath build/Vzato.xcarchive CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Apple Distribution" \
  VZATO_APP_PROFILE=<app profile UUID> VZATO_WIDGET_PROFILE=<widget profile UUID> archive
```

## Privacy

No analytics, no ads, no third-party code, no server. Everything is stored in
the app's local database and in the user's private iCloud database, which the
developer cannot access. The only network requests the app
will ever make on its own are to Apple (iCloud) and, on an explicit tap, to the
public medicines databases of the Czech and Slovak state institutes to fetch a
leaflet. The privacy manifest declares no collected data.

## Project layout

```
Vzato/App         app entry, root tabs, Core Data stack, settings keys
Vzato/Models      Core Data model and NSManagedObject subclasses
Vzato/Services    scheduling, dose logging, supply, supply check, notifications, CSV
Vzato/Views       SwiftUI screens, shared by iPhone, iPad and Mac
VzatoWidgets      widget extension (Today, Lock Screen) and the Taken intent
Vzato/Resources   String Catalog (en, cs, sk, hu), assets, privacy manifest
VzatoTests        Swift Testing unit tests
Config            signing (local, gitignored), entitlements, export options
Design/icon       app icon sources (SVG)
Docs/app-store    App Store texts in four languages
Scripts           helper scripts
```

## Free for everyone

Every feature is free for everyone, including the source code. There are no ads,
no accounts and no paid version. I maintain Vzato mainly
for myself, so updates follow what I need, but any comment or idea is welcome:
open an issue or write to info@vzato.app.

If you want to say thanks, you can [buy me a coffee](https://buymeacoffee.com/kornelko).

## Contributing

Issues and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md)
first; it is short. Changes are listed in [CHANGELOG.md](CHANGELOG.md).

## License

[Mozilla Public License 2.0](LICENSE). The name *Vzato* and the app icon are
not covered by the license and may only be used by official builds.

The medicines index (`Vzato/Resources/Medicines.index`, built by
`Scripts/build-medicines-index.py`) comes from open data of the Czech State
Institute for Drug Control, SÚKL ([terms of use](https://opendata.sukl.gov.cz/podminky-uziti-otevrenych-dat)),
and the Slovak ŠÚKL (CC0). Neither institute endorses this app.
