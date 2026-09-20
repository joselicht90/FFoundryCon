import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/chat_message.dart';
import '../../../repositories/foundry_repository.dart';

/// Barra "Aplicar daño" del DM (Completo / Mitad / Doble / Curar) sobre los
/// objetivos golpeados por una tirada. Usada en el chat y en el mini-log de
/// combate.
class ApplyDamageBar extends ConsumerStatefulWidget {
  final ApplyDamage apply;
  const ApplyDamageBar({super.key, required this.apply});

  @override
  ConsumerState<ApplyDamageBar> createState() => _ApplyDamageBarState();
}

class _ApplyDamageBarState extends ConsumerState<ApplyDamageBar> {
  bool _busy = false;

  Future<void> _apply(double mult, String label) async {
    if (_busy) return;
    setState(() => _busy = true);
    final a = widget.apply;
    try {
      await ref.read(foundryRepositoryProvider).applyDamage(
            a.targets.map((t) => t.tokenId).toList(),
            damages: a.damages.isNotEmpty ? a.damages : null,
            amount: a.total,
            multiplier: mult,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label → ${a.targets.length} objetivo(s)')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo aplicar: $e')));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.apply;
    final names = a.targets.map((t) => t.name).join(', ');
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 8, 11, 9),
      decoration: BoxDecoration(
        color: AppColors.red.withAlpha(20),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.red.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bloodtype, size: 15, color: AppColors.red),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Aplicar ${a.total} a: $names',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.listText)),
              ),
              if (_busy)
                const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.red)),
            ],
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _chip('Completo', () => _apply(1, 'Daño completo')),
              _chip('Mitad', () => _apply(0.5, 'Mitad de daño')),
              _chip('Doble', () => _apply(2, 'Daño doble')),
              _chip('Curar', () => _apply(-1, 'Curación'), heal: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, VoidCallback onTap, {bool heal = false}) {
    final c = heal ? AppColors.green : AppColors.red;
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: _busy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: c.withAlpha(28),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: c.withAlpha(120)),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c)),
      ),
    );
  }
}
