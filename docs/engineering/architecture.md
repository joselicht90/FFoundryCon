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
  `<url>/game`: with a live Foundry session (platform WebView cookie store)
  it enters the world directly; without one Foundry's server redirects to
  `/join`, where the player logs in through Foundry's own form. The app
  never reads or stores the password. The app menu's logout clears those
  cookies and loads `/join` to pick another user.
- **Navigation**: only the Foundry origin (and `about:blank`) is allowed;
  everything else is blocked by the `NavigationDelegate`.
- **Injection**: after every page load the app runs
  `assets/foundry_mobile/adapter.js` wrapped as
  `(() => { const FFC = {actorId, css}; ... })()`. The adapter sets the
  `core.noCanvas` client setting in `localStorage` (reloading `/game` once if
  it was off), injects `adapter.css`, and on `/game` opens the actor's sheet
  full screen with a floating toggle for Foundry's chat sidebar. It is
  idempotent. JS→Dart is limited to the `FFoundryCon` `JavaScriptChannel`,
  which accepts a closed set of commands from the adapter's app menu
  (`exit`, `reload`, `logout`; anything else is ignored), plus the return
  value of Dart's call to `window.__ffcBack()`.
- **Immersive tab**: while the Foundry tab is active `PlayerScreen` drops its
  header, banners and bottom nav and hides the system bars
  (`SystemUiMode.immersiveSticky`). The WebView extends under the notch and
  the home indicator (side insets still respected); their heights are pushed
  as `--ffc-safe-top` / `--ffc-safe-bottom` and the adapter pads for them.
  On `/game` the app actions (back to the app, reload, Foundry log-out) are
  buttons the adapter appends to the chat panel's top tab bar; off `/game`
  (Foundry's join page) a bottom-left overlay offers back + reload. The
  system back is handled by `FoundrySheetPage` while the tab is active: it
  calls `window.__ffcBack()`, which closes, in order, the targets panel, the
  chat panel, or the top framed window other than the main sheet (items,
  containers, dialogs) and returns whether it closed something; otherwise
  the tab exits to the previous one and `edgeToEdge` is restored.
- No canvas means no token targets: MidiQOL attacks from this tab do not
  auto-apply damage. MidiQOL builds an actor token from the prototype with
  `parent: canvas.scene` (null without canvas); the adapter subclasses
  `CONFIG.Token.objectClass` to parent such in-memory tokens to the active
  scene, and `TokenDocument#object` falls back to in-memory tokens (never
  drawn, `_object` untouched so `rendered` stays false). A floating 🎯 button
  (sheet and chat) lists the active scene's visible tokens and toggles
  them in `game.user.targets` (broadcast via `broadcastActivity`), which
  MidiQOL reads as the attack targets. Any own chat message opens the chat panel, where the MidiQOL card
  continues (attack/damage buttons).
- **Mobile sheet layout** (Foundry v14 (14.369) + dnd5e 5.3.3): a `renderApplicationV2`
  hook adds `ffc-sheet` to Actor/Item `DocumentSheetV2` elements on every
  render; `adapter.css` turns them into one column (sidebar collapsed behind a
  window-header toggle, tabs as a fixed bottom bar, secondary list columns
  hidden). Never move Foundry's nodes: ApplicationV2 re-renders by part
  (`data-application-part`) and replaces them; only add classes/CSS and
  own `ffc-*` elements re-created on each render (header portrait, sidebar
  toggle). The sheet opened by the adapter (`ffc-main-sheet`) hides the
  window close button; every other full-screen sheet stacked on it (items,
  containers such as a backpack) keeps it, as its only way back. While such
  a window (or a dialog) is open a ← bubble at the right edge closes the top
  one.
  Scrolling the body collapses the header (`ffc-header-collapsed`);
  Foundry's minimum-resolution notifications are hidden. On iOS a
  long-press shim dispatches `contextmenu` (Android does this natively); it
  ignores touches that start while or right after something scrolls (a tap
  that stops momentum scrolling), and sheets disable native text selection
  outside editable fields. Roll toasts (`PlayerScreen`) are suppressed while
  the Foundry tab is active; rolls are still marked as seen.
- **Responsiveness**: the chat panel stays laid out and is hidden with
  opacity (pre-rendered at `ready`). On the Foundry tab the keyboard does not
  resize the WebView (`resizeToAvoidBottomInset: false`); its height is
  pushed as `--ffc-kb` alongside `--ffc-safe-top`. Non-sheet windows
  (dialogs) are centered between the notch and the bubbles/keyboard.
- **Debug inspection**: in `kDebugMode` only, the WebView is inspectable
  (`chrome://inspect` on Android, Safari Web Inspector on iOS 16.4+) to tune
  the adapter's selectors. Release builds are not inspectable.
- CSS selectors and the `localStorage` key depend on the Foundry/dnd5e
  version; adjust the assets, not Dart code, when they change.
