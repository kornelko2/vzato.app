# Vzato

SwiftUI universal app (iOS 17+, iPadOS 17+, macOS 14+) for medication reminders.
Core Data (`NSPersistentCloudKitContainer`, CloudKit not enabled yet), local
notifications, no dependencies, no server. Czech, Slovak and English through
`Vzato/Resources/Localizable.xcstrings` (English keys, cs + sk translations).

The design documents are in Czech: `specification.md` (what), `implementation-plan.md`
(how and when, phases 1–12), `design-options.md` (name and visual direction C).

## Build

The Xcode project is generated and not committed. `Config/Local.xcconfig` is
gitignored and holds `DEVELOPMENT_TEAM`; copy it from the `.example` first.

```bash
xcodegen generate
xcodebuild -project Vzato.xcodeproj -scheme Vzato -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project Vzato.xcodeproj -scheme Vzato -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Two simulators may share a name; use `-destination 'platform=iOS Simulator,id=<UDID>'`
from `xcrun simctl list devices available` when that happens.

Editor diagnostics (SourceKit-LSP), once per clone and after `xcodegen generate`:

```bash
xcode-build-server config -project Vzato.xcodeproj -scheme Vzato
```

`buildServer.json` is gitignored. If the editor shows "no such module" but
`xcodebuild` succeeds, the editor is wrong, not the code.

## Layout

- `Vzato/Models` – Core Data model `Vzato.xcdatamodeld` (codegen off) and the
  `NSManagedObject` subclasses `Profile`, `Medication`, `Schedule`, `DoseEvent`.
  CloudKit rules apply from day one: optional attributes with defaults, optional
  relationships with inverses, no unique constraints.
- `Vzato/Services` – logic without SwiftUI: `DoseScheduler` (expected doses per
  day, merged with recorded events), `DoseLogger` (the only place stock changes
  because of a dose), `StockService`, `ReconciliationService` (supply check),
  `NotificationService`, `CSVExport`.
- `Vzato/Views` – SwiftUI, shared by all platforms. `Today/` is design direction C.
- `VzatoTests` – Swift Testing with an in-memory store and a fixed Europe/Prague
  calendar; test dates start on Monday 2 Nov 2026.
- `Design/icon` – app icon drafts as SVG; the asset catalog PNGs are rendered from
  the chosen one.

## Conventions

- Every Swift file starts with the MPL-2.0 header comment.
- User-facing strings are English literals; add cs and sk to the String Catalog in
  the same change. Avoid building sentences from fragments; use `%lld` / `%@` keys.
- A scheduled dose has no `DoseEvent` until the user acts; never pre-create events.
- Swift 6 language mode, strict concurrency. Services that touch managed objects
  are `@MainActor`; the notification delegate is `nonisolated` and hops to the main
  actor with plain values.
- Debug builds accept the `--sample-data` launch argument.
