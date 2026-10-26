# KaloCalc for iOS

Native SwiftUI port of the Android app in `../mobile_app_calorie_calc` ("exactly the same, for iOS"). Calorie and macro
diary with food search (Open Food Facts), barcode scanning, photo estimation (Apple Vision labels, optional Google Gemini
key), goals and a calorie calculator, weight and calorie charts. English, Bulgarian, German, French, Spanish. iOS 17+,
iPhone only. Bundle id `com.nikikabadzhov.kalocalc`. The repo is public on GitHub (`nikikab/mobile_app_calorie_calc_ios`) and
all rights are reserved (`LICENSE`).

The Android app is the reference for behaviour. When something is unclear, read the Kotlin and match it; the string keys,
the `SharedPreferences`/DataStore key names and the calculation rules were all carried over on purpose.

## Working environment (important)

Development happens in WSL/Linux. There is **no Xcode and no Mac**. So:

- Logic that does not need Apple frameworks lives in the Swift package `KaloCalcCore` and is tested on Linux in Docker.
- Everything that needs UIKit/SwiftUI/SwiftData/Vision/Keychain is compiled, tested and screenshotted by **GitHub Actions on
  macOS**. A change to app code is only verified once CI is green. Push, then watch the run.
- Nothing has been run on a real iPhone by this project's tooling. Camera, barcode scanner, Vision on a real photo, and
  real Gemini/Open Food Facts calls are untested. Touch behaviour is untested; only layout is seen through screenshots.

Commands:

```
# core tests (118+)
cd KaloCalcCore && docker run --rm -v "$PWD":/pkg -w /pkg swift:6.0 swift test

# wait for CI, then fetch screenshots
gh run list --limit 3
timeout 560 bash -c "until [ \"\$(gh run view $ID --json status -q .status)\" = completed ]; do sleep 15; done"
gh run download $ID -n screenshots -D <dir>        # also: -n KaloCalc-ipa
```

Foreground `sleep` chains are blocked in this environment; use the `until` loop with `timeout` shown above.
To find a Swift compile error in a failed run: `gh run view $ID --log | grep -iE "error|Cannot find|has no member"`
(`--log-failed` often omits the compiler line).

## Architecture

```
KaloCalcCore/          Swift package, Foundation only, iOS 17 / macOS 13, tested on Linux
KaloCalc/              the app (generated into KaloCalc.xcodeproj by XcodeGen; the .xcodeproj is gitignored)
  App/                 KaloCalcApp, AppModel (composition root), RootView (4 tabs), DemoData
  Data/                SwiftData schema + migration plan, Repository, UserDefaults/Keychain stores
  Food/                URLSession transport, error messages, Vision recognizer, FoodServices
  Support/             AppStrings (localization lookup), PhotoStore
  UI/{Common,Diary,Goal,Search,Progress,Settings}
  Resources/           Localizable.xcstrings (generated), InfoPlist.xcstrings, assets, app icon
KaloCalcTests/         XCTest unit tests for the app target (run in CI on the simulator)
project.yml            XcodeGen definition
tools/                 string-catalog generator, icon and screenshot tooling
.github/workflows/     ci.yml (every push), testflight.yml (manual)
```

### Core package (`KaloCalcCore`)

Pure logic, no UI: `Calculator` (Mifflin-St Jeor, activity, goals, macro splits), `GoalPlan`/`resolveTargets`, `Diary`
(entries, epoch days), `DaySummary`, `Input` (decimal parsing, entry and profile validation), `Portion`, `EstimateEditor`
(recomputes an estimate when grams or an ingredient change), `FoodSearch` (French fallback through Gemini translation),
`OpenFoodFacts` + `Gemini` parsers, `OpenFoodFactsClient` + `GeminiClient`, `Stores` (profile/settings over the
`KeyValueStore`/`SecretStore` protocols), `Progress`, `ActivityAdjustment` (ready, not yet wired to anything).

Network access goes through the `HTTPTransport` protocol. Tests use a fake; the app uses `URLSessionTransport`.

### App

- `@Observable` view models, one per screen, created from `AppModel`. `AppModel` owns the SwiftData container, the
  `Repository`, `ProfileStore`, `SettingsStore`, `PhotoStore` and the current `language`.
- **SwiftData** (`Schema.swift`): five `@Model` records (food entry, weight, goal plan, day target, favorite) in a versioned
  schema `KaloSchemaV1` with a `KaloMigrationPlan`. Ids are **our own monotonic Int64**, handed out by counters in
  UserDefaults, not SwiftData's persistent ids. This keeps ids stable across a future backup/restore and matches Android
  (`clientRecordId(entryId:)` = `kalocalc-<id>` for Health sync). Change the schema only through a new version + migration.
- **Profile and settings** are in UserDefaults, with Android's key names. The **Gemini key is in the Keychain**
  (`WhenUnlockedThisDeviceOnly`), never in UserDefaults.
- **Photos**: `PhotoStore` keeps a pending file in Caches until the entry is saved, then moves it to Documents/photos.
  Entries store only the file **name**, never a path (the app container path changes between installs).
- **Localization**: strings come from `Localizable.xcstrings`, which is **generated** by `tools/strings_to_xcstrings.py` from
  the Android `strings.xml` files plus `tools/ios_strings.json` (iOS-only strings). Keys are the Android resource names;
  `%1$d`→`%1$lld`, `%1$s`→`%1$@`, flags such as `%1$+d` are kept. Never hand-edit the catalog; edit the sources and re-run.
  Code uses `tr("key", args...)` / `AppStrings.text`. The language picker in Settings calls `AppStrings.use(_:)`, which
  swaps the lookup bundle, and `RootView` sets `\.locale` and `.id(language)` so every screen redraws.
- **Demo mode**: launch with `-demo` for in-memory sample data (`DemoData.swift`). `-tab diary|progress|goal|settings` and
  `-sheet <name>` open a tab and dialog. CI screenshots use this. In demo mode the simulator's disabled camera button is
  shown enabled (cosmetic, screenshots only).

## Decisions taken (and why)

- **Native SwiftUI, iOS 17+**, not Flutter/KMP: the user asked for a native port; iOS 17 gives `@Observable`, SwiftData and
  Swift Charts without dependencies. iOS 9.3.5 devices cannot be supported (answered earlier).
- **Logic in a Linux-testable package** because there is no Mac. It also makes the Kotlin-vs-Swift behaviour comparable
  test by test. `roundHalfUp` mimics Kotlin `roundToInt`/`Math.round` (halves go up, also for negatives).
- **Public GitHub repo** to use the free CI quota; can be made private later.
- **No third-party dependencies** in the app.
- **Keychain for the API key**, key sent in an `x-goog-api-key` header, never in a URL.
- **Gemini is optional.** Without a key photos give Vision labels only. With a key, photos are sent to Google; Settings
  says so.
- **Vision** `VNClassifyImageRequest`, confidence >= 0.3, errors give no labels (not a failure).
- **Backup ZIP is deferred** by the user ("оставяме за по-късно"). The Android app has export/import; iOS does not yet.
- **App icon** reuses the Android artwork, drawn by `tools/make_icon.py` (pycairo) into a 1024x1024 opaque PNG.
- **Build number** comes from the GitHub run number; `CFBundleVersion`/`CFBundleShortVersionString` take their values from
  build settings (an earlier fixed value made TestFlight show build 1 every time).
- **Signing**: no local certificates. `testflight.yml` archives **unsigned** and signs during `-exportArchive` with
  automatic cloud signing through an App Store Connect API key (archiving with signing failed: it wanted a *development*
  profile, which needs a registered device).
- **Screenshots** are taken on a Pro Max simulator (1320x2868, the 6.9-inch size); `tools/store_shots.py` adds the teal
  gradient, a caption and a frame for the App Store.
- User preferences seen so far: refused `chmod 666 /var/run/docker.sock` (user was added to the `docker` group instead);
  wants to see screenshots from CI; communicates in Bulgarian.

## CI and release

- `ci.yml` (every push): `core-linux` (swift:6.0 container, `swift test`), `app-ios` (macOS: XcodeGen, `xcodebuild test`,
  simulator screenshots in en and bg, uploaded as artifact `screenshots`), `ipa` (unsigned device `.ipa`, artifact
  `KaloCalc-ipa`, for BrowserStack/AltStore/Sideloadly, which re-sign it; it cannot go to App Store Connect).
- `testflight.yml` (manual, "Run workflow"): archive, sign, upload to App Store Connect. Repository secrets it needs:
  `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (the whole .p8), `APPLE_TEAM_ID`. They are set; never commit them. The API
  key role must be Admin (cloud signing creates certificates). If the key is lost the .p8 cannot be re-downloaded: create
  a new key and update the secrets.
- Capabilities such as HealthKit need to be enabled on the App ID at developer.apple.com and in the project; the automatic
  signing then regenerates the profile.

## App Store submission: status

Known from the work done in this repo (App Store Connect itself cannot be inspected from here, so check it before relying
on this):

- Apple Developer Program account: enrolled by the user (individual).
- App record created in App Store Connect: name `KaloCalc` (fallbacks if taken: "KaloCalc: Calorie Counter",
  "KaloCalc – Food Diary"), bundle id `com.nikikabadzhov.kalocalc`, SKU `kalocalc-ios-001`, primary language English (U.S.),
  user access Full.
- Several builds have been uploaded to TestFlight by `testflight.yml` (20, 21 and 23 Oct 2026). The first was submitted for
  Beta App Review and showed "Waiting for Review" (this concerns external testers only; internal testers need no review).
  Internal testing works by adding people as users in Users and Access, then to an Internal Testing group.
- Beta App Description and "What to Test" text were written (see the chat history; short feature list, known gaps, privacy
  notes).
- Product page text drafted: subtitle "Snap food, count calories" (en) / "Снимай храната, брой калории" (bg), promotional
  text, keywords (<= 100 chars), description, "What's New: First release."
- Screenshots: 12 files (6 en, 6 bg) at 1320x2868 produced by `tools/store_shots.py`; kept outside the repo. Regenerate with
  CI screenshots + `python3 tools/store_shots.py <screenshots> <out>` (needs pycairo; font DejaVu Sans).
- Not yet seen as done: Privacy Policy URL, Support URL, App Privacy answers, age rating, App Review information, the
  "Header" creative on the product page (size unknown, ask the user for the dialog's stated dimensions), selecting a build for
  the release version, and submitting for review.

For the App Privacy answers: the developer collects nothing. The only transfer is photos to Google, and only if the user
sets their own Gemini key; this must be stated in the privacy policy. Food search queries go to Open Food Facts.
`ITSAppUsesNonExemptEncryption` is false in `project.yml`.

## What remains

Roughly in order of value:

1. **Test on a real iPhone** through TestFlight: camera, barcode and QR scanning, Vision on real photos, Gemini with a real
   key, keyboard behaviour, language switch, Progress charts. Fix what breaks.
2. **Finish the submission**: privacy policy page (GitHub Pages on this repo is the simplest), support URL, App Privacy,
   age rating, header image, pick a build, submit. Decide whether external testers are wanted (Beta App Review) or only
   internal.
3. **HealthKit** (parity with Android Health Connect): write each diary entry as nutrition samples with a fixed id, a
   "sync past entries" action, and the optional activity adjustment that reads active energy/steps and feeds
   `ActivityAdjustment.swift` (already in core with tests). Needs the HealthKit capability on the App ID, an
   `NSHealthShareUsageDescription`/`NSHealthUpdateUsageDescription`, and two switches in Settings. The simulator has Health,
   so writing can be tested in CI; real behaviour needs a phone.
4. **Backup ZIP** export/import (diary, weights, profile, photos; Gemini key excluded), deferred by the user. The Android
   `Backup.kt` defines the format; keep it compatible if cross-platform restore is wanted.
5. **Polish**: delete a weight entry (Android has the DAO call but no UI), favourites with photos, a dark/tinted app icon
   variant, iPad support (currently `TARGETED_DEVICE_FAMILY: "1"`), accessibility pass, Dynamic Type check, German/French/
   Spanish screenshots (only en and bg are produced).
6. Bump `MARKETING_VERSION` in `project.yml` for each App Store release; the build number is automatic.

## Conventions

- Match the surrounding code: small files, comments only for the non-obvious why, same naming as the Android code where
  it has an equivalent.
- Every behaviour carried over from Kotlin gets a test in `KaloCalcCore` when it can be expressed without Apple frameworks.
- Numbers shown to the user are formatted with `Text(verbatim:)` or an explicit locale (the app language may differ from
  the system locale).
- Don't push secrets, `.p8` files or personal data. The user's email must not appear in the repo.
