# KaloCalc for iOS

Port of the Android app (`../mobile_app_calorie_calc`). Native SwiftUI, iOS 17+.

- `KaloCalcCore/` – platform-independent logic (calculator, goals, diary rules, parsers). Builds and tests on Linux:
  `docker run --rm -v "$PWD/KaloCalcCore":/pkg -w /pkg swift:6.0 swift test`
- `KaloCalc/` – the SwiftUI app. Needs a Mac with Xcode.
- `project.yml` – XcodeGen definition. On a Mac: `brew install xcodegen && xcodegen generate`.
- `tools/strings_to_xcstrings.py` – rebuilds `KaloCalc/Resources/Localizable.xcstrings` from the Android `strings.xml` files
  (keys are the Android resource names; `%1$d` → `%1$lld`, `%1$s` → `%1$@`).
