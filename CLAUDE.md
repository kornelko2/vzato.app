# Vzato – instructions for Claude Code

Vzato is a free, open source medication reminder: SwiftUI universal app (iOS 17+,
iPadOS 17+, macOS 14+), Core Data with `NSPersistentCloudKitContainer` (iCloud sync is a
build-time opt-in via `VZATO_CLOUDKIT`, see README), local notifications, Swift 6 strict concurrency, zero dependencies.
Czech, Slovak, English and Hungarian via `Vzato/Resources/Localizable.xcstrings`.

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
cp Config/Local.xcconfig.example Config/Local.xcconfig   # optional, once per clone
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

- **Shared sources.** The `VzatoWidgets` extension compiles `Vzato/Models`, `Vzato/Services`,
  `App/PersistenceController.swift`, `App/AppSettings.swift`, `Views/Shared/Theme.swift` and the
  String Catalog. Never use `UIApplication`/`NSApplication` or app-only types there; app-only code
  goes to `Vzato/App` (e.g. `AppearanceAndIcon.swift`, `WidgetBridge.swift`, `SyncMonitor.swift`).
- **Store location.** `Vzato.sqlite` lives in the App Group `group.app.vzato`. The widget writes with
  transaction author `widget`; the app merges those writes from persistent history
  (`startMergingExternalChanges`) and only the app talks to CloudKit. Never purge persistent history:
  CloudKit export depends on it.

- `Vzato/Models` – `Vzato.xcdatamodeld` (codegen off, current version `Vzato 5`) and
  `NSManagedObject` subclasses `Profile`, `Medication`, `Schedule`, `DoseEvent`, `MedicationPhoto`. Arrays are stored as comma-separated
  strings (`weekdaysRaw`, `minutesRaw`); enums as raw strings with computed accessors.
- `Vzato/Services` – logic without SwiftUI: `DoseScheduler` (expected doses per day,
  merged with recorded events), `DoseLogger` (the only place stock changes because of a
  dose), `StockService`, `ReconciliationService` (supply check), `NotificationService`,
  `CSVExport`, `DoseSummary`, `PhotoStore` (ImageIO only, no UIKit/AppKit).
- `Vzato/App/SyncMonitor.swift` – observes CloudKit container events (last success, last
  error) and reschedules notifications after remote changes. Entitlement variants live in
  `Config/{iOS,macOS}-{Local,CloudKit}.entitlements`, selected by `VZATO_ENTITLEMENTS_VARIANT`.
  Build-setting defaults belong in `Config/Defaults.xcconfig`, never in `project.yml` settings,
  otherwise `Local.xcconfig` cannot override them (project settings beat project xcconfigs).
- `Vzato/App/AppState.swift` – `@Observable` navigation state (section, sheets) shared by the
  root view and the Mac menu commands; present app-wide sheets from `RootView`, not from tabs.
- `Vzato/Views` – SwiftUI, shared by all platforms; platform differences only in small
  `#if os(iOS)` blocks. `Today/` implements design direction C (one big card). `Photos/` holds the photo section,
  viewer and the iOS-only camera/scanner wrappers (`#if os(iOS)`).
- `VzatoTests` – Swift Testing, in-memory store, fixed Europe/Prague calendar, dates
  start on Monday 2 Nov 2026. Use `TestStore` and `SpyNotifier` from `TestSupport.swift`.
- `website/` – static marketing page and privacy policy (cs, sk, en, hu in one file each, no
  JavaScript, no cookies, no external requests). The privacy policy must stay true to the app:
  any change that stores, sends or syncs new data updates `website/privacy.html` in the same change.
- `Docs/app-store/metadata.md` – App Store texts; `Scripts/asc.py metadata` uploads them through the
  App Store Connect API (`ASC_ISSUER_ID` required; the key lives in `~/.appstoreconnect/private_keys`).
- `Design/icon` – icon sources as SVG. E (pill) is the primary icon, F (organizer) the iOS
  alternate icon; `Scripts/render-icons.sh` renders both into the asset catalog (needs
  Inkscape). Never edit the PNGs by hand; change the SVG and re-run the script.

## Conventions

- Core Data model: every attribute optional or with a default, every relationship
  optional with an inverse, no unique constraints, no ordered relationships. TestFlight
  builds have shipped: any schema change = new model version with lightweight migration.
- A scheduled dose has no `DoseEvent` until the user acts. Status for an unrecorded
  slot is derived (pending → missed after the grace period). Never pre-create events.
- Stock changes only in `DoseLogger` (dose taken/reset) and `StockService.setStock`.
- Every user-visible action on a dose or the supply goes through `DoseLogger`, `StockService` or
  `ReconciliationService`, which write an `ActivityEntry`. Never edit or delete log entries, and
  never record a dose by creating `DoseEvent`s directly in app code.
- Duplicate records of one scheduled dose are resolved by `DoseEvent.preferred` (taken wins, then
  earliest intake, earliest write, id). The rule must stay deterministic: every device runs it.
- Only the app migrates the store (`shouldMigrateStoreAutomatically` is off in the widget).
- Services that touch managed objects are `@MainActor`; the notification delegate is
  `nonisolated` and hops to the main actor with plain values (UUID, Int, Date).
- Strings: English literal in code (`Text("Taken")`, `String(localized:)`), `cs`, `sk` and
  `hu` added to the String Catalog in the same change; use `%lld` / `%@` format keys,
  no sentence fragments. Amounts are `Double` and go through `DoseFormatter.amount(_:unit:)`
  ("2 tablets", "20 drops", "½ tablet"); unit words live in `DoseUnit` with plural
  variations in the catalog (`%lld tablets`), fractions as `%@ tablet` / `%@ tablets`. Button copy is "Taken" → cs "Vzato", sk "Vzaté" (neutral form,
  decided by the user; do not change to "Vzal jsem").
- Dates: always `Calendar` arithmetic and `Text(date, style:)` / `FormatStyle`; never
  manual seconds math or hard-coded formats.
- Notification identifiers: `dose|<medicationID>|<weekday|0>|<minutes>`,
  `snooze|…`, `lowstock|<medicationID>`; iOS caps pending requests at 64.
- Czech docs: keep the revision note at the top of `specification.md` current and mark
  decided open questions with strikethrough plus the decision.
