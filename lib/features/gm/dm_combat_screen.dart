import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/chat_controller.dart';
import '../../controllers/combat_controller.dart';
import '../../core/network/image_url.dart';
import '../../core/network/reader_url_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/chat_message.dart';
import '../../models/foundry_actor.dart';
import '../../models/foundry_combat.dart';
import '../../models/npc_plan.dart';
import '../../repositories/foundry_repository.dart';
import '../player/widgets/apply_damage_bar.dart';
import '../player/widgets/roll_card.dart';
import '../player/widgets/sheet_dialogs.dart';
import '../player/widgets/sheet_kit.dart';

/// Combate para el DM: control de turnos + orden de iniciativa (con PV de todos)
/// y el detalle del combatiente en acción (o el que elija) — enemigos incluidos.
/// En landscape/tablet muestra master-detail lado a lado.
class DmCombatScreen extends ConsumerStatefulWidget {
  const DmCombatScreen({super.key});

  @override
  ConsumerState<DmCombatScreen> createState() => _DmCombatScreenState();
}

class _DmCombatScreenState extends ConsumerState<DmCombatScreen> {
  // Selección manual; si es null, se sigue al combatiente del turno actual.
  String? _selectedId;
  String? _lastCurrentId;

  @override
  Widget build(BuildContext context) {
    // Si avanza el turno, volvemos a seguir al combatiente en acción.
    ref.listen(combatControllerProvider, (_, next) {
      final cur = next.valueOrNull?.currentId;
      if (cur != _lastCurrentId) {
        _lastCurrentId = cur;
        if (mounted) setState(() => _selectedId = null);
      }
    });

    final combat = ref.watch(combatControllerProvider).valueOrNull ?? const FoundryCombat();
    if (!combat.active) {
      return const Center(
        child: Text('No hay combate activo\nIniciá uno desde Foundry',
            textAlign: TextAlign.center, style: TextStyle(color: AppColors.label)),
      );
    }

    final combatants = combat.combatants;
    final selId = _selectedId ?? combat.currentId;
    final selected = combatants.where((c) => c.id == selId).firstOrNull;

    final master = _MasterPane(
      combat: combat,
      selectedId: selId,
      onSelect: (id) => setState(() => _selectedId = id),
    );
    final detail = selected == null
        ? const Center(child: Text('Elegí un combatiente', style: TextStyle(color: AppColors.label)))
        : _DetailPane(combatant: selected);

    final wide = MediaQuery.of(context).size.width >= 720;
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 5, child: master),
          const VerticalDivider(width: 1, color: Color(0x1FFFFFFF)),
          Expanded(flex: 7, child: detail),
        ],
      );
    }
    // Portrait: control + orden arriba (altura acotada) y el detalle abajo.
    return Column(
      children: [
        SizedBox(height: 260, child: master),
        const Divider(height: 1, color: Color(0x1FFFFFFF)),
        Expanded(child: detail),
      ],
    );
  }
}

/// Panel izquierdo: control de turnos + lista de iniciativa seleccionable.
class _MasterPane extends ConsumerWidget {
  final FoundryCombat combat;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  const _MasterPane(
      {required this.combat, required this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: [
        _TurnControls(round: combat.round),
        const SizedBox(height: 8),
        _AutonomousToggle(value: combat.autonomousNpc),
        const SizedBox(height: 8),
        for (final c in combat.combatants)
          _CombatantTile(
            combatant: c,
            current: c.id == combat.currentId,
            selected: c.id == selectedId,
            onTap: () => onSelect(c.id),
          ),
      ],
    );
  }
}

class _TurnControls extends ConsumerStatefulWidget {
  final int round;
  const _TurnControls({required this.round});

  @override
  ConsumerState<_TurnControls> createState() => _TurnControlsState();
}

class _TurnControlsState extends ConsumerState<_TurnControls> {
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
          IconButton(
            iconSize: 30,
            color: AppColors.gold,
            tooltip: 'Anterior',
            onPressed: _busy ? null : () => _ctl('prev'),
            icon: const Icon(Icons.skip_previous),
          ),
          Expanded(
            child: Center(
              child: _busy
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Ronda ${widget.round}',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.gold)),
            ),
          ),
          IconButton(
            iconSize: 30,
            color: AppColors.gold,
            tooltip: 'Siguiente',
            onPressed: _busy ? null : () => _ctl('next'),
            icon: const Icon(Icons.skip_next),
          ),
        ],
      ),
    );
  }
}

/// Toggle global: si está ON, las acciones de IA se ejecutan sin confirmar.
class _AutonomousToggle extends ConsumerStatefulWidget {
  final bool value;
  const _AutonomousToggle({required this.value});

  @override
  ConsumerState<_AutonomousToggle> createState() => _AutonomousToggleState();
}

class _AutonomousToggleState extends ConsumerState<_AutonomousToggle> {
  late bool _on = widget.value;

  @override
  void didUpdateWidget(covariant _AutonomousToggle old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _on = widget.value;
  }

  Future<void> _toggle(bool v) async {
    setState(() => _on = v);
    try {
      await ref.read(foundryRepositoryProvider).setAutonomousNpc(v);
    } catch (e) {
      if (mounted) {
        setState(() => _on = !v);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.psychology, size: 18, color: AppColors.gold),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('IA autónoma (sin confirmar)',
                style: TextStyle(fontSize: 12.5, color: AppColors.listText)),
          ),
          Switch(
            value: _on,
            activeThumbColor: AppColors.gold,
            onChanged: _toggle,
          ),
        ],
      ),
    );
  }
}

class _CombatantTile extends ConsumerWidget {
  final Combatant combatant;
  final bool current;
  final bool selected;
  final VoidCallback onTap;
  const _CombatantTile(
      {required this.combatant,
      required this.current,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ref.watch(readerUrlProvider);
    final c = combatant;
    final url = foundryImageUrl(base, c.img);
    final color = c.isHostile
        ? AppColors.tokenEnemy
        : (c.isFriendly ? AppColors.tokenAlly : const Color(0xFF8A8F98));
    final hp = c.hp;
    final pct = (hp != null && hp.max > 0) ? (hp.value / hp.max).clamp(0.0, 1.0) : null;

    return Opacity(
      opacity: c.defeated ? 0.45 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold.withAlpha(30) : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: current ? AppColors.gold : (selected ? AppColors.gold.withAlpha(120) : color.withAlpha(50)),
              width: current ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(c.initiative == null ? '—' : '${c.initiative!.round()}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800,
                          color: current ? AppColors.gold : AppColors.label)),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 34, height: 34,
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
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(c.name,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                                    color: AppColors.listText)),
                          ),
                          if (current)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.play_arrow, size: 16, color: AppColors.gold)),
                        ],
                      ),
                      if (pct != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 5,
                                  backgroundColor: Colors.white.withAlpha(18),
                                  valueColor: AlwaysStoppedAnimation(
                                    pct > 0.5 ? AppColors.green : (pct > 0.25 ? AppColors.orange : AppColors.red)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text('${hp!.value}/${hp.max}',
                                style: const TextStyle(fontSize: 10, color: AppColors.label)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Panel derecho: hoja del combatiente (PV, CA, acciones y rasgos).
class _DetailPane extends ConsumerWidget {
  final Combatant combatant;
  const _DetailPane({required this.combatant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(combatantActorProvider(combatant.id));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('No se pudo cargar el combatiente.\n$e',
              textAlign: TextAlign.center, style: const TextStyle(color: AppColors.label)),
        ),
      ),
      data: (actor) => _StatBlock(actor: actor, combatant: combatant),
    );
  }
}

class _StatBlock extends ConsumerWidget {
  final FoundryActor actor;
  final Combatant combatant;
  const _StatBlock({required this.actor, required this.combatant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ref.watch(readerUrlProvider);
    final url = foundryImageUrl(base, combatant.img ?? actor.img);
    // PV en vivo desde la turnera; el resto de la hoja del fetch.
    final hp = combatant.hp;
    final pct = (hp != null && hp.max > 0) ? (hp.value / hp.max).clamp(0.0, 1.0) : null;

    final actions = [
      ...actor.items.where((i) => i.hasAttack),
      ...actor.feats,
    ];

    // Mini-log: tiradas de ESTE combatiente desde que arrancó la ronda.
    final since = ref.watch(combatControllerProvider).valueOrNull?.roundStartedAt ?? 0;
    final chat = ref.watch(chatControllerProvider).valueOrNull ?? const <ChatMessage>[];
    final names = {actor.name, combatant.name};
    final roundLog = chat
        .where((m) => m.isRoll && m.timestamp >= since && names.contains(m.author))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.card,
                image: url != null
                    ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
                    : null,
                border: Border.all(color: AppColors.gold.withAlpha(110)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(actor.name,
                  style: cinzel(18, weight: FontWeight.w600)),
            ),
            _MiniBox(label: 'CA', value: '${actor.ac ?? '—'}'),
          ],
        ),
        if (pct != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 10,
                    backgroundColor: Colors.white.withAlpha(18),
                    valueColor: AlwaysStoppedAnimation(
                      pct > 0.5 ? AppColors.green : (pct > 0.25 ? AppColors.orange : AppColors.red)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('${hp!.value}/${hp.max}${hp.temp > 0 ? ' +${hp.temp}' : ''}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.listText)),
            ],
          ),
        ],
        if (actor.effects.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: [
              for (final e in actor.effects)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withAlpha(28),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.orange.withAlpha(90)),
                  ),
                  child: Text(e.name,
                      style: const TextStyle(fontSize: 10, color: AppColors.orange)),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        _NpcAiButton(combatantId: combatant.id, combatantName: actor.name),
        // Mini-log de lo que hizo este combatiente en la ronda (se resetea
        // cada ronda). Con botones de aplicar daño en cada tirada de daño.
        if (roundLog.isNotEmpty) ...[
          SectionHeader('Esta ronda'),
          for (final m in roundLog)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RoundLogEntry(msg: m),
            ),
        ],
        if (actions.isNotEmpty) ...[
          SectionHeader('Acciones'),
          for (final it in actions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DmActionRow(item: it, ownerId: actor.id),
            ),
        ],
        if (actor.features.isNotEmpty) ...[
          SectionHeader('Rasgos'),
          for (final f in actor.features)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DmActionRow(item: f, ownerId: actor.id),
            ),
        ],
        if (actions.isEmpty && actor.features.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Sin acciones registradas', style: TextStyle(color: AppColors.label)),
          ),
      ],
    );
  }
}

/// Fila de acción/rasgo del combatiente: abre descripción + (para actores
/// vinculados) permite tirar en nombre de ese combatiente.
class _DmActionRow extends ConsumerWidget {
  final ActorItem item;
  final String ownerId;
  const _DmActionRow({required this.item, required this.ownerId});

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
            activities: item.activities,
            ownerId: ownerId),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.listText)),
                    if (meta.isNotEmpty)
                      Text(meta, style: const TextStyle(fontSize: 11, color: AppColors.label)),
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

/// Botón de acción automática (IA) para un combatiente NPC. Pide un plan al
/// módulo; si el modo autónomo está activo lo ejecuta, si no pide confirmación.
class _NpcAiButton extends ConsumerStatefulWidget {
  final String combatantId;
  final String combatantName;
  const _NpcAiButton({required this.combatantId, required this.combatantName});

  @override
  ConsumerState<_NpcAiButton> createState() => _NpcAiButtonState();
}

class _NpcAiButtonState extends ConsumerState<_NpcAiButton> {
  bool _busy = false;

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    final repo = ref.read(foundryRepositoryProvider);
    try {
      final plan = await repo.npcPlan(widget.combatantId);
      if (!mounted) return;
      if (plan.autonomous) {
        await repo.npcExecute(plan.raw);
        _snack('🧠 ${plan.reason}');
      } else {
        final ok = await _confirm(plan);
        if (ok == true) {
          await repo.npcExecute(plan.raw);
          _snack('Acción ejecutada');
        }
      }
    } catch (e) {
      _snack('No se pudo: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<bool?> _confirm(NpcPlan plan) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgAlt,
        title: Row(
          children: [
            const Icon(Icons.psychology, color: AppColors.gold, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('Acción de ${plan.npcName}', style: const TextStyle(fontSize: 16))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan.reason,
                style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.listText)),
            const SizedBox(height: 12),
            _row('Objetivo', plan.targetName),
            _row('Arma', plan.weaponName),
            _row('Distancia', '${plan.distanceFt} ft (alcance ${plan.reachFt} ft)'),
            _row('Estilo', plan.style),
            if (plan.needsMove) _row('Movimiento', 'Se acerca al objetivo'),
            if (!plan.willAttack)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('No llega a atacar este turno, solo avanza.',
                    style: TextStyle(fontSize: 12, color: AppColors.orange)),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold, foregroundColor: Colors.black),
            icon: const Icon(Icons.play_arrow, size: 18),
            onPressed: () => Navigator.pop(ctx, true),
            label: const Text('Ejecutar'),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 88,
                child: Text(k, style: const TextStyle(fontSize: 12, color: AppColors.label))),
            Expanded(
                child: Text(v,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.listText))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.gold.withAlpha(40),
        foregroundColor: AppColors.gold,
        minimumSize: const Size.fromHeight(46),
      ),
      icon: _busy
          ? const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold))
          : const Icon(Icons.psychology),
      onPressed: _busy ? null : _run,
      label: const Text('Decidir acción (IA)',
          style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

/// Entrada del mini-log: la tarjeta de tirada (chica) + si es daño con
/// objetivos, los botones para aplicarlo.
class _RoundLogEntry extends StatelessWidget {
  final ChatMessage msg;
  const _RoundLogEntry({required this.msg});

  @override
  Widget build(BuildContext context) {
    final ad = msg.applyDamage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RollCardView(
          flavor: msg.flavor,
          formula: msg.formula,
          total: msg.total,
          dice: msg.dice,
        ),
        if (ad != null && ad.targets.isNotEmpty) ...[
          const SizedBox(height: 6),
          ApplyDamageBar(apply: ad),
        ],
      ],
    );
  }
}

class _MiniBox extends StatelessWidget {
  final String label;
  final String value;
  const _MiniBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.gold)),
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.label)),
      ],
    );
  }
}
