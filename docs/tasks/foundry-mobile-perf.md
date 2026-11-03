---
executor: task-executor
platforms: [android, ios]
workKinds: [flutter, integration]
blockedBy: []
securityReview: required
---

# Foundry tab: chat/keyboard responsiveness and centered dialogs

## Problem

On the Foundry tab (see `foundry-mobile-sheet.md`): opening the chat panel
is slow, opening the keyboard lags, and MidiQOL/roll dialogs appear at their
desktop position (bottom center), covered by the floating bubbles.

## Authoritative facts

- User request (2026-11-03). Environment: Foundry v14 (14.369), dnd5e 5.3.3,
  MidiQOL 14.0.19.
- The chat panel was `display: none` while closed, so each open laid out the
  whole chat log; opening also re-ran `expand`/`changeTab` on the sidebar.
- The keyboard resized the WebView (Scaffold `resizeToAvoidBottomInset`),
  and every viewport resize re-lays out Foundry's full-screen UI.

## Scope

1. Chat pre-rendered: the sidebar stays laid out full screen and is hidden
   with `opacity: 0` + `pointer-events: none`; it is expanded on the chat tab
   at `ready`. Opening only flips a class; sidebar calls run only if needed.
2. Keyboard: `PlayerScreen` disables `resizeToAvoidBottomInset` on the
   Foundry tab; `FoundrySheetPage` pushes the keyboard inset as `--ffc-kb`
   (coalesced while the inset animates). The chat panel, sheet body, dialogs
   and the join page reserve that space; focused fields outside the chat
   scroll into view.
3. Dialogs (`.application:not(.sheet)`, `.window-app:not(.sheet)`) centered
   vertically between the notch and the bubbles/keyboard, with a max height.

## Acceptance criteria

- Opening/closing the chat panel is immediate after the first load.
- Opening the keyboard in chat or on a sheet field does not stall; the field
  stays visible above the keyboard.
- Attack/roll dialogs appear centered and not covered by the bubbles.

## Verification

- `fvm dart format --output=none --set-exit-if-changed .`,
  `fvm flutter analyze`, `fvm flutter test`.
- Device checks of all acceptance criteria (Android, iOS): manual,
  unverified until a human records them.

## Limitations

- No profiling was available when this was written (no device attached);
  the causes above are inferred from the implementation, not measured.
- A hidden but laid-out chat keeps updating its layout as messages arrive.
- iOS WKWebView applies its own keyboard avoidance; behavior there is
  unverified.

## Follow-up (2026-11-03): bottom inset and stacked sheets

User report on iOS: the Foundry tab left an empty strip at the bottom, and
opening a container (backpack) left no way back to the character sheet.

- Bottom strip: the WebView sat in `SafeArea(top: false)`, reserving the
  home-indicator inset. It now extends under it (`bottom: false`);
  `FoundrySheetPage` pushes `--ffc-safe-bottom` and the adapter pads the tab
  bar, sheet body, bubbles, chat panel, dialogs and the join page for it.
- Stacked sheets: containers open dnd5e's item sheet, which goes full screen
  like the character sheet, and the adapter hid the close button on every
  sheet. Now only the sheet opened by the adapter (`ffc-main-sheet`) hides
  it.
- Verification: format/analyze/test only. Device check (iOS, Android):
  unverified.

## Follow-up (2026-11-03): app menu in the chat bar and system back

User request: system back should close the stacked sheet first; remove the
bottom-left floating overlay and put its actions (exit, reload, log out) in
the chat panel's top bar with Foundry's menus.

- `FoundrySheetPage` owns the system back while active (`PopScope` moved
  from `PlayerScreen`): `runJavaScriptReturningResult('window.__ffcBack?.()')`
  closes targets panel → chat → top framed non-main window; if nothing was
  closed, exits the tab.
- New trust boundary: `FFoundryCon` `JavaScriptChannel`. Any script on the
  Foundry page can post to it; Dart accepts only `exit`, `reload`, `logout`
  (logout still asks for confirmation) and ignores everything else. No data
  crosses the channel.
- The overlay remains only off `/game` (join page), where there is no chat.
- Verification: format/analyze/test, `node --check` on the adapter. Device
  check (iOS, Android): unverified. Independent security review of the
  channel: pending (`securityReview: required`).

## Follow-up (2026-11-03): reuse the Foundry session

User report: the Foundry tab asks for user and password every time.

- The WebView always loaded `/join` (Foundry's login form) even with a
  live session cookie. It now loads `/game`; without a session Foundry's
  server redirects to `/join`. Logout still loads `/join`.
- Unverified: that Foundry's session cookie persists across app restarts
  in WKWebView (iOS) and Android's WebView. If a cold start still asks for
  login, the cookie is not persisted and needs separate work.

## Follow-up (2026-11-03): toasts, back bubble, chat spacing, long-press

User requests:

- No roll toasts while the Foundry tab is active (`PlayerScreen`); rolls are
  still marked as seen so leaving the tab does not replay them.
- A ← bubble at the right edge (chat and 🎯 shift left) while a closable
  window other than the main sheet is open; it closes the top one (same
  `topWindow()` as the system back).
- Chat panel: no tab bar there, so the bubbles sit 12px from the bottom
  edge and the panel reserves 68px instead of 112px.
- Accidental long-press while scrolling (iOS): the shim cancels on any
  scroll and ignores touches starting within 300ms of one; sheets set
  `user-select: none` (editable fields excluded).
- Verification: format/analyze/test, `node --check`. Device check:
  unverified.

## Follow-up (2026-11-03): slow sheet hide on chat open and on back

User report: with the chat pre-rendered, the sheet still takes long to
disappear when opening the chat, and when going back from a stacked page
to the sheet.

- Back (system back and ← bubble): `close()` on ApplicationV2 animates and
  waits for the closing transition (with a timeout); full-screen windows
  have no running transition, so the close waited. Now
  `close({ animate: false })`.
- Chat toggle: the body class change recalculated style for every chat
  node (`#ui-right *` pointer-events rule) and the whole sheet subtree
  (inherited `visibility`). Now the hidden roots use
  `content-visibility: hidden` (subtree skipped, render state kept) and the
  `*` rule is gone; the root keeps `pointer-events: none`.
- Inferred, not profiled (release WebView is not inspectable). iOS before
  Safari 18 ignores `content-visibility` and falls back to opacity/visibility.
- Verification: `node --check`. Device check: unverified.
