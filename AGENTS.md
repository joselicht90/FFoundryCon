# Engineering contract

This repository is a Flutter companion client for Foundry VTT. It talks to a
user-owned `foundry-data-reader` server (part of a 4-component system, see
`README.md`). Before changing code or engineering documents, read this file
and the relevant document in `docs/engineering/`.

## Product boundary

This app is a client to a user-owned/self-hosted `foundry-data-reader`
server; Foundry VTT itself is the source of truth. Do not implement assumed
reader API shapes, endpoints, or WebSocket event types without an
authoritative contract — `lib/repositories/foundry_repository.dart` and the
`foundry-data-reader` project are the reference. A live GM session (real or
via `foundry-gm-headless`) is required for the reader to serve actor/roll
data; do not build around undocumented reader behavior to work around that.

Treat the reader URL, session/auth data, world/user/actor identifiers, chat
and roll payloads, and raw reader responses as sensitive. Never commit them
or put them in logs, test fixtures, screenshots, review evidence, or error
messages. Use anonymized fixtures in tests.

## Architecture

Follow `docs/engineering/architecture.md`. The dependency direction is:

```text
core -> repositories -> controllers -> features
```

- **`lib/core/`** owns infrastructure: dio client setup, reader URL/session
  plumbing, storage (shared_preferences), logging, notifications, theme.
- **`lib/models/`** are `@JsonSerializable` DTOs — the only place reader JSON
  gets parsed.
- **`lib/repositories/`** owns all HTTP/WebSocket calls to the reader and
  maps responses to models. Nothing above this layer touches `dio` or raw
  JSON directly.
- **`lib/controllers/`** are Riverpod notifiers coordinating app/session
  state and use cases against repositories.
- **`lib/features/`** are screens/widgets. They consume controllers only —
  no direct repository, dio, or JSON-parsing calls from presentation code.

Do not add platform-specific (Android/iOS) native code merely because
platform runners exist. Document any MethodChannel/EventChannel contract in
`docs/engineering/` before its Dart or native implementation changes.

## Work lifecycle

Create a task card under `docs/tasks/` before non-trivial implementation.
Follow `docs/tasks/README.md`; task execution, reviews, and evidence use the
formats described there and in `docs/reviews/README.md`. Preserve historic
task and review records. Do not invent test results, CI runs, device
results, or security-review conclusions.

Use one of these executors: `task-executor`, `code-reviewer`, or
`security-reviewer`. Run an independent security review whenever a change
introduces or changes a trust boundary, credential/session handling,
external input, network transport, storage of sensitive data, or platform
permission.

## Quality and delivery

Run the applicable commands in `docs/engineering/quality-gates.md`. A passed
static check does not prove behavior on a device or against a live reader
server. Record unavailable environments as unverified.

GitHub Actions is the CI target. `.github/workflows/ci.yml` runs the
format/analyze/test quality gate on every push and PR. `.github/workflows/build-apk.yml`
is the separate signed release pipeline (Android + iOS) triggered on push to
`main` — do not alter release signing, the upload keystore, package
identifiers, or that workflow unless a task explicitly authorizes it.

`AGENTS.md` is the authoritative agent contract for this project. If a
generated adapter for another agent runtime is introduced, generate it from
this contract rather than creating a competing source of rules.
