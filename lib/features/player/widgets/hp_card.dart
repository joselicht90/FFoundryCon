import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/actor_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/foundry_actor.dart';
import 'sheet_dialogs.dart';
import 'sheet_kit.dart';

/// Color para HP temporal (escudo), distinto del rojo de la vida.
const Color _tempColor = Color(0xFF5AA9E6);

class HpCard extends ConsumerWidget {
  final FoundryActor actor;
  const HpCard({super.key, required this.actor});

  Future<void> _apply(BuildContext c, WidgetRef ref, int value, int temp) async {
    await editAction(c, ref, {
      'system.attributes.hp.value': value,
      'system.attributes.hp.temp': temp,
    });
  }

  Future<void> _damage(BuildContext c, WidgetRef ref) async {
    final hp = actor.hp;
    final amount = await showAmountDialog(c, 'Daño', AppColors.hpFillB);
    if (amount == null || !c.mounted) return;
    final tempLeft = (hp.temp - amount).clamp(0, hp.temp);
    final overflow = (amount - hp.temp).clamp(0, amount);
    final v = (hp.value - overflow).clamp(0, hp.max == 0 ? 99999 : hp.max);
    await _apply(c, ref, v, tempLeft);
  }

  Future<void> _heal(BuildContext c, WidgetRef ref) async {
    final hp = actor.hp;
    final res = await showHealDialog(c, hp.temp);
    if (res == null || !c.mounted) return;
    if (res.temp) {
      // El temp no se acumula: se queda el mayor entre el actual y el nuevo.
      final t = res.amount > hp.temp ? res.amount : hp.temp;
      await editAction(c, ref, {'system.attributes.hp.temp': t});
    } else {
      final v = (hp.value + res.amount).clamp(0, hp.max == 0 ? 99999 : hp.max);
      await editAction(c, ref, {'system.attributes.hp.value': v});
    }
  }

  /// Setea el temp HP a un valor exacto (para editarlo a mano).
  Future<void> _setTemp(BuildContext c, WidgetRef ref) async {
    final t = await showNumberDialog(c, 'Temp HP', actor.hp.temp);
    if (t == null || !c.mounted) return;
    await editAction(c, ref, {
      'system.attributes.hp.temp': t.clamp(0, 99999),
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edit = ref.watch(editModeProvider);
    final hp = actor.hp;
    final pct = hp.max > 0 ? (hp.value / hp.max).clamp(0.0, 1.0) : 0.0;

    return SheetCard(
      borderColor: AppColors.hpFillB.withAlpha(56),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('HIT POINTS',
              style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.4,
                  color: AppColors.hpLabel,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${hp.value}', style: cinzel(32, color: AppColors.hpValue, height: .9)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('/ ${hp.max}',
                    style: const TextStyle(fontSize: 15, color: Color(0xFF6E5A57))),
              ),
              // Chip de HP temporal: visible si hay temp, o siempre en modo edición.
              // Tocarlo permite setear el valor a mano.
              if (hp.temp > 0 || edit) ...[
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _setTemp(context, ref),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _tempColor.withAlpha(36),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _tempColor.withAlpha(120)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shield, size: 12, color: _tempColor),
                          const SizedBox(width: 4),
                          Text(hp.temp > 0 ? '+${hp.temp}' : 'Temp',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _tempColor)),
                          if (edit) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.edit, size: 11, color: _tempColor),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              if (edit) ...[
                const Spacer(),
                const Text('MAX ',
                    style: TextStyle(fontSize: 10, color: AppColors.label)),
                EditStepper(
                  value: '${hp.max}',
                  valueSize: 14,
                  onDec: () => editAction(context, ref,
                      {'system.attributes.hp.max': (hp.max - 1).clamp(0, 99999)}),
                  onInc: () => editAction(
                      context, ref, {'system.attributes.hp.max': hp.max + 1}),
                ),
              ],
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LayoutBuilder(
              builder: (ctx, c) {
                final w = c.maxWidth;
                final hpW = pct * w;
                final tempFrac =
                    hp.max > 0 ? (hp.temp / hp.max).clamp(0.0, 1.0) : 0.0;
                final tempW = (tempFrac * w).clamp(0.0, (w - hpW).clamp(0.0, w));
                return Stack(
                  children: [
                    Container(height: 8, width: w, color: AppColors.hpTrack),
                    Container(height: 8, width: hpW, color: AppColors.hpFillB),
                    // HP temporal: segmento azul (escudo) tras la vida actual.
                    if (hp.temp > 0)
                      Positioned(
                        left: hpW,
                        child: Container(height: 8, width: tempW, color: _tempColor),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: _btn(context, '− Daño', AppColors.hpValue,
                    AppColors.hpFillB.withAlpha(90), () => _damage(context, ref)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _btn(context, '+ Curar', AppColors.healText,
                    AppColors.green.withAlpha(90), () => _heal(context, ref)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _btn(BuildContext c, String label, Color fg, Color border, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
      ),
    );
  }
}
