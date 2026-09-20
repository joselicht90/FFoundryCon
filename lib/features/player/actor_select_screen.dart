import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/actor_controller.dart';
import '../../controllers/session_controller.dart';
import '../../core/network/image_url.dart';
import '../../core/network/reader_url_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/scene_scaffold.dart';
import '../../repositories/foundry_repository.dart';
import 'player_screen.dart';

class ActorSelectScreen extends ConsumerWidget {
  const ActorSelectScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, String actorId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    await ref.read(actorControllerProvider.notifier).load(actorId);
    if (!context.mounted) return;
    Navigator.of(context).pop();

    final st = ref.read(actorControllerProvider);
    if (st.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir la hoja: ${st.error}')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PlayerScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(selectedUserProvider);
    final actorsAsync = ref.watch(actorsProvider);
    final base = ref.watch(readerUrlProvider);

    return SceneScaffold(
      overline: user?.name ?? 'Jugador',
      title: 'Elegí personaje',
      leading: IconButton(
        icon: const Icon(Icons.chevron_left, color: AppColors.label),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: AppColors.label),
          onPressed: () => ref.invalidate(actorsProvider),
        ),
      ],
      child: actorsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: 'No se pudieron leer los personajes.\n'
              'Si Foundry está cerrado, se usa la base local.\n\n$e',
          onRetry: () => ref.invalidate(actorsProvider),
        ),
        data: (actors) {
          final isGM = user?.isGM ?? false;
          final mine = <ActorSummary>[];
          final others = <ActorSummary>[];
          for (final a in actors) {
            (user != null && a.userIds.contains(user.id) ? mine : others).add(a);
          }
          final ordered = isGM ? [...mine, ...others] : mine;

          if (ordered.isEmpty) {
            return _ErrorView(
              message: '${user?.name ?? 'Este usuario'} no tiene personajes asignados.',
              onRetry: () => ref.invalidate(actorsProvider),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: ordered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final a = ordered[i];
              final isMine = mine.contains(a);
              final url = foundryImageUrl(base, a.img);
              return _CharacterCard(
                imageUrl: url,
                initial: a.name.isNotEmpty ? a.name[0].toUpperCase() : '?',
                name: a.name,
                mine: isMine,
                onTap: () => _open(context, ref, a.id),
              );
            },
          );
        },
      ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  final String? imageUrl;
  final String initial;
  final String name;
  final bool mine;
  final VoidCallback onTap;
  const _CharacterCard({
    required this.imageUrl,
    required this.initial,
    required this.name,
    required this.mine,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.bgAlt,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
              color: mine ? AppColors.gold.withAlpha(90) : AppColors.gold.withAlpha(46)),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold.withAlpha(110)),
                image: imageUrl != null
                    ? DecorationImage(image: NetworkImage(imageUrl!), fit: BoxFit.cover)
                    : null,
              ),
              alignment: Alignment.center,
              child: imageUrl == null
                  ? Text(initial, style: cinzel(22, color: Colors.white))
                  : null,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: cinzel(16, weight: FontWeight.w600)),
                  if (mine)
                    const Text('Tu personaje',
                        style: TextStyle(fontSize: 12, color: AppColors.gold)),
                ],
              ),
            ),
            if (mine)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.star, size: 16, color: AppColors.gold),
              ),
            const Text('Jugar ›',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.gold)),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(message, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
