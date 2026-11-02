---
executor: task-executor
platforms: [android, ios]
workKinds: [flutter, security]
blockedBy: []
securityReview: required
---

# Foundry sheet in a WebView + remove map/D-pad

## Problem

Native rolls (`sheet_dialogs.dart`, `cast_result_sheet.dart`, MidiQOL flow
through the reader) have to replicate many dnd5e/MidiQOL factors by hand.
Foundry is itself a web app: loading it directly in a WebView, logged in as
the player, runs the real sheet and MidiQOL in the real client. The app only
adapts the layout with injected CSS/JS.

The token map and D-pad screens are unused.

## Authoritative facts

- Foundry is reachable from the phone through a public HTTPS URL (user
  confirmed, 2026-11-02). The URL is user configuration, not committed.
- User decisions (2026-11-02): extra tab in `PlayerScreen` (native sheet and
  chat stay); no game canvas for now (`core.noCanvas`), so MidiQOL attacks
  from the WebView have no targets and damage is applied manually; remove
  map and D-pad.
- `widgets/target_picker.dart` uses `FoundryRepository.getMap()`, so
  `getMap`, `FoundryScene` and `FoundryToken` stay.

## Scope

1. `webview_flutter` dependency.
2. `lib/core/network/foundry_url_provider.dart`: persisted Foundry URL
   (pattern of `reader_url_provider.dart`), no default; field in Settings.
3. `assets/foundry_mobile/adapter.{js,css}`: injected after page load. Sets
   `core.noCanvas`, opens the selected actor's sheet full screen, hides the
   rest of Foundry's UI, chat as a toggleable panel. No JS→Dart bridge.
4. `lib/features/player/pages/foundry_sheet_page.dart`: WebView kept alive,
   loads `<foundry>/join`; login happens in Foundry's own form (the app never
   sees or stores the password); navigation restricted to the Foundry origin.
5. `PlayerScreen`: "Map" nav item replaced by "Foundry".
6. Remove `map_screen.dart`, `token_control_screen.dart`,
   `token_controller.dart`, GM "Map" tab, repository `getTokens`/`stepToken`/
   `moveToken`, `StepDirection`.

## Acceptance criteria

- Foundry tab shows a hint when no Foundry URL is configured.
- With a URL, Foundry's join page loads; after login the selected actor's
  sheet opens full screen without the canvas.
- Navigation to other origins is blocked.
- Switching tabs does not reload Foundry.
- No map/D-pad entry points remain; format/analyze/test pass.

## Verification

- `fvm dart format --output=none --set-exit-if-changed .`,
  `fvm flutter analyze`, `fvm flutter test`.
- Unit test for `FoundryUrlController` URL normalization.
- Device checks (login, session persistence, no canvas, sheet layout,
  MidiQOL attack + damage button in Foundry chat, dialogs, blocked external
  navigation, same user also open on a PC) are manual and unverified until a
  human records them.
- Independent `security-reviewer` pass: new remote origin in a WebView,
  Foundry session cookies in the WebView store, injected JS.

## Limitations

- `core.noCanvas` localStorage key and CSS selectors depend on the
  Foundry/dnd5e version; adjust after first device run.
- No canvas ⇒ no targets ⇒ MidiQOL does not auto-apply damage.
- Reader endpoints for token step/move become unused (other repo, untouched).
