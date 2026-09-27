---
executor: task-executor
platforms: [android, ios]
workKinds: [flutter]
blockedBy: []
---

# Cast result sheet (attack/damage re-roll without re-consuming resources)

## Problem

Foundry's own chat (MidiQOL) leaves a persistent card after a spell/attack
cast with ATTACK/DAMAGE/REFUND RESOURCE buttons, letting the caster re-roll
attack or damage on the same cast without spending another spell slot. The
app has no equivalent: `castWithTargets()` fires a single `use(action:'use')`
and shows a toast; there is no way to re-roll attack/damage for that same
cast from the app UI.

## Authoritative facts (verified live against reader.r4spi.com, 2026-09-27)

Actor "Helion Vassor" (`2azqlJk7O70BCRGP`), item Scorching Ray
(`ScorchiRay224III`, activity `attackScorcRayII`), level-2 slots at 2/3
before and after both calls below (unchanged):

- `POST /api/actors/:id/use {itemId, activityId, action:'attack',
  targetIds:[]}` → fire-and-forget (`{"status":"ok"}`), does **not** consume
  the spell slot. The result appears afterwards via `GET /api/chat` as a
  system message `"<actor> usó <item>"` plus roll children
  `<id>-midi0` (flavor `Ataque`) and `<id>-midi1` (flavor `Daño`).
- `POST /api/actors/:id/use {itemId, activityId, action:'damage',
  targetIds:[]}` → **synchronous**, returns `{total, formula, dice}`
  directly in the HTTP response; also posts a standalone chat message with
  flavor `"<item> - Damage Roll"`. Does not consume the slot either.

No change to `foundry-data-reader` is needed. `action:'attack'|'damage'` on
`POST /use` already exists and is wired end to end
(`lib/repositories/foundry_repository.dart:85-94,302-330`,
`lib/controllers/actor_controller.dart:71-101`).

## Scope

- New widget `lib/features/player/widgets/cast_result_sheet.dart`:
  `showCastResultSheet(...)` — a non-auto-dismissing bottom sheet with an
  ATAQUE button (`action:'attack'`), a DAÑO button (`action:'damage'`), a
  chronological list of this session's rolls (sourced from
  `chatControllerProvider`, filtered by author + timestamp-since-open +
  roll flavor), and a Cerrar button.
- Edit `castWithTargets` in
  `lib/features/player/widgets/sheet_dialogs.dart` (~line 568-585): when
  `hasAttack == true`, open the new sheet instead of the plain toast after
  the initial `use(action:'use', ...)` call. Non-attack items keep the
  existing toast.

## Out of scope

- REFUND RESOURCE button — no reader endpoint exists for undoing resource
  consumption today.
- Any "spend N from a pool" UI (e.g. Lay on Hands) — unrelated problem.
- Multi-roll-per-activation (e.g. Scorching Ray's 3 rays as one action) —
  this is Foundry item/MidiQOL configuration, not app-side.

## Acceptance criteria

- Casting an item with `hasAttack == true` opens the sheet; the initial
  cast's attack/damage rolls appear in the list once the reader posts them
  to chat.
- Pressing ATAQUE fires a new `action:'attack'` call and a new row appears
  in the list once it lands in chat, with no spell-slot consumption.
- Pressing DAÑO fires `action:'damage'` and a new row appears the same way.
- Cerrar closes the sheet without side effects.
- Non-attack items (`hasAttack == false`) behave exactly as before (toast,
  no sheet).

## Verification method

- `fvm flutter analyze` and `fvm flutter test`.
- Manual end-to-end against the live reader (`reader.r4spi.com`): cast
  Scorching Ray, confirm sheet + rolls, confirm slot count unchanged via
  `GET /api/actors/:id` before/after pressing ATAQUE/DAÑO.

## Limitations

- Verified against the live reader manually (curl) during planning, not
  through an automated integration test — no CI target exercises a live
  reader.
- Smoke-tested via `scripts/run_flutter.sh` (`fvm flutter run -d chrome
  --debug`): app compiles and launches with the new widget wired in, and
  performs a real `GET /api/worlds` (200) against `reader.r4spi.com`. No
  exceptions from `cast_result_sheet.dart`/`sheet_dialogs.dart`. This only
  proves the code compiles/runs, not the actual cast → sheet → re-roll flow
  (Chrome web session has no live Foundry actor session to cast from).
- `macos-debug` profile failed in this environment: `xcodebuild` not
  available (only Xcode CLI tools installed, not full Xcode) — environment
  limitation, unrelated to this change.
- Not verified on a physical Android/iOS device in this session (no
  device/simulator attached — `fvm flutter devices` only found macOS
  desktop and Chrome). Record as unverified until an Android/iOS run
  confirms the actual cast → sheet → ATAQUE/DAÑO flow end to end.

## Dependencies

None — no reader or module changes required.
