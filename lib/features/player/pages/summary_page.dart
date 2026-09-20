import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/actor_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/foundry_actor.dart';
import '../widgets/abilities_grid.dart';
import '../widgets/hp_card.dart';
import '../widgets/sheet_dialogs.dart';
import '../widgets/sheet_kit.dart';

class SummaryPage extends ConsumerWidget {
  final FoundryActor actor;
  const SummaryPage({super.key, required this.actor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edit = ref.watch(editModeProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      children: [
        Row(
          children: [
            Expanded(child: _acBox(context, ref, edit)),
            const SizedBox(width: 9),
            Expanded(
              child: StatBox(
                label: 'Initiative',
                value: actor.initiative == null
                    ? '—'
                    : '${actor.initiative! >= 0 ? '+' : ''}${actor.initiative}',
                valueColor: AppColors.gold,
                onTap: () =>
                    rollAction(context, ref, RollKind.init, 'init', 'Iniciativa', pick: true),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(child: _speedBox(context, ref, edit)),
          ],
        ),
        const SizedBox(height: 11),
        _InspirationChip(inspired: actor.inspiration),
        const SizedBox(height: 11),
        HpCard(actor: actor),
        if (actor.xp != null) ...[
          const SizedBox(height: 11),
          _XpCard(xp: actor.xp!),
        ],
        if (actor.effects.isNotEmpty) ...[
          SectionHeader('Estados'),
          _EffectsSection(effects: actor.effects),
        ],
        if (actor.items.any((i) => i.hasAttack) || actor.feats.isNotEmpty) ...[
          SectionHeader('Acciones'),
          for (final it in [
            ...actor.items.where((i) => i.hasAttack),
            ...actor.feats,
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AttackRow(item: it),
            ),
        ],
        SectionHeader('Habilidades',
            trailing: actor.prof != null ? 'Prof +${actor.prof}' : null),
        AbilitiesGrid(actor: actor),
        if (actor.features.isNotEmpty) ...[
          SectionHeader('Rasgos'),
          for (final f in actor.features)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _FeatureRow(item: f),
            ),
        ],
      ],
    );
  }

  Widget _acBox(BuildContext context, WidgetRef ref, bool edit) {
    if (edit && actor.acEditable) {
      final cur = actor.acFlat ?? actor.ac ?? 10;
      return _StepBox(
        label: 'Armor',
        child: EditStepper(
          value: '$cur',
          onDec: () => editAction(context, ref, {'system.attributes.ac.flat': cur - 1}),
          onInc: () => editAction(context, ref, {'system.attributes.ac.flat': cur + 1}),
        ),
      );
    }
    return StatBox(label: 'Armor', value: '${actor.ac ?? '—'}');
  }

  Widget _speedBox(BuildContext context, WidgetRef ref, bool edit) {
    if (edit) {
      final cur = int.tryParse(actor.speed ?? '') ?? 30;
      return _StepBox(
        label: 'Speed',
        child: EditStepper(
          value: '$cur',
          onDec: () => editAction(
              context, ref, {'system.attributes.movement.walk': '${cur - 1}'}),
          onInc: () => editAction(
              context, ref, {'system.attributes.movement.walk': '${cur + 1}'}),
        ),
      );
    }
    return StatBox(label: 'Speed', value: actor.speed ?? '—');
  }
}

/// Fila de acción de ataque (arma) en la hoja: Atk (con targets) + Dmg.
class _AttackRow extends ConsumerWidget {
  final ActorItem item;
  const _AttackRow({required this.item});

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
              if (item.uses != null) _UsesPill(uses: item.uses!),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.gold),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inspiración (heroic inspiration): estrella dorada si la tenés. Tocar para
/// ganar/gastar (togglea `system.attributes.inspiration`).
class _InspirationChip extends ConsumerWidget {
  final bool inspired;
  const _InspirationChip({required this.inspired});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = inspired ? AppColors.gold : AppColors.muted;
    return SheetCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => editAction(
            context, ref, {'system.attributes.inspiration': !inspired}),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Icon(inspired ? Icons.star : Icons.star_border, size: 22, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(inspired ? 'Inspirado' : 'Sin inspiración',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: color)),
              ),
              Text(inspired ? 'Gastar' : 'Marcar',
                  style: const TextStyle(fontSize: 11, color: AppColors.label)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Estados activos (rage, bless, condiciones…) con botón para terminarlos.
class _EffectsSection extends ConsumerStatefulWidget {
  final List<ActorEffect> effects;
  const _EffectsSection({required this.effects});

  @override
  ConsumerState<_EffectsSection> createState() => _EffectsSectionState();
}

class _EffectsSectionState extends ConsumerState<_EffectsSection> {
  final Set<String> _busy = {};

  Future<void> _end(ActorEffect e) async {
    if (_busy.contains(e.id)) return;
    setState(() => _busy.add(e.id));
    try {
      await ref.read(actorControllerProvider.notifier).endEffect(e.id);
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo terminar: $err')));
      }
    }
    if (mounted) setState(() => _busy.remove(e.id));
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in widget.effects)
          Container(
            padding: const EdgeInsets.fromLTRB(11, 6, 5, 6),
            decoration: BoxDecoration(
              color: AppColors.orange.withAlpha(28),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.orange.withAlpha(120)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department, size: 15, color: AppColors.orange),
                const SizedBox(width: 6),
                Text(e.name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.orange)),
                const SizedBox(width: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _end(e),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: _busy.contains(e.id)
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.orange))
                        : const Icon(Icons.close, size: 16, color: AppColors.orange),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Pill de recurso: espacios/cargas restantes vs. totales (ej. 0/2).
class _UsesPill extends StatelessWidget {
  final ItemUses uses;
  const _UsesPill({required this.uses});

  @override
  Widget build(BuildContext context) {
    final has = uses.value > 0;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gold.withAlpha(has ? 28 : 12),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.gold.withAlpha(has ? 110 : 50)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${uses.value}/${uses.max}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: has ? AppColors.gold : AppColors.label)),
          const Text('usos',
              style: TextStyle(fontSize: 8, color: AppColors.label)),
        ],
      ),
    );
  }
}

/// Rasgo pasivo: solo abre la descripción al tocar.
class _FeatureRow extends ConsumerWidget {
  final ActorItem item;
  const _FeatureRow({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SheetCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showActionInfoDialog(context, ref,
            itemId: item.id, name: item.name, description: item.description),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
          child: Row(
            children: [
              Expanded(
                child: Text(item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: AppColors.listText)),
              ),
              if (item.uses != null) _UsesPill(uses: item.uses!),
              const Icon(Icons.info_outline, size: 18, color: AppColors.label),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de experiencia: barra de progreso al próximo nivel + edición manual.
class _XpCard extends ConsumerWidget {
  final ActorXp xp;
  const _XpCard({required this.xp});

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final v = await showNumberDialog(context, 'Experiencia', xp.value);
    if (v == null || !context.mounted) return;
    await editAction(context, ref, {'system.details.xp.value': v});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pct = xp.max > 0 ? (xp.value / xp.max).clamp(0.0, 1.0) : 0.0;
    return SheetCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _edit(context, ref),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const MicroLabel('Experiencia'),
                  const Spacer(),
                  Text(
                    xp.max > 0 ? '${xp.value} / ${xp.max}' : '${xp.value}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit, size: 14, color: AppColors.label),
                ],
              ),
              if (xp.max > 0) ...[
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 7,
                    backgroundColor: AppColors.gold.withAlpha(24),
                    valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StepBox extends StatelessWidget {
  final String label;
  final Widget child;
  const _StepBox({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return SheetCard(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
      child: Column(
        children: [
          MicroLabel(label),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
