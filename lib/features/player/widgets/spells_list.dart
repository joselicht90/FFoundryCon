import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/actor_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/foundry_actor.dart';
import 'sheet_dialogs.dart';
import 'sheet_kit.dart';

class SpellsList extends ConsumerStatefulWidget {
  final FoundryActor actor;
  const SpellsList({super.key, required this.actor});

  @override
  ConsumerState<SpellsList> createState() => _SpellsListState();
}

class _SpellsListState extends ConsumerState<SpellsList> {
  String _q = '';
  // Secciones colapsadas (por título). "No preparados" arranca cerrada.
  final Set<String> _closed = {'No preparados'};

  /// Header de sección colapsable (Preparados / No preparados).
  Widget _section(String title, int count, bool open, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 16, 2, 9),
        child: Row(
          children: [
            Icon(open ? Icons.expand_more : Icons.chevron_right,
                size: 18, color: AppColors.gold),
            const SizedBox(width: 4),
            Text(title.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.6,
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Expanded(
                child: Container(height: 1, color: AppColors.gold.withAlpha(40))),
            const SizedBox(width: 8),
            Text('$count',
                style: const TextStyle(fontSize: 11, color: AppColors.label)),
          ],
        ),
      ),
    );
  }

  /// Conjuro "disponible": truco, preparado, o de modo siempre disponible
  /// (innate/pact/atwill/always). El resto (modo prepared sin preparar) va a
  /// la sección "No preparados".
  bool _avail(ActorSpell s) => s.isCantrip || s.prepared || s.mode != 'prepared';

  /// Construye los grupos por nivel (header + card) para una lista de conjuros.
  List<Widget> _byLevel(List<ActorSpell> list, {bool slots = false}) {
    final map = <int, List<ActorSpell>>{};
    for (final s in list) {
      (map[s.level] ??= []).add(s);
    }
    final levels = map.keys.toList()..sort();
    final out = <Widget>[];
    for (final level in levels) {
      final spells = map[level]!..sort((a, b) => a.name.compareTo(b.name));
      final slot = slots ? widget.actor.slotForLevel(level) : null;
      final title = level == 0 ? 'Cantrips' : 'Nivel $level';
      final slotStr = slot != null ? '${slot.value}/${slot.max} slots' : null;
      out.add(_LevelHeader(title: title, slots: slotStr));
      out.add(SheetCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (int i = 0; i < spells.length; i++)
              _SpellRow(spell: spells[i], last: i == spells.length - 1),
          ],
        ),
      ));
      out.add(const SizedBox(height: 14));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final actor = widget.actor;
    if (actor.spells.isEmpty) return const _Empty();

    final q = _q.trim().toLowerCase();
    final spells = q.isEmpty
        ? actor.spells
        : actor.spells.where((s) => s.name.toLowerCase().contains(q)).toList();

    // La clase "prepara" si hay algún conjuro de nivel sin preparar.
    final prepares = actor.spells
        .any((s) => !s.isCantrip && !s.prepared && s.mode == 'prepared');

    final children = <Widget>[
      if (actor.spellSlots.isNotEmpty) ...[
        _SlotsOverview(slots: actor.spellSlots),
        const SizedBox(height: 14),
      ],
      SheetSearchField(
        hint: 'Buscar conjuro…',
        onChanged: (v) => setState(() => _q = v),
      ),
      const SizedBox(height: 14),
    ];

    // Agrega una sección colapsable (si la lista no está vacía).
    void addSection(String title, List<ActorSpell> list, {bool slots = false}) {
      if (list.isEmpty) return;
      final open = !_closed.contains(title);
      children.add(_section(title, list.length, open, () {
        setState(() => open ? _closed.add(title) : _closed.remove(title));
      }));
      if (open) children.addAll(_byLevel(list, slots: slots));
    }

    final atwill = spells.where((s) => s.mode == 'atwill').toList();
    final innate = spells.where((s) => s.mode == 'innate').toList();
    final pact = spells.where((s) => s.mode == 'pact').toList();
    // Grimorio normal: modos prepared/always (+ cantrips).
    final book = spells
        .where((s) => !['atwill', 'innate', 'pact'].contains(s.mode))
        .toList();
    final useSections =
        prepares || atwill.isNotEmpty || innate.isNotEmpty || pact.isNotEmpty;

    if (spells.isEmpty) {
      children.add(const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
            child: Text('Sin resultados', style: TextStyle(color: AppColors.label))),
      ));
    } else if (useSections) {
      if (prepares) {
        addSection('Preparados', book.where(_avail).toList(), slots: true);
        addSection('No preparados', book.where((s) => !_avail(s)).toList());
      } else {
        addSection('Conjuros', book, slots: true);
      }
      addSection('Pacto', pact, slots: true);
      addSection('At-Will', atwill);
      addSection('Innate Spellcasting', innate);
    } else {
      children.addAll(_byLevel(book, slots: true));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
      children: children,
    );
  }
}

/// Resumen de slots de conjuro (todos los niveles + pacto), siempre visible.
/// Incluye un botón para regenerar los espacios (value = max).
class _SlotsOverview extends ConsumerStatefulWidget {
  final List<SpellSlot> slots;
  const _SlotsOverview({required this.slots});

  @override
  ConsumerState<_SlotsOverview> createState() => _SlotsOverviewState();
}

class _SlotsOverviewState extends ConsumerState<_SlotsOverview> {
  bool _busy = false;

  Future<void> _restore() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(actorControllerProvider.notifier).restoreSpellSlots();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Espacios de conjuro regenerados')),
        );
      }
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
    final ordered = [...widget.slots]
      ..sort((a, b) => a.pact == b.pact ? a.level - b.level : (a.pact ? 1 : -1));
    return SheetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: MicroLabel('Espacios de conjuro')),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _busy ? null : _restore,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.gold))
                          : const Icon(Icons.refresh, size: 16, color: AppColors.gold),
                      const SizedBox(width: 4),
                      const Text('Regenerar',
                          style: TextStyle(fontSize: 11, color: AppColors.gold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: ordered.map(_chip).toList(),
          ),
        ],
      ),
    );
  }

  /// Suma/resta un espacio disponible (consumir = -1, agregar = +1),
  /// acotado a [0, max]. Persiste con `system.spells.<key>.value`.
  Future<void> _delta(SpellSlot s, int d) async {
    final nv = (s.value + d).clamp(0, s.max);
    if (nv == s.value) return;
    try {
      await ref
          .read(actorControllerProvider.notifier)
          .edit({'system.spells.${s.key}.value': nv});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo: $e')));
      }
    }
  }

  Widget _stepBtn(IconData ic, bool enabled, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: AppColors.gold.withAlpha(enabled ? 120 : 40)),
          ),
          child: Icon(ic,
              size: 14,
              color: enabled ? AppColors.gold : AppColors.gold.withAlpha(60)),
        ),
      );

  Widget _chip(SpellSlot s) {
    final label = s.pact ? 'Pacto N${s.level}' : 'N${s.level}';
    // s.value = slots disponibles (libres); s.max = total.
    final libres = s.value.clamp(0, s.max);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.gold.withAlpha(s.value > 0 ? 28 : 12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gold.withAlpha(s.value > 0 ? 110 : 50)),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w700,
                  color: s.value > 0 ? AppColors.gold : AppColors.label)),
          const SizedBox(height: 4),
          if (s.max <= 6)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < s.max; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < s.value ? AppColors.gold : Colors.transparent,
                        border: Border.all(color: AppColors.gold.withAlpha(140)),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 6),
          // Consumir (−) / agregar (+) un espacio, manualmente.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _stepBtn(Icons.remove, s.value > 0, () => _delta(s, -1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('$libres/${s.max}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold)),
              ),
              _stepBtn(Icons.add, s.value < s.max, () => _delta(s, 1)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LevelHeader extends StatelessWidget {
  final String title;
  final String? slots;
  const _LevelHeader({required this.title, this.slots});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 1,
                  color: AppColors.gold,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 9),
          Expanded(child: Container(height: 1, color: AppColors.gold.withAlpha(36))),
          if (slots != null) ...[
            const SizedBox(width: 9),
            Text(slots!, style: const TextStyle(fontSize: 10, color: AppColors.label)),
          ],
        ],
      ),
    );
  }
}

class _SpellRow extends ConsumerWidget {
  final ActorSpell spell;
  final bool last;
  const _SpellRow({required this.spell, required this.last});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = spell;
    final meta = [
      if (s.school.isNotEmpty) s.school,
      if (!s.isCantrip && !s.prepared) 'no prep',
      if (s.uses != null) '${s.uses!.value}/${s.uses!.max}',
    ].join(' · ');

    return InkWell(
      onTap: () => _showSpellDialog(context, ref, s),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: Color(0x0BFFFFFF))),
        ),
        child: Row(
          children: [
            Text('✦', style: TextStyle(fontSize: 13, color: AppColors.gold)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(s.name,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: s.prepared || s.isCantrip
                          ? AppColors.listText
                          : AppColors.sub)),
            ),
            if (meta.isNotEmpty)
              Text(meta, style: const TextStyle(fontSize: 10, color: AppColors.label)),
          ],
        ),
      ),
    );
  }
}

void _showSpellDialog(BuildContext context, WidgetRef ref, ActorSpell s) {
  final meta = [
    s.isCantrip ? 'Truco' : 'Nivel ${s.level}',
    if (s.school.isNotEmpty) s.school,
  ].join(' · ');
  final desc = (s.description ?? '').trim();
  // Niveles de slot disponibles (no-pacto) para upcastear.
  final slotLevels = (ref.read(actorControllerProvider).valueOrNull?.spellSlots ?? [])
      .where((sl) => !sl.pact && sl.value > 0)
      .map((sl) => sl.level)
      .toList();

  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.bgAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.gold.withAlpha(60)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.72, maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.name)),
                  const SizedBox(height: 2),
                  Text(meta,
                      style: const TextStyle(fontSize: 11, color: AppColors.gold)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                child: Text(
                  desc.isEmpty ? 'Sin descripción.' : desc,
                  style: const TextStyle(
                      fontSize: 13, height: 1.45, color: AppColors.listText),
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0x14FFFFFF)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cerrar')),
                  if (s.damage != null)
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        rollDamageTargeted(context, ref, itemId: s.id, name: s.name);
                      },
                      child: const Text('Daño'),
                    ),
                  if (s.canUse)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: Colors.black),
                      icon: const Icon(Icons.gps_fixed, size: 16),
                      onPressed: () {
                        Navigator.pop(ctx);
                        castWithTargets(context, ref,
                            itemId: s.id,
                            name: s.name,
                            hasAttack: s.hasAttack,
                            needsTargets: s.needsTargets,
                            hasResource: !s.isCantrip || s.uses != null,
                            activities: s.activities,
                            spellLevel: s.level,
                            slotLevels: slotLevels);
                      },
                      label: const Text('Lanzar'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('✦', style: TextStyle(fontSize: 30, color: AppColors.label)),
          SizedBox(height: 10),
          Text('No es lanzador de conjuros',
              style: TextStyle(color: AppColors.label)),
        ],
      ),
    );
  }
}
