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
- Czech, Slovak and English.
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

### Notes
- Storage is Core Data with `NSPersistentCloudKitContainer` (model version 2);
  iCloud sync is not enabled yet.
- The app icon is a placeholder; the final design is pending.

## [0.1.0] - unreleased

First TestFlight build (phase 1 of the implementation plan).
