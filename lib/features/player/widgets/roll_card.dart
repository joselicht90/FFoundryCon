import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Tarjeta de tirada, usada igual en el chat y en el popup de resultado.
class RollCardView extends StatelessWidget {
  final String? author;
  final String? authorColor;
  final String? time;
  final bool? isPrivate;
  final String? flavor;
  final String? formula;
  final int? total;
  final List<int> dice;

  const RollCardView({
    super.key,
    this.author,
    this.authorColor,
    this.time,
    this.isPrivate,
    this.flavor,
    this.formula,
    this.total,
    this.dice = const [],
  });

  static Color _parse(String? hex, Color fallback) {
    if (hex == null) return fallback;
    try {
      return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authorC = _parse(authorColor, AppColors.gold);
    final isD20 = (formula ?? '').toLowerCase().contains('d20');
    final nat = dice.isNotEmpty ? dice.reduce(max) : null;
    final crit = isD20 && nat == 20;
    final fail = isD20 && nat == 1;
    final border = crit
        ? AppColors.green
        : fail
            ? AppColors.red
            : AppColors.gold.withAlpha(64);
    final totalColor = crit
        ? AppColors.green
        : fail
            ? AppColors.red
            : AppColors.gold;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1D22),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (author != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: const BoxDecoration(
                color: Color(0x06FFFFFF),
                border: Border(bottom: BorderSide(color: Color(0x0DFFFFFF))),
              ),
              child: Row(
                children: [
                  Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: authorC)),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(author!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w600, color: authorC)),
                  ),
                  if (isPrivate == true)
                    const Padding(
                      padding: EdgeInsets.only(right: 5),
                      child: Icon(Icons.lock, size: 11, color: AppColors.orange),
                    ),
                  if (time != null)
                    Text(time!,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF6F6A60))),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (flavor != null)
                            Text(flavor!,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.name)),
                          if (formula != null) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.panelAlt,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.gold.withAlpha(46)),
                              ),
                              child: Text(formula!,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFA69F8F))),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 54,
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border),
                        gradient: const RadialGradient(
                          center: Alignment(0, -0.4),
                          colors: [Color(0xFF2E3138), Color(0xFF14161A)],
                        ),
                      ),
                      child: Text('${total ?? '?'}', style: cinzel(24, color: totalColor)),
                    ),
                  ],
                ),
                if (dice.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [for (final d in dice) _die(d, isD20)],
                  ),
                ],
                if (crit || fail) ...[
                  const SizedBox(height: 8),
                  Text(crit ? '¡CRÍTICO!' : 'PIFIA',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: totalColor)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _die(int v, bool isD20) {
    final crit = isD20 && v == 20;
    final fail = isD20 && v == 1;
    final c = crit
        ? AppColors.green
        : fail
            ? AppColors.red
            : const Color(0xFFA69F8F);
    return Container(
      constraints: const BoxConstraints(minWidth: 26),
      height: 26,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: c.withAlpha(28),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: c.withAlpha(110)),
      ),
      child: Text('$v',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c)),
    );
  }
}
