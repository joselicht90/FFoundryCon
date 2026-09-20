import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/session_controller.dart';
import '../../core/network/image_url.dart';
import '../../core/network/reader_url_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/scene_scaffold.dart';
import '../../models/foundry_world.dart';
import '../settings/settings_screen.dart';
import '../user/user_select_screen.dart';

class WorldSelectScreen extends ConsumerWidget {
  const WorldSelectScreen({super.key});

  void _select(BuildContext context, WidgetRef ref, FoundryWorld world) {
    ref.read(selectedWorldProvider.notifier).select(world);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UserSelectScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worlds = ref.watch(worldsProvider);
    final base = ref.watch(readerUrlProvider);

    return SceneScaffold(
      overline: 'Foundry',
      title: 'Elegí un mundo',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: AppColors.label),
          onPressed: () => ref.invalidate(worldsProvider),
        ),
        IconButton(
          icon: const Icon(Icons.settings, color: AppColors.label),
          tooltip: 'Configuración',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
      child: worlds.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: 'Error cargando mundos:\n$e',
          onRetry: () => ref.invalidate(worldsProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return _ErrorView(
              message: 'No se encontraron mundos.',
              onRetry: () => ref.invalidate(worldsProvider),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 13),
            itemBuilder: (_, i) => _WorldCard(
              world: list[i],
              imageUrl: foundryImageUrl(base, list[i].image),
              onTap: () => _select(context, ref, list[i]),
            ),
          );
        },
      ),
    );
  }
}

class _WorldCard extends StatelessWidget {
  final FoundryWorld world;
  final String? imageUrl;
  final VoidCallback onTap;
  const _WorldCard({required this.world, this.imageUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // banner con un tono derivado del título (fallback si no hay imagen)
    final hue = (world.title.hashCode % 360).abs().toDouble();
    final c1 = HSLColor.fromAHSL(1, hue, .35, .28).toColor();
    final c2 = HSLColor.fromAHSL(1, (hue + 40) % 360, .4, .16).toColor();

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.bgAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold.withAlpha(46)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 96,
              alignment: Alignment.bottomLeft,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                gradient: imageUrl == null
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [c1, c2],
                      )
                    : null,
                image: imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(imageUrl!),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                            Colors.black.withAlpha(60), BlendMode.darken),
                      )
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(128),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text((world.system ?? 'FOUNDRY').toUpperCase(),
                        style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: Colors.white)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(world.title, style: cinzel(16, weight: FontWeight.w600)),
                  const SizedBox(height: 7),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(world.id,
                          style: const TextStyle(fontSize: 11, color: AppColors.label)),
                      const Text('Entrar ›',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gold)),
                    ],
                  ),
                ],
              ),
            ),
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
