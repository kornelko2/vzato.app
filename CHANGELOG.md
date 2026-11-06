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
- App icon: pill (default) or weekly organizer, selectable in Settings on
  iPhone and iPad.
- Settings: appearance, snooze length, missed-after grace period, low-supply
  alerts, notification permission.
- Debug launch argument `--sample-data`.
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

### Added (behind a build flag)
- iCloud sync through the user's private CloudKit database, with sync status in
  Settings. Off unless `Config/Local.xcconfig` sets `VZATO_CLOUDKIT = YES`; the
  maintainer's builds have it on.

### Notes
- Storage is Core Data with `NSPersistentCloudKitContainer` (model version 2).

## [0.1.0] - unreleased

First TestFlight build (phase 1 of the implementation plan).
