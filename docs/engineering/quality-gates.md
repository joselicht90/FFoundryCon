# Quality gates

Run the checks that apply to a change before requesting review:

```bash
fvm dart format --output=none --set-exit-if-changed .
fvm flutter analyze
fvm flutter test
```

(Drop the `fvm` prefix if not using FVM locally; CI uses a pinned Flutter
version directly.)

Android and iOS are the shipped delivery targets. Run the build gate for any
platform the change touches:

```bash
fvm flutter build apk --debug
fvm flutter build ios --release --no-codesign
```

Model changes (anything under `lib/models/` annotated `@JsonSerializable`)
require regenerating code before the above checks are meaningful:

```bash
fvm dart run build_runner build --delete-conflicting-outputs
```

The committed GitHub Actions workflow (`.github/workflows/ci.yml`) runs
format, analyze, and test on every push and PR. Signed release builds
(Android upload key, iOS unsigned IPA) run separately in
`.github/workflows/build-apk.yml` on push to `main` and are not a dev-time
gate.

Run a real `foundry-data-reader` acceptance check only with the user's
explicit authorization and a user-controlled reader/Foundry instance. Record
it as human or external validation, never as an automated gate. No current
formal gate verifies a real reader connection, live GM session behavior, or
release signing/deployment.
