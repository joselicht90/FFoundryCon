import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/actor_controller.dart';
import '../../controllers/combat_controller.dart';
import '../../controllers/session_controller.dart';
import '../../core/network/image_url.dart';
import '../../core/network/reader_url_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/foundry_actor.dart';
import '../../models/foundry_combat.dart';
import 'widgets/sheet_dialogs.dart';
import 'widgets/sheet_kit.dart';

class CombatScreen extends ConsumerWidget {
  /// embedded = sin Scaffold/AppBar (para usar como pestaña del DM).
  final bool embedded;
  const CombatScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final combat = ref.watch(combatControllerProvider).valueOrNull ??
        const FoundryCombat();
    final actor = ref.watch(actorControllerProvider).valueOrNull;
    final isGM = ref.watch(selectedUserProvider)?.isGM ?? false;

    // Los jugadores no ven combatientes ocultos.
    final list = combat.combatants
        .where((c) => isGM || !c.hidden)
        .toList();
    final myTurn = actor != null && combat.current?.actorId == actor.id;

    final body = !combat.active
        ? _NoCombat(isGM: isGM)
        : ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
            children: [
              // Control de turnos del DM.
              if (isGM) ...[
                _DmTurnControls(round: combat.round),
                const SizedBox(height: 14),
              ],
              if (myTurn) ...[
                _EndTurnButton(actorId: actor.id),
                const SizedBox(height: 14),
              ],
              SectionHeader('Orden de turnos'),
              for (final c in list)
                _CombatantRow(
                  combatant: c,
                  isCurrent: c.id == combat.currentId,
                  isMine: actor != null && c.actorId == actor.id,
                  showHp: isGM || !c.isHostile, // el DM ve PV de todos
                ),
              if (actor != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: SectionHeader('Tus acciones')),
                    TextButton.icon(
                      icon: const Icon(Icons.casino, size: 16),
                      label: const Text('Iniciativa'),
                      onPressed: () => rollAction(
                          context, ref, RollKind.init, 'init', 'Iniciativa',
                          pick: true),
                    ),
                  ],
                ),
                ...[
                  ...actor.items.where((i) => i.hasAttack),
                  ...actor.feats,
                ].map((it) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ActionRow(item: it),
                    )),
                if (actor.items.every((i) => !i.hasAttack) && actor.feats.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Sin acciones de combate',
                        style: TextStyle(color: AppColors.label)),
                  ),
              ],
            ],
          );

    if (embedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: Text(combat.active ? 'Combate · Ronda ${combat.round}' : 'Combate'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(combatControllerProvider.notifier).refresh(),
          ),
        ],
      ),
      body: body,
    );
  }
}

/// Controles de turno del DM: retroceder / avanzar y empezar/terminar combate.
class _DmTurnControls extends ConsumerStatefulWidget {
  final int round;
  const _DmTurnControls({required this.round});

  @override
  ConsumerState<_DmTurnControls> createState() => _DmTurnControlsState();
}

class _DmTurnControlsState extends ConsumerState<_DmTurnControls> {
  bool _busy = false;

  Future<void> _ctl(String dir) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(combatControllerProvider.notifier).control(dir);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo: $e')));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return SheetCard(
      child: Row(
        children: [
          _btn(Icons.skip_previous, 'Anterior', () => _ctl('prev')),
          Expanded(
            child: Column(
              children: [
                Text('Ronda ${widget.round}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.gold)),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
              ],
            ),
          ),
          _btn(Icons.skip_next, 'Siguiente', () => _ctl('next')),
        ],
      ),
    );
  }

  Widget _btn(IconData ic, String tip, VoidCallback onTap) => IconButton(
        tooltip: tip,
        iconSize: 30,
        color: AppColors.gold,
        onPressed: _busy ? null : onTap,
        icon: Icon(ic),
      );
}

/// Botón para terminar el turno propio (solo visible cuando es tu turno).
class _EndTurnButton extends ConsumerStatefulWidget {
  final String actorId;
  const _EndTurnButton({required this.actorId});

  @override
  ConsumerState<_EndTurnButton> createState() => _EndTurnButtonState();
}

class _EndTurnButtonState extends ConsumerState<_EndTurnButton> {
  bool _busy = false;

  Future<void> _end() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(combatControllerProvider.notifier).endTurn(widget.actorId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo terminar el turno: $e')));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.black,
        minimumSize: const Size.fromHeight(48),
      ),
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
          : const Icon(Icons.skip_next),
      onPressed: _busy ? null : _end,
      label: const Text('Terminar mi turno',
          style: TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class _CombatantRow extends ConsumerWidget {
  final Combatant combatant;
  final bool isCurrent;
  final bool isMine;
  final bool showHp;
  const _CombatantRow(
      {required this.combatant,
      required this.isCurrent,
      required this.isMine,
      this.showHp = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ref.watch(readerUrlProvider);
    final c = combatant;
    final url = foundryImageUrl(base, c.img);
    final color = c.isHostile
        ? AppColors.tokenEnemy
        : (c.isFriendly ? AppColors.tokenAlly : const Color(0xFF8A8F98));
    final border = isCurrent ? AppColors.gold : color.withAlpha(50);

    return Opacity(
      opacity: c.defeated ? 0.45 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: isCurrent ? AppColors.gold.withAlpha(22) : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: isCurrent ? 2 : 1),
        ),
        child: Row(
          children: [
            // Iniciativa.
            SizedBox(
              width: 26,
              child: Text(
                c.initiative == null ? '—' : '${c.initiative!.round()}',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isCurrent ? AppColors.gold : AppColors.label),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withAlpha(40),
                image: url != null
                    ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
                    : null,
                border: Border.all(color: color, width: 1.5),
              ),
              alignment: Alignment.center,
              child: url == null
                  ? Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                                color: AppColors.listText)),
                      ),
                      if (isMine) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withAlpha(40),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text('VOS',
                              style: TextStyle(
                                  fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.gold)),
                        ),
                      ],
                    ],
                  ),
                  if (showHp && c.hp != null && c.hp!.max > 0) ...[
                    const SizedBox(height: 5),
                    _HpBar(hp: c.hp!),
                  ],
                ],
              ),
            ),
            if (isCurrent)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.play_arrow, color: AppColors.gold, size: 20),
              ),
            if (c.defeated)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.close, color: AppColors.red, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}

class _HpBar extends StatelessWidget {
  final CombatantHp hp;
  const _HpBar({required this.hp});

  @override
  Widget build(BuildContext context) {
    final pct = hp.max > 0 ? (hp.value / hp.max).clamp(0.0, 1.0) : 0.0;
    final col = pct > 0.5
        ? AppColors.green
        : (pct > 0.25 ? AppColors.orange : AppColors.red);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: Colors.white.withAlpha(18),
              valueColor: AlwaysStoppedAnimation(col),
            ),
          ),
        ),
        const SizedBox(width: 7),
        Text('${hp.value}/${hp.max}',
            style: const TextStyle(fontSize: 10, color: AppColors.label)),
      ],
    );
  }
}

/// Fila de acción en combate: abre la descripción + acciones al tocar.
class _ActionRow extends ConsumerWidget {
  final ActorItem item;
  const _ActionRow({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = [
      if (item.toHit != null) '⚔ ${item.toHit}',
      if (item.damage != null) '🎲 ${item.damage}',
    ].join('   ');

    return SheetCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showActionInfoDialog(context, ref,
            itemId: item.id,
            name: item.name,
            meta: meta,
            description: item.description,
            hasAttack: item.hasAttack,
            hasDamage: item.damage != null,
            canUse: item.canUse,
            needsTargets: item.needsTargets,
            hasResource: item.uses != null,
            activities: item.activities),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.listText)),
                    if (meta.isNotEmpty)
                      Text(meta,
                          style: const TextStyle(fontSize: 11, color: AppColors.label)),
                  ],
                ),
              ),
              if (item.uses != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text('${item.uses!.value}/${item.uses!.max}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.gold)),
                ),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.gold),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoCombat extends StatelessWidget {
  final bool isGM;
  const _NoCombat({this.isGM = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shield_moon_outlined, size: 48, color: AppColors.label),
          const SizedBox(height: 12),
          const Text('No hay combate activo',
              style: TextStyle(color: AppColors.label)),
          const SizedBox(height: 4),
          Text(
              isGM
                  ? 'Iniciá un combate desde Foundry y aparecerá acá'
                  : 'Aparecerá acá cuando el GM inicie uno',
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ),
    );
  }
}
