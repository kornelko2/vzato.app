# Changelog

All notable changes to Vzato are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Medications with a weekly schedule, several times per day, meal relation,
  start and end dates, color and notes.
- Today screen with one large card for the dose that needs attention (overdue,
  missed or next), big *Vzato* button, snooze and skip, and a timeline of the
  whole day.
- Local notifications with *Taken / Snooze / Skip* actions.
- History: month calendar with per-day status, per-day corrections, monthly
  adherence, CSV export.
- Supply tracking: pill count, automatic decrement, low-supply warning and
  notification, projected run-out date.
- Supply check: compare the recorded doses with a physical count and backfill
  missing records.
- Extra doses outside the plan.
- Czech, Slovak, English and Hungarian.
- Dose units per medication (tablets, capsules, drops, ml, teaspoons, puffs,
  sachets, injections, pieces) with correct plurals in all languages; the amount
  to take ("2 tablets", "20 drops", "½ tablet") is shown on the Today card, in
  the timeline and in the reminder text.
- Doses in half or quarter tablets; supply counts can be fractional and are
  shown as 10½.
- App icon: pill (default) or weekly organizer, selectable in Settings. iPhone
  and iPad change the home-screen icon, the Mac changes its Dock icon.
- Settings: appearance, snooze length, missed-after grace period, low-supply
  alerts, notification permission.
- Widgets: *Today* on the home screen (iPhone, iPad) and in Notification Centre
  or on the desktop (Mac) with the next dose and a *Vzato* button; *Next dose*
  on the Lock Screen. The database moved into the App Group container so the
  widget can read it; existing data is moved once on first launch.
- Duplicate doses recorded on two devices before they synced are merged by one
  rule that every device applies the same way: *taken* always wins, then the
  earliest intake. The screen shows only the winning record even before the merge.
- Activity log (Settings › Activity log, CSV export): every taken, skipped,
  reset or extra dose, every supply count and supply check, and every automatic
  merge, with time, device and source. Entries are never edited and sync.
- The widget no longer migrates the database itself; after an update only the
  app upgrades it, which avoids a crash when both open the old file at once.
- "You can eat now": for medications taken before a meal, a reminder after a
  configurable waiting time (default 30 minutes) once the dose is confirmed, and
  an "Eat from 7:05" countdown on the Today screen. Model version 4.
- Own notification sounds: six attention-getting sounds for medication reminders and
  six gentle ones for "you can eat now", selectable in Settings › Sounds with a
  preview (choosing a sound plays it). The
  sounds are synthesized by `Scripts/make-sounds.py`.
- Fixed: amounts typed in the supply check and in "Amount at home" were ignored,
  because the number pad has no Return key; they now count on every keystroke and
  accept a decimal comma (10,5).
- App Store screenshots from the simulator and the Mac in four languages
  (`Scripts/screenshots.sh`, `Scripts/screenshots-mac.sh`, `asc.py screenshots`); demo
  data goes to a throwaway store (`--scratch-store`, Debug only).
- Settings › Free for everyone: every feature and the source code are free, the
  author maintains Vzato mainly for himself, feedback to info@vzato.app. A Buy Me a
  Coffee link is on the website and in the repository, not in the app (App Store rules).
- First-start guide for people who do not use phones much: welcome, allow
  notifications (with the reason), then the first medication in three steps (name,
  how much, when) and a summary. Shown only when there is no medication yet; every
  step can be skipped; Settings › Help › Show the introduction again.
- Help in Settings: eight short how-tos in numbered steps, offline, with a link to
  the guide with pictures on vzato.app and the contact info@vzato.app.
- Fixed: reminders never arrived (no sound, nothing on the lock screen) because
  the app asked for notification permission only from a button in Settings. It now
  asks as soon as a medication has a time, and Today shows a red warning with
  *Allow notifications* / *Open settings* while reminders are off. Reminder
  rebuilds run one after another.
- Choose which photo the Today card shows for each medication: pill (default),
  package or none (Medication › Photos › Photo on Today). Model version 5.
- Doses scheduled before a medication was added no longer count as missed (Today,
  History, summary, supply check), unless recorded.
- Summary for the doctor (History › Summary for the doctor): medications with dose
  and plan, taken / missed / skipped / extra doses and adherence for 7, 30 or 90
  days, current supply and run-out date, list of missed doses; exported as an A4
  PDF to send or print.
- Double-dose protection: only a due dose (from 30 minutes before its time) can be
  confirmed with one tap; later doses show only their time, no button (taking one
  early is possible by touching and holding its row in the timeline, with a question); taking
  the same medication again soon after asks "already taken at 7:25" (card,
  timeline, extra dose, widget); an Undo appears for a few seconds after Taken.
- The list of medications shows the amount at home and the get-more-by date.
- Fixed: typing over an amount appended to it (79 over 30 became 7930). Tapping an
  amount now clears it for the new entry; the number pad has a Done key.
- Fixed: "Add time" could create a duplicate time; it now suggests morning, noon,
  evening, night.
- Medication detail shows *Get more by*, a week before the supply runs out.
- The supply check shows the result directly under the count.
- UI test in the simulator for the supply flow (`VzatoUITests`).
- Empty Medications and Today screens offer a large *Add medication* button.
- Debug launch arguments `--sample-data`, `--tab`, `--open-medication <name>`, `--edit`.
- Follow-up reminders for unconfirmed doses (default twice, 10 minutes apart),
  cancelled when the dose is confirmed or skipped.
- Early warning a configurable number of days before the supply runs out.
- Photos of the package, the pill and the leaflet (several pages): camera and
  document scanner on iPhone and iPad, photo library and file import everywhere,
  zoomable viewer, pill thumbnail on the Today card. Photos are downscaled to
  2000 px and stored with the medication.
- iPad and Mac layout: sidebar split view on wide screens, tabs on the iPhone.
  On the Mac: Settings window, menu commands (New medication ⌘N, Log extra dose
  ⇧⌘N, Go ⌘1–⌘3) and Return to confirm the featured dose.
- Unit tests for the scheduler, dose logging, supply, supply check, summaries,
  photo store and CSV.
- Skip button next to Taken in the Today widget.

### Fixed
- The app could be closed by iOS a moment after leaving it, while iCloud was still
  saving the last change (crash report 0xdead10cc). It now asks for a few seconds
  in the background until the sync step finishes.

### Added (behind a build flag)
- iCloud sync through the user's private CloudKit database, with sync status in
  Settings. Off unless `Config/Local.xcconfig` sets `VZATO_CLOUDKIT = YES`; the
  maintainer's builds have it on.

### Notes
- Storage is Core Data with `NSPersistentCloudKitContainer` (model version 2).

## [1.0] - unreleased

First TestFlight build.
