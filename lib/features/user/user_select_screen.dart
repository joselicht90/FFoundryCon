import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/session_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/scene_scaffold.dart';
import '../../models/foundry_user.dart';
import '../gm/gm_screen.dart';
import '../player/actor_select_screen.dart';

class UserSelectScreen extends ConsumerWidget {
  const UserSelectScreen({super.key});

  Color _userColor(FoundryUser user) {
    try {
      final hex = user.color.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppColors.gold;
    }
  }

  void _selectUser(BuildContext context, WidgetRef ref, FoundryUser user) {
    ref.read(selectedUserProvider.notifier).select(user);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => user.isGM ? const GmScreen() : const ActorSelectScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final world = ref.watch(selectedWorldProvider);
    if (world == null) {
      return const Scaffold(body: Center(child: Text('No hay mundo seleccionado')));
    }
    final usersAsync = ref.watch(worldUsersProvider(world.id));

    return SceneScaffold(
      overline: world.title,
      title: 'Elegí usuario',
      leading: IconButton(
        icon: const Icon(Icons.chevron_left, color: AppColors.label),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: AppColors.label),
          onPressed: () => ref.invalidate(worldUsersProvider(world.id)),
        ),
      ],
      child: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Centered(
          message: 'Error cargando usuarios:\n$e',
          onRetry: () => ref.invalidate(worldUsersProvider(world.id)),
        ),
        data: (allUsers) {
          // Ocultamos las cuentas de party (Party, Party2, …) y el bot headless
          // (PiBOT). El DM real sí se lista (entra a la vista de DM). Los GM van
          // primero.
          final hideRe = RegExp(r'^(party\d*|pibot)$', caseSensitive: false);
          final users = allUsers
              .where((u) => !hideRe.hasMatch(u.name.trim()))
              .toList()
            ..sort((a, b) {
              if (a.isGM != b.isGM) return a.isGM ? -1 : 1;
              return a.name.compareTo(b.name);
            });
          if (users.isEmpty) {
            return _Centered(
              message: 'Este mundo no tiene jugadores.',
              onRetry: () => ref.invalidate(worldUsersProvider(world.id)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final user = users[i];
              return _RosterCard(
                ring: _userColor(user),
                initial: user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                title: user.name,
                subtitle: user.isGM ? 'Game Master' : 'Jugador',
                trailing: user.isGM
                    ? const Icon(Icons.shield, size: 18, color: AppColors.gold)
                    : null,
                onTap: () => _selectUser(context, ref, user),
              );
            },
          );
        },
      ),
    );
  }
}

/// Card de roster (usuario o personaje): anillo + título Cinzel + subtítulo.
class _RosterCard extends StatelessWidget {
  final Color ring;
  final String initial;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;
  const _RosterCard({
    required this.ring,
    required this.initial,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
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
          border: Border.all(color: AppColors.gold.withAlpha(46)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [ring.withAlpha(180), ring.withAlpha(90)],
                ),
              ),
              child: Text(initial, style: cinzel(20, color: Colors.white)),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: cinzel(16, weight: FontWeight.w600)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
            const SizedBox(width: 6),
            const Text('Entrar ›',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.gold)),
          ],
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _Centered({required this.message, required this.onRetry});

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
