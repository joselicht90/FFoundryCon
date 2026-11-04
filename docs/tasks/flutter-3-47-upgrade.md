---
executor: task-executor
platforms: [android, ios]
workKinds: [flutter, ios]
blockedBy: []
---

# Upgrade Flutter SDK 3.35.2 -> 3.47.9

## Problem

Flutter 3.35.2 (2025-08-25) predates iOS 26. On an iOS 27.2 physical device
with Xcode 27.2 the debug build launches but stays on a white screen and the
Dart VM Service is never discovered. iOS 26+ tightened RX/RW page protection,
which breaks debug (JIT) on older Flutter versions (see flutter/flutter#170416).
Xcode 27.2 also rejects iOS deployment targets below 15.0.

## Authoritative facts

- Latest stable at time of writing: 3.47.9 (2026-10-29, Flutter releases
  manifest), Dart 3.13.
- Xcode 27.2 supported deployment target range: 15.0 to 27.2.x.

## Scope

- Pin the SDK to 3.47.9 (`.fvmrc`, `.fvm/`).
- Bump `flutter-version` in `.github/workflows/ci.yml` and
  `.github/workflows/build-apk.yml`. This task authorizes only that line in
  `build-apk.yml`; signing, keystore, and package identifiers stay unchanged.
- iOS deployment target 15.0 (Runner project, Podfile, pods).
- Accept the migrations Flutter applies automatically: UIScene lifecycle
  (`Info.plist`, `AppDelegate.swift`), Swift Package Manager plugin
  integration (Xcode project/scheme), `analysis_options.yaml` excludes.
- Fix new deprecations reported by `flutter analyze`.
- Pub dependency versions are not upgraded beyond what `pub get` resolves
  within the existing constraints.

## Acceptance criteria

- format, analyze, and test quality gates pass on 3.47.9.
- `flutter build ios --release --no-codesign` succeeds.
- Debug run on a physical iOS 27.2 device reaches the first screen.

## Verification

- Local: format (0 changed), `flutter analyze` (no issues), `flutter test`
  (5 passed), `flutter build ios --release --no-codesign` (built).
- Unverified: debug run on device, Android build, CI run.

## Limitations

- Raising the minimum iOS version to 15.0 drops devices on iOS 13 and 14.

## Follow-up (2026-11-03): Android toolchain minimums

`flutter run --release` failed: Flutter 3.47.9 requires Gradle ≥ 8.14.0,
AGP ≥ 8.11.1 and Kotlin ≥ 2.2.20. Bumped the Gradle wrapper to 8.14.3, AGP
to 8.11.1 and Kotlin to 2.2.20. Verification: `flutter build apk --release`
succeeds locally. CI and device: unverified.
