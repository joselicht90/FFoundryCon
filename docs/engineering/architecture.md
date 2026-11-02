# Architecture

FFoundryCon remains a single Flutter package until a real need establishes a
package boundary. Organize production code by feature while maintaining this
dependency direction:

```text
core -> repositories -> controllers -> features
```

- **`lib/core/`** — infrastructure: `network/` (dio client, reader URL
  provider, reader WebSocket event stream, image URL helpers), `storage/`
  (shared_preferences wrapper), `logging/`, `notifications/`, `theme/`, and
  shared widgets. No feature- or reader-domain logic lives here.
- **`lib/models/`** — `@JsonSerializable` DTOs for reader payloads (actor,
  world, user, token, chat message, roll request/ingest, rule, compendium,
  npc plan). This is the only layer that owns JSON shape knowledge.
- **`lib/repositories/`** — `foundry_repository.dart` is the sole owner of
  HTTP/WebSocket calls to the `foundry-data-reader` server. It returns typed
  models, not raw JSON or `Response` objects, to callers.
- **`lib/controllers/`** — Riverpod `Notifier`/`StateNotifier`s (session,
  connection, actor, chat, combat, token, dm_party, rules) coordinate use
  cases against one or more repositories and hold UI-facing state.
- **`lib/features/`** — screens and widgets (setup, world/user/actor select,
  gm/*, player/*, rules, settings). They read/call controllers via Riverpod
  providers only.

## Rules

- Widgets and screens under `lib/features/` must not import `dio`,
  `web_socket_channel`, or call `foundry_repository` directly, and must not
  parse or construct reader JSON. Route new reader calls through
  `lib/repositories/` and expose them via a controller.
- New reader response shapes get a model in `lib/models/` with
  `@JsonSerializable` + generated `.g.dart` (via `build_runner`), not inline
  `Map<String, dynamic>` handling in controllers or features.
- Controllers depend on repository interfaces/instances and domain models;
  they do not depend on Flutter widgets.
- Platform-specific (Android/iOS) code is an optional implementation detail.
  Document any MethodChannel/EventChannel contract (method/event names,
  payload fields, error codes, threading, supported-platform behavior,
  verification) in `docs/engineering/` before changing native or Dart sides
  of it.

## Foundry WebView adapter

The player's "Foundry" tab (`lib/features/player/pages/foundry_sheet_page.dart`)
loads the real Foundry client — not the reader — so sheets and MidiQOL run
exactly as in a browser. Contract:

- **URL**: `foundryUrlProvider` (`lib/core/network/foundry_url_provider.dart`),
  user-configured in Settings, `https` only, no default. The page loads
  `<url>/join`; the player logs in through Foundry's own form. The app never
  reads or stores the password; the session lives in the platform WebView
  cookie store.
- **Navigation**: only the Foundry origin (and `about:blank`) is allowed;
  everything else is blocked by the `NavigationDelegate`.
- **Injection**: after every page load the app runs
  `assets/foundry_mobile/adapter.js` wrapped as
  `(() => { const FFC = {actorId, css}; ... })()`. The adapter sets the
  `core.noCanvas` client setting in `localStorage` (reloading `/game` once if
  it was off), injects `adapter.css`, and on `/game` opens the actor's sheet
  full screen with a floating toggle for Foundry's chat sidebar. It is
  idempotent and has no JS→Dart channel.
- No canvas means no token targets: MidiQOL attacks from this tab do not
  auto-apply damage.
- CSS selectors and the `localStorage` key depend on the Foundry/dnd5e
  version; adjust the assets, not Dart code, when they change.
