import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/actor_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/foundry_actor.dart';
import 'sheet_dialogs.dart';
import 'sheet_kit.dart';

class AbilitiesGrid extends ConsumerWidget {
  final FoundryActor actor;
  const AbilitiesGrid({super.key, required this.actor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edit = ref.watch(editModeProvider);
    final abilities = actor.abilityList;
    // Filas de 3 con altura intrínseca: cada card se ajusta a su contenido
    // (compacto, sin overflow ni espacio sobrante en ninguna pantalla).
    final rows = <Widget>[];
    for (var i = 0; i < abilities.length; i += 3) {
      final chunk = abilities.skip(i).take(3).toList();
      rows.add(Padding(
        padding: EdgeInsets.only(bottom: i + 3 < abilities.length ? 9 : 0),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < 3; j++) ...[
                if (j > 0) const SizedBox(width: 9),
                Expanded(
                  child: j < chunk.length
                      ? _AbilityCard(
                          ability: chunk[j],
                          edit: edit,
                          pendingMod:
                              actor.isPending('abilities.${chunk[j].key}.mod'),
                          pendingSave:
                              actor.isPending('abilities.${chunk[j].key}.save'),
                        )
                      : const SizedBox(),
                ),
              ],
            ],
          ),
        ),
      ));
    }
    return Column(children: rows);
  }
}

class _AbilityCard extends ConsumerWidget {
  final ActorAbility ability;
  final bool edit;
  final bool pendingMod;
  final bool pendingSave;
  const _AbilityCard({
    required this.ability,
    required this.edit,
    this.pendingMod = false,
    this.pendingSave = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ab = ability;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InkWell(
            onTap: edit
                ? null
                : () => rollAction(context, ref, RollKind.ability, ab.key,
                    '${ab.label} (prueba)'),
            onLongPress: edit
                ? null
                : () => rollAction(context, ref, RollKind.ability, ab.key,
                    '${ab.label} (prueba)',
                    pick: true),
            child: Padding(
              padding: const EdgeInsets.only(top: 9, bottom: 4, left: 4, right: 4),
              child: Column(
                children: [
                  Text(ab.label.substring(0, 3).toUpperCase(),
                      style: const TextStyle(
                          fontSize: 9,
                          letterSpacing: 1.6,
                          color: AppColors.label,
                          fontWeight: FontWeight.w600)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(ab.modStr, style: cinzel(22)),
                      if (pendingMod)
                        const Padding(
                          padding: EdgeInsets.only(left: 2),
                          child: Icon(Icons.schedule, size: 11, color: AppColors.orange),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (edit)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: EditStepper(
                value: '${ab.value}',
                valueSize: 13,
                onDec: () => editAction(context, ref,
                    {'system.abilities.${ab.key}.value': ab.value - 1}),
                onInc: () => editAction(context, ref,
                    {'system.abilities.${ab.key}.value': ab.value + 1}),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text('${ab.value}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF8A857A))),
            ),
          InkWell(
            onTap: edit
                ? () => editAction(context, ref, {
                      'system.abilities.${ab.key}.proficient':
                          ab.saveProficient ? 0 : 1
                    })
                : () => rollAction(context, ref, RollKind.save, ab.key,
                    '${ab.label} (salvación)'),
            onLongPress: edit
                ? null
                : () => rollAction(context, ref, RollKind.save, ab.key,
                    '${ab.label} (salvación)',
                    pick: true),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0x0DFFFFFF))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ab.saveProficient ? AppColors.gold : AppColors.label,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text('SAVE ${ab.saveStr}',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.sub)),
                  if (pendingSave)
                    const Padding(
                      padding: EdgeInsets.only(left: 3),
                      child: Icon(Icons.schedule, size: 9, color: AppColors.orange),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
