import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/actor_controller.dart';
import '../../controllers/dm_party_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../models/foundry_actor.dart';
import '../player/player_screen.dart';
import '../player/widgets/actor_avatar.dart';

/// Dashboard del DM: todas las hojas de los jugadores de un vistazo (PV, CA,
/// inspiración, estados), en vivo. Tocar una abre la hoja completa.
class DmDashboard extends ConsumerWidget {
  const DmDashboard({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, String actorId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    await ref.read(actorControllerProvider.notifier).load(actorId);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PlayerScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dmPartyProvider);
    return RefreshIndicator(
      onRefresh: () => ref.read(dmPartyProvider.notifier).refresh(),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [
          const SizedBox(height: 80),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No se pudieron cargar los personajes.\n$e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.label)),
            ),
          ),
          Center(
            child: FilledButton(
              onPressed: () => ref.read(dmPartyProvider.notifier).refresh(),
              child: const Text('Reintentar'),
            ),
          ),
        ]),
        data: (actors) {
          if (actors.isEmpty) {
            return const Center(
                child: Text('Sin personajes', style: TextStyle(color: AppColors.label)));
          }
          return LayoutBuilder(
            builder: (ctx, cons) {
              // Landscape/tablet: 2 columnas; portrait: 1.
              final wide = cons.maxWidth >= 640;
              final cardW = wide ? (cons.maxWidth - 24 - 10) / 2 : cons.maxWidth - 24;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final a in actors)
                      SizedBox(
                        width: cardW,
                        child: _PartyCard(
                          actor: a,
                          onTap: () => _open(context, ref, a.id),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PartyCard extends StatelessWidget {
  final FoundryActor actor;
  final VoidCallback onTap;
  const _PartyCard({required this.actor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hp = actor.hp;
    final pct = hp.max > 0 ? (hp.value / hp.max).clamp(0.0, 1.0) : 0.0;
    final hpColor = pct > 0.5
        ? AppColors.green
        : (pct > 0.25 ? AppColors.orange : AppColors.red);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withAlpha(46)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Column(
            children: [
              Row(
                children: [
                  ActorAvatar(img: actor.img, name: actor.name, radius: 22),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(actor.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: cinzel(15, weight: FontWeight.w600)),
                            ),
                            if (actor.inspiration) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.star, size: 15, color: AppColors.gold),
                            ],
                          ],
                        ),
                        Text(actor.classLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AppColors.sub)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _MiniStat(label: 'CA', value: '${actor.ac ?? '—'}'),
                ],
              ),
              const SizedBox(height: 9),
              // Barra de PV.
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 9,
                        backgroundColor: Colors.white.withAlpha(18),
                        valueColor: AlwaysStoppedAnimation(hpColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    '${hp.value}/${hp.max}${hp.temp > 0 ? ' +${hp.temp}' : ''}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.listText),
                  ),
                ],
              ),
              if (actor.effects.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
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
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.gold)),
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.label)),
      ],
    );
  }
}
