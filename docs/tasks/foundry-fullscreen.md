---
executor: task-executor
platforms: [android, ios]
workKinds: [flutter]
blockedBy: []
---

# Foundry tab full screen

## Problem

The Foundry WebView tab is squeezed between `PlayerScreen`'s header, combat/
offline banners and bottom nav, leaving little room for the real sheet.

## Authoritative facts

- User request (2026-11-03): selecting the Foundry tab goes full screen,
  with only a small overlay to go back. Adapting Foundry's HTML further for
  phones is a later step, out of scope here.

## Scope

- `PlayerScreen`: on the Foundry tab (with an actor loaded) omit header,
  banners and bottom nav; hide system bars (`immersiveSticky`), restore
  `edgeToEdge` on leave/dispose. Keep the `PageView` element stable so the
  kept-alive WebView is not rebuilt. System back returns to the previous tab.
- `FoundrySheetPage`: `onExit` callback; `SafeArea` around the WebView;
  bottom-left pill with back + reload; "Volver" also on the error and
  missing-URL states.
- No change to navigation allowlist, injection or session handling: no trust
  boundary change, no security review.

## Acceptance criteria

- Entering the Foundry tab hides app chrome and system bars; leaving restores
  them.
- The WebView does not reload when entering/leaving the tab.
- Overlay back and Android back return to the last native tab.
- Overlay does not cover the adapter's Chat button.

## Verification

- `dart format`, `flutter analyze`, `flutter test`.
- Device check of the acceptance criteria (Android, iOS).

## Limitations

- iOS has no system back; exit is only via the overlay.
