---
executor: task-executor
platforms: [android, ios]
workKinds: [flutter, integration]
blockedBy: []
securityReview: required
---

# Foundry sheet adapted to phone layout

## Problem

The Foundry tab is full screen, but the dnd5e character sheet is a desktop
layout (wide header, sidebar + content, vertical tabs outside the window,
multi-column lists, hover/right-click controls). It must fit a phone without
losing Foundry functionality (rolls, MidiQOL, editing).

## Authoritative facts

- User (2026-11-03): Foundry v14 (14.369) + dnd5e 5.3.3 + MidiQOL 14.0.19 (confirmed on device). Approach: reorganize the real
  DOM (no custom HTML). Selector discovery via WebView remote inspection in
  debug builds.
- ApplicationV2 re-renders by part and replaces part elements, so the adapter
  must not move nodes; classes + CSS only.

## Scope

1. Direct deps `webview_flutter_android`, `webview_flutter_wkwebview`;
   `FoundrySheetPage` enables inspection only in `kDebugMode`.
2. `adapter.js`: `renderApplicationV2` hook marks Actor/Item sheets with
   `ffc-sheet`; sidebar toggle in the window header; iOS long-press →
   `contextmenu` shim.
3. `adapter.css`: one-column sheet, compact header, 3×2 ability grid,
   collapsible sidebar, bottom tab bar, trimmed list columns, always-visible
   item controls, full-width dialog buttons. Chat toggle and Flutter overlay
   moved above the tab bar.

## Acceptance criteria

- Character sheet fits the phone width with no horizontal scroll.
- Bottom tab bar switches tabs; sidebar toggle survives re-renders (HP edit,
  item use).
- Attack/spell with MidiQOL and its dialogs are usable.
- Long-press opens item context menu on Android and iOS.
- Release build is not inspectable.

## Verification

- `fvm dart format --output=none --set-exit-if-changed .`,
  `fvm flutter analyze`, `fvm flutter test`, `fvm flutter build apk --debug`.
- Device checks of all acceptance criteria: manual, unverified until a human
  records them.
- Independent `security-reviewer` pass: debug-only remote inspection of a
  WebView holding a Foundry session.

## Limitations

- Selectors and overridden rules come from dnd5e `release-5.3.3` sources
  (`less/v2/character.less`, `templates/actors/character-*.hbs`,
  `base-actor-sheet.mjs`); other 5.x releases may differ. First device run
  (2026-11-03, before this correction) showed the sheet overflowing: dnd5e's
  `min-width: 800px` and absolutely positioned header/ability scores.
- Inventory column trimming relies on dnd5e's own width-based `hidden-width`.
- The sheet opened is the logged-in Foundry user's assigned character; the
  app-selected actor is used only if that user owns it.
