import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/actor_controller.dart';
import '../../controllers/session_controller.dart';
import '../../controllers/token_controller.dart';
import '../../core/theme/app_theme.dart';
import 'map_screen.dart';
import '../../models/foundry_token.dart';
import 'widgets/sheet_dialogs.dart';
import 'widgets/sheet_kit.dart';

class TokenControlScreen extends ConsumerStatefulWidget {
  const TokenControlScreen({super.key});

  @override
  ConsumerState<TokenControlScreen> createState() => _TokenControlScreenState();
}

class _TokenControlScreenState extends ConsumerState<TokenControlScreen> {
  String? _selectedId;
  bool _moving = false;
  final Set<String> _targets = {};

  bool _canControl(FoundryToken t, bool isGM, String? userId) =>
      isGM || (userId != null && t.ownedBy(userId));

  Future<void> _step(StepDirection direction) async {
    final id = _selectedId;
    if (id == null || _moving) return;
    setState(() => _moving = true);
    try {
      await ref.read(tokenControllerProvider.notifier).step(id, direction);
    } catch (e) {
      if (mounted) sheetToast(context, 'Error moviendo: $e');
    }
    if (mounted) setState(() => _moving = false);
  }

  Future<void> _toggleTarget(String id) async {
    setState(() => _targets.contains(id) ? _targets.remove(id) : _targets.add(id));
    try {
      await ref.read(tokenControllerProvider.notifier).setTargets(_targets.toList());
    } catch (e) {
      if (mounted) sheetToast(context, 'No se pudo fijar objetivos: $e');
    }
  }

  Future<void> _clearTargets() async {
    setState(_targets.clear);
    try {
      await ref.read(tokenControllerProvider.notifier).setTargets([]);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final tokensAsync = ref.watch(tokenControllerProvider);
    final user = ref.watch(selectedUserProvider);
    final actor = ref.watch(actorControllerProvider).valueOrNull;
    final isGM = user?.isGM ?? false;

    if (actor != null && actor.offline) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Control de tokens deshabilitado.\nRequiere Foundry abierto.',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.label)),
        ),
      );
    }

    return tokensAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text('$e', style: const TextStyle(color: AppColors.red))),
      data: (tokens) {
        final visible =
            isGM ? tokens : tokens.where((t) => !t.hidden && !t.isSecret).toList();
        if (_selectedId == null || !visible.any((t) => t.id == _selectedId)) {
          final mine = visible.where((t) => _canControl(t, isGM, user?.id)).toList();
          if (mine.isNotEmpty) {
            _selectedId = mine
                .firstWhere((t) => t.actorId == actor?.id, orElse: () => mine.first)
                .id;
          }
        }
        String? selName;
        for (final t in visible) {
          if (t.id == _selectedId) selName = t.name;
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('Abrir mapa completo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.gold,
                side: BorderSide(color: AppColors.gold.withAlpha(110)),
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MapScreen()),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MicroLabel('Controlando'),
                    Text(selName ?? '—',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.name)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const MicroLabel('Objetivos'),
                    Text('${_targets.length}',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.target)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            _legend(),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children:
                  visible.map((t) => _tokenBadge(t, isGM, user?.id, actor?.id)).toList(),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dpad(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: [
                      _action('Limpiar objetivos', AppColors.target, _clearTargets),
                      const SizedBox(height: 8),
                      _action('Controlar mi token', AppColors.tokenYou, () {
                        for (final t in visible) {
                          if (t.actorId == actor?.id) {
                            setState(() => _selectedId = t.id);
                            return;
                          }
                        }
                      }),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
                'Tocá un aliado para controlarlo · tocá enemigos para fijar objetivo',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF6F6A60))),
          ],
        );
      },
    );
  }

  Color _tokenColor(FoundryToken t, String? userId, String? actorId) {
    if (t.actorId == actorId) return AppColors.tokenYou;
    if (t.isHostile) return AppColors.tokenEnemy;
    if (t.isFriendly || (userId != null && t.ownedBy(userId))) {
      return AppColors.tokenAlly;
    }
    return const Color(0xFF555A63);
  }

  Widget _tokenBadge(FoundryToken t, bool isGM, String? userId, String? actorId) {
    final color = _tokenColor(t, userId, actorId);
    final controllable = _canControl(t, isGM, userId);
    final isControlled = t.id == _selectedId;
    final isTarget = _targets.contains(t.id);
    final initial = t.name.isNotEmpty ? t.name[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () => controllable
          ? setState(() => _selectedId = t.id)
          : _toggleTarget(t.id),
      child: SizedBox(
        width: 58,
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: isControlled
                        ? Border.all(color: AppColors.gold, width: 2.5)
                        : null,
                  ),
                  child: Text(initial,
                      style: cinzel(18, color: Colors.white, weight: FontWeight.w700)),
                ),
                if (isTarget)
                  Positioned(
                    left: -4,
                    right: -4,
                    top: -4,
                    bottom: -4,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.target, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(t.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9, color: AppColors.label)),
          ],
        ),
      ),
    );
  }

  Widget _legend() {
    Widget item(Color c, String t, {bool ring = false}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ring ? null : c,
                border: ring ? Border.all(color: c, width: 2) : null,
              ),
            ),
            const SizedBox(width: 5),
            Text(t, style: const TextStyle(fontSize: 10, color: AppColors.label)),
          ],
        );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 6,
      children: [
        item(AppColors.tokenYou, 'Vos'),
        item(AppColors.tokenAlly, 'Aliado'),
        item(AppColors.tokenEnemy, 'Enemigo'),
        item(AppColors.target, 'Objetivo', ring: true),
      ],
    );
  }

  Widget _dpad() {
    Widget cell({IconData? icon, VoidCallback? onTap, String? center}) {
      if (icon == null && center == null) {
        return const SizedBox(width: 46, height: 46);
      }
      return InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: center != null ? const Color(0xFF1A1C21) : const Color(0xFF22252B),
            borderRadius: BorderRadius.circular(11),
            border:
                center != null ? null : Border.all(color: AppColors.gold.withAlpha(64)),
          ),
          child: icon != null
              ? Icon(icon, color: AppColors.gold, size: 20)
              : Text(center!, style: cinzel(13, color: const Color(0xFF6F6A60))),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          cell(),
          const SizedBox(width: 5),
          cell(icon: Icons.keyboard_arrow_up, onTap: _moving ? null : () => _step(StepDirection.up)),
          const SizedBox(width: 5),
          cell(),
        ]),
        const SizedBox(height: 5),
        Row(mainAxisSize: MainAxisSize.min, children: [
          cell(icon: Icons.keyboard_arrow_left, onTap: _moving ? null : () => _step(StepDirection.left)),
          const SizedBox(width: 5),
          cell(center: _selectedId != null ? '•' : ''),
          const SizedBox(width: 5),
          cell(icon: Icons.keyboard_arrow_right, onTap: _moving ? null : () => _step(StepDirection.right)),
        ]),
        const SizedBox(height: 5),
        Row(mainAxisSize: MainAxisSize.min, children: [
          cell(),
          const SizedBox(width: 5),
          cell(icon: Icons.keyboard_arrow_down, onTap: _moving ? null : () => _step(StepDirection.down)),
          const SizedBox(width: 5),
          cell(),
        ]),
      ],
    );
  }

  Widget _action(String label, Color color, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: color.withAlpha(90)),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ),
    );
  }
}
