import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/actor_controller.dart';
import '../../../controllers/chat_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/chat_message.dart';
import 'roll_card.dart';

/// Hoja persistente tras castear/atacar (imita la tarjeta de chat de Foundry):
/// permite re-tirar ataque/daño del mismo cast sin volver a gastar el
/// recurso (`action:'attack'`/`'damage'` ya no consumen, ver
/// `docs/tasks/cast-result-sheet.md`), con el listado de tiradas de la sesión.
Future<void> showCastResultSheet(
  BuildContext c,
  WidgetRef ref, {
  required String itemId,
  required String name,
  String? activityId,
  List<String> targetIds = const [],
  bool hasAttack = true,
  bool hasDamage = true,
  String? ownerId,
}) {
  return showModalBottomSheet(
    context: c,
    isDismissible: true,
    backgroundColor: AppColors.bgAlt,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _CastResultSheet(
      itemId: itemId,
      name: name,
      activityId: activityId,
      targetIds: targetIds,
      hasAttack: hasAttack,
      hasDamage: hasDamage,
      ownerId: ownerId,
    ),
  );
}

class _CastResultSheet extends ConsumerStatefulWidget {
  final String itemId;
  final String name;
  final String? activityId;
  final List<String> targetIds;
  final bool hasAttack;
  final bool hasDamage;
  final String? ownerId;

  const _CastResultSheet({
    required this.itemId,
    required this.name,
    this.activityId,
    this.targetIds = const [],
    this.hasAttack = true,
    this.hasDamage = true,
    this.ownerId,
  });

  @override
  ConsumerState<_CastResultSheet> createState() => _CastResultSheetState();
}

class _CastResultSheetState extends ConsumerState<_CastResultSheet> {
  late final int _sessionStart;
  late final String? _authorName;
  bool _attackBusy = false;
  bool _damageBusy = false;

  @override
  void initState() {
    super.initState();
    // Colchón de reloj (mismo margen que usa el poll de respaldo del chat).
    _sessionStart = DateTime.now().millisecondsSinceEpoch - 2000;
    _authorName = ref.read(actorControllerProvider).valueOrNull?.name;
  }

  Future<void> _fire(String action, bool busyFlag) async {
    if (_attackBusy || _damageBusy) return;
    setState(() {
      if (action == 'attack') {
        _attackBusy = true;
      } else {
        _damageBusy = true;
      }
    });
    try {
      await ref.read(actorControllerProvider.notifier).use(
            widget.itemId,
            action: action,
            targetIds: widget.targetIds,
            activityId: widget.activityId,
            actorId: widget.ownerId,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          if (action == 'attack') {
            _attackBusy = false;
          } else {
            _damageBusy = false;
          }
        });
      }
    }
  }

  bool _belongsToSession(ChatMessage m) {
    if (!m.isRoll) return false;
    if (m.timestamp < _sessionStart) return false;
    if (_authorName != null && m.author != _authorName) return false;
    final flavor = m.flavor;
    if (flavor == null) return false;
    return flavor == 'Ataque' || flavor == 'Daño' || flavor.startsWith(widget.name);
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider).valueOrNull ?? const [];
    final rolls = chat.where(_belongsToSession).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.name,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.name)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (widget.hasAttack) ...[
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.gold, foregroundColor: Colors.black),
                      onPressed: _attackBusy ? null : () => _fire('attack', _attackBusy),
                      child: Text(_attackBusy ? '…' : 'ATAQUE'),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                if (widget.hasDamage)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _damageBusy ? null : () => _fire('damage', _damageBusy),
                      child: Text(_damageBusy ? '…' : 'DAÑO'),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
              child: rolls.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Sin tiradas todavía',
                          style: TextStyle(fontSize: 12, color: AppColors.label)),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: rolls.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final m = rolls[i];
                        return RollCardView(
                          flavor: m.flavor,
                          formula: m.formula,
                          total: m.total,
                          dice: m.dice,
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
