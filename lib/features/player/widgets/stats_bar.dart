import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/actor_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/foundry_actor.dart';
import 'sheet_dialogs.dart';

class StatsBar extends ConsumerWidget {
  final FoundryActor actor;
  const StatsBar({super.key, required this.actor});

  Future<void> _damageHeal(BuildContext c, WidgetRef ref) async {
    final hp = actor.hp;
    final r = await showDamageHealDialog(c, hp);
    if (r == null || !c.mounted) return;
    if (r.heal) {
      final v = (hp.value + r.amount).clamp(0, hp.max == 0 ? 9999 : hp.max);
      await editAction(c, ref, {'system.attributes.hp.value': v});
    } else {
      // El daño consume primero los PV temporales.
      final tempLeft = (hp.temp - r.amount).clamp(0, hp.temp);
      final overflow = (r.amount - hp.temp).clamp(0, r.amount);
      final v = (hp.value - overflow).clamp(0, hp.max == 0 ? 9999 : hp.max);
      await editAction(c, ref, {
        'system.attributes.hp.value': v,
        'system.attributes.hp.temp': tempLeft,
      });
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edit = ref.watch(editModeProvider);
    final hp = actor.hp;
    final tempStr = hp.temp > 0 ? ' (+${hp.temp})' : '';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Chip(
          icon: Icons.favorite,
          label: 'PV',
          value: '${hp.value}/${hp.max}$tempStr',
          color: AppColors.red,
          // Mantené apretado para daño/curación (siempre disponible).
          onLongPress: () => _damageHeal(context, ref),
          onTap: edit
              ? () async {
                  final v = await showNumberDialog(context, 'PV actuales', hp.value);
                  if (v != null && context.mounted) {
                    await editAction(context, ref, {'system.attributes.hp.value': v});
                  }
                }
              : null,
        ),
        _Chip(
          icon: Icons.shield,
          label: 'CA',
          value: '${actor.ac ?? '—'}',
          color: AppColors.blue,
          onTap: edit && actor.acEditable
              ? () async {
                  final v = await showNumberDialog(
                      context, 'CA (flat)', actor.acFlat ?? actor.ac ?? 10);
                  if (v != null && context.mounted) {
                    await editAction(context, ref, {'system.attributes.ac.flat': v});
                  }
                }
              : null,
        ),
        _Chip(
          icon: Icons.directions_run,
          label: 'Vel',
          value: '${actor.speed ?? '—'} ${actor.speedUnits}',
          color: Colors.teal,
          onTap: edit
              ? () async {
                  final v = await showNumberDialog(context,
                      'Velocidad (${actor.speedUnits})',
                      int.tryParse(actor.speed ?? '') ?? 30);
                  if (v != null && context.mounted) {
                    await editAction(
                        context, ref, {'system.attributes.movement.walk': '$v'});
                  }
                }
              : null,
        ),
        if (actor.prof != null)
          _Chip(icon: Icons.star, label: 'Comp', value: '+${actor.prof}', color: AppColors.gold),
        if (actor.initiative != null)
          _Chip(
            icon: Icons.bolt,
            label: 'Inic',
            value: '${actor.initiative! >= 0 ? '+' : ''}${actor.initiative}',
            color: Colors.purple,
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _Chip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final interactive = onTap != null || onLongPress != null;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: interactive ? color : color.withAlpha(80),
            width: interactive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text('$label ', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            Text(value,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.edit, size: 11, color: color),
            ],
          ],
        ),
      ),
    );
  }
}
