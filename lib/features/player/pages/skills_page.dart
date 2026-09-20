import 'package:flutter/material.dart';

import '../../../models/foundry_actor.dart';
import '../widgets/sheet_kit.dart';
import '../widgets/skills_list.dart';

class SkillsPage extends StatelessWidget {
  final FoundryActor actor;
  const SkillsPage({super.key, required this.actor});

  @override
  Widget build(BuildContext context) {
    final perc = actor.skills['prc']?.passive;
    final ins = actor.skills['ins']?.passive;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
      children: [
        Row(
          children: [
            Expanded(
              child: StatBox(
                label: 'Pasiva Perc.',
                value: '${perc ?? '—'}',
                valueSize: 19,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatBox(
                label: 'Pasiva Insight',
                value: '${ins ?? '—'}',
                valueSize: 19,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatBox(
                label: 'Prof Bonus',
                value: actor.prof != null ? '+${actor.prof}' : '—',
                valueSize: 19,
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        SkillsList(actor: actor),
      ],
    );
  }
}
