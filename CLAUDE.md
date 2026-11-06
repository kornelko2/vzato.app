# Vzato – instructions for Claude Code

Vzato is a free, open source medication reminder: SwiftUI universal app (iOS 17+,
iPadOS 17+, macOS 14+), Core Data with `NSPersistentCloudKitContainer` (CloudKit not
enabled yet), local notifications, Swift 6 strict concurrency, zero dependencies.
Czech, Slovak and English via `Vzato/Resources/Localizable.xcstrings`.

Design documents are in Czech and are the source of truth: `specification.md` (what),
`implementation-plan.md` (how and when, phases 1–13), `design-options.md` (name and
visual direction C). Public docs in English: `README.md`, `CHANGELOG.md`,
`CONTRIBUTING.md`.

## Hard rules (never break these, even if asked casually)

1. **No server, no accounts, no analytics, no ads, no third-party code or packages.**
   Do not add a Swift package, an SDK, a web request or any telemetry. The only
   network use allowed is Apple (iCloud/CloudKit) and, on an explicit user tap, the
   public SÚKL/ŠÚKL medicines APIs described in the specification.
2. **Not a medical device.** Never add features that recommend doses, check
   interactions or interpret health data. Keep the disclaimer in Settings and README.
3. **Privacy.** Nothing leaves the device without a user action. Data obtained from
   HealthKit must never be written to the CloudKit-synced store. Keep
   `PrivacyInfo.xcprivacy` truthful (`Data Not Collected`).
4. **Secrets and local config stay out of git:** `Config/Local.xcconfig`,
   `buildServer.json`, `*.xcodeproj`, archives. Never put a team ID, API key or
   personal path into tracked files.
5. **Licensing.** MPL-2.0 header on every Swift file. Do not copy code from
   incompatible licenses. The name Vzato and the icon are excluded from the license.
6. **Scope discipline.** If a request changes behavior, update `specification.md`
   and `CHANGELOG.md` in the same change. Do not start optional phases (10–13) or
   widen scope without the user's explicit decision; propose, then wait.
7. **Git.** Commit and push only when the user asks. No AI attribution lines in
   commit messages. Short `type: summary` messages in the existing style.

## Build and test

The Xcode project is generated and not committed.

```bash
cp Config/Local.xcconfig.example Config/Local.xcconfig   # once per clone
xcodegen generate                                        # after project.yml or file-tree changes
xcodebuild -project Vzato.xcodeproj -scheme Vzato -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project Vzato.xcodeproj -scheme Vzato -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

- Two simulators may share a name; use `-destination 'platform=iOS Simulator,id=<UDID>'`
  from `xcrun simctl list devices available`. Some installed simulators lack a runtime;
  prefer a booted one.
- Keep DerivedData outside the repo (`-derivedDataPath` in the scratchpad) and never
  run two `xcodebuild` invocations against the same DerivedData at once.
- Editor diagnostics: `xcode-build-server config -project Vzato.xcodeproj -scheme Vzato`
  once per clone and after `xcodegen generate`. If the editor shows "no such module"
  but `xcodebuild` succeeds, the editor is wrong.
- Debug builds accept `--sample-data` to seed demo medications
  (`xcrun simctl launch <udid> app.vzato --sample-data -AppleLanguages "(cs)"`).
- Before saying a change is done: build succeeds, all tests pass, and new logic in
  `Vzato/Services` has a test.

## Layout

- `Vzato/Models` – `Vzato.xcdatamodeld` (codegen off, current version `Vzato 2`) and
  `NSManagedObject` subclasses `Profile`, `Medication`, `Schedule`, `DoseEvent`, `MedicationPhoto`. Arrays are stored as comma-separated
  strings (`weekdaysRaw`, `minutesRaw`); enums as raw strings with computed accessors.
- `Vzato/Services` – logic without SwiftUI: `DoseScheduler` (expected doses per day,
  merged with recorded events), `DoseLogger` (the only place stock changes because of a
  dose), `StockService`, `ReconciliationService` (supply check), `NotificationService`,
  `CSVExport`, `DoseSummary`, `PhotoStore` (ImageIO only, no UIKit/AppKit).
- `Vzato/App/AppState.swift` – `@Observable` navigation state (section, sheets) shared by the
  root view and the Mac menu commands; present app-wide sheets from `RootView`, not from tabs.
- `Vzato/Views` – SwiftUI, shared by all platforms; platform differences only in small
  `#if os(iOS)` blocks. `Today/` implements design direction C (one big card). `Photos/` holds the photo section,
  viewer and the iOS-only camera/scanner wrappers (`#if os(iOS)`).
- `VzatoTests` – Swift Testing, in-memory store, fixed Europe/Prague calendar, dates
  start on Monday 2 Nov 2026. Use `TestStore` and `SpyNotifier` from `TestSupport.swift`.
- `Design/icon` – icon drafts as SVG (final icon pending; the asset catalog holds a
  placeholder rendered by `Scripts/make-app-icon.swift`).

## Conventions

- Core Data model: every attribute optional or with a default, every relationship
  optional with an inverse, no unique constraints, no ordered relationships. Any schema
  change = new model version (`Vzato 2.xcdatamodel`), lightweight migration.
- A scheduled dose has no `DoseEvent` until the user acts. Status for an unrecorded
  slot is derived (pending → missed after the grace period). Never pre-create events.
- Stock changes only in `DoseLogger` (dose taken/reset) and `StockService.setStock`.
- Services that touch managed objects are `@MainActor`; the notification delegate is
  `nonisolated` and hops to the main actor with plain values (UUID, Int, Date).
- Strings: English literal in code (`Text("Taken")`, `String(localized:)`), `cs` and
  `sk` added to the String Catalog in the same change; use `%lld` / `%@` format keys,
  no sentence fragments. Button copy is "Taken" → cs "Vzato", sk "Vzaté" (neutral form,
  decided by the user; do not change to "Vzal jsem").
- Dates: always `Calendar` arithmetic and `Text(date, style:)` / `FormatStyle`; never
  manual seconds math or hard-coded formats.
- Notification identifiers: `dose|<medicationID>|<weekday|0>|<minutes>`,
  `snooze|…`, `lowstock|<medicationID>`; iOS caps pending requests at 64.
- Czech docs: keep the revision note at the top of `specification.md` current and mark
  decided open questions with strikethrough plus the decision.
