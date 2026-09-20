import 'package:flutter/material.dart';

import '../../../models/foundry_actor.dart';
import 'actor_avatar.dart';

class SheetHeader extends StatelessWidget {
  final FoundryActor actor;
  const SheetHeader({super.key, required this.actor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ActorAvatar(img: actor.img, name: actor.name, radius: 36),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                actor.name,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                actor.classLine,
                style: const TextStyle(color: Colors.grey),
              ),
              if (actor.level != null)
                Text(
                  'Nivel ${actor.level}'
                  '${actor.background.isNotEmpty ? ' • ${actor.background}' : ''}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
