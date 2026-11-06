# Contributing to Vzato

Thanks for helping. A few rules keep the project small and trustworthy.

## Principles that do not change

- **No server, no accounts, no analytics, no ads, no third-party code.** Data
  stays on the device and in the user's own iCloud. A pull request that adds a
  network dependency, an SDK or a tracking library will not be merged.
- **Not a medical device.** The app reminds and records what the user entered.
  It must not recommend doses, check interactions or interpret health data.
- **Privacy first.** Nothing leaves the device without an explicit user action.
- **Czech, Slovak and English are all first-class.** Every user-facing string
  ships with all three in the same change.

## Workflow

1. Open an issue for anything bigger than a typo, so scope is agreed first.
   The Czech design documents (`specification.md`, `implementation-plan.md`)
   are the source of truth; change them in the same PR when behavior changes.
2. Fork, branch from `main`, keep the PR focused.
3. `xcodegen generate`, build for the iOS simulator and run the tests. New
   logic in `Vzato/Services` needs a test.
4. Add a line to `CHANGELOG.md` under *Unreleased*.
5. Commit messages: short, `type: summary` (feat, fix, docs, test, chore).

## Code rules

- Swift 6 language mode, strict concurrency. Keep SwiftUI out of `Services`.
- Every Swift file starts with the MPL-2.0 header comment.
- Core Data model: every attribute optional or with a default, every
  relationship optional with an inverse, no unique constraints, no ordered
  relationships. Add a new model version for any schema change.
- A scheduled dose has no `DoseEvent` until the user acts. Never pre-create
  events.
- Strings: English literal in code, `cs` and `sk` in
  `Vzato/Resources/Localizable.xcstrings`. Use `%lld` / `%@` keys, never
  concatenated fragments.
- Never commit `Config/Local.xcconfig`, `buildServer.json` or the generated
  `.xcodeproj`.

## License

By contributing you agree that your contribution is licensed under the
[Mozilla Public License 2.0](LICENSE). No CLA is required.
