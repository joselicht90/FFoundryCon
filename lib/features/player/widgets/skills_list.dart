import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/actor_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/foundry_actor.dart';
import 'sheet_dialogs.dart';

class SkillsList extends ConsumerWidget {
  final FoundryActor actor;
  const SkillsList({super.key, required this.actor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edit = ref.watch(editModeProvider);
    return Column(
      children: [
        for (final s in actor.skillList) ...[
          _SkillRow(
            skill: s,
            edit: edit,
            pendingTotal: actor.isPending('skills.${s.key}.total'),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SkillRow extends ConsumerWidget {
  final ActorSkill skill;
  final bool edit;
  final bool pendingTotal;
  const _SkillRow({
    required this.skill,
    required this.edit,
    this.pendingTotal = false,
  });

  Color _dotColor(num p) {
    if (p >= 2) return AppColors.gold;
    if (p >= 1) return AppColors.green;
    if (p > 0) return AppColors.orange;
    return const Color(0xFF3A3D44);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = skill;
    final dot = _dotColor(s.proficient);
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: edit
          ? () {
              final next = s.proficient >= 2 ? 0 : (s.proficient >= 1 ? 2 : 1);
              editAction(context, ref, {'system.skills.${s.key}.value': next});
            }
          : () => rollAction(context, ref, RollKind.skill, s.key, s.label),
      onLongPress: edit
          ? null
          : () => rollAction(context, ref, RollKind.skill, s.key, s.label, pick: true),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dot,
                boxShadow: s.proficient >= 1
                    ? [BoxShadow(color: dot.withAlpha(120), blurRadius: 6)]
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(s.label,
                  style: const TextStyle(fontSize: 13.5, color: AppColors.listText)),
            ),
            Text(s.ability.toUpperCase(),
                style: const TextStyle(
                    fontSize: 9,
                    letterSpacing: .5,
                    color: AppColors.label,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 10),
            if (pendingTotal)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.schedule, size: 11, color: AppColors.orange),
              ),
            SizedBox(
              width: 30,
              child: Text(s.totalStr,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.gold)),
            ),
          ],
        ),
      ),
    );
  }
}
