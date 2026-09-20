import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Ícono de dado de 20 caras (hexágono con cara superior triangular).
class D20Icon extends StatelessWidget {
  final double size;
  final Color color;
  const D20Icon({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _D20Painter(color));
}

class _D20Painter extends CustomPainter {
  final Color color;
  _D20Painter(this.color);

  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final r = s.width / 2 * 0.96;
    Offset v(double deg) {
      final a = deg * pi / 180;
      return c + Offset(cos(a) * r, sin(a) * r);
    }

    final hex = [for (var i = 0; i < 6; i++) v(-90 + i * 60)];
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * 0.08
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..addPolygon(hex, true)
      ..addPolygon([hex[0], hex[2], hex[4]], true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _D20Painter old) => old.color != color;
}

/// Ícono de espada (para daño).
class SwordIcon extends StatelessWidget {
  final double size;
  final Color color;
  const SwordIcon({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _SwordPainter(color));
}

class _SwordPainter extends CustomPainter {
  final Color color;
  _SwordPainter(this.color);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Hoja en diagonal (de abajo-izq a arriba-der) con punta.
    canvas.drawLine(Offset(w * 0.28, h * 0.72), Offset(w * 0.86, h * 0.14), p);
    // Guardia (perpendicular a la empuñadura).
    canvas.drawLine(Offset(w * 0.14, h * 0.62), Offset(w * 0.40, h * 0.88), p);
    // Empuñadura.
    canvas.drawLine(Offset(w * 0.18, h * 0.82), Offset(w * 0.30, h * 0.94), p);
  }

  @override
  bool shouldRepaint(covariant _SwordPainter old) => old.color != color;
}

/// Campo de búsqueda para filtrar listas (spells / items).
class SheetSearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const SheetSearchField({super.key, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      autocorrect: false,
      style: const TextStyle(fontSize: 14, color: AppColors.parchment),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.label, fontSize: 13),
        prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.label),
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: AppColors.gold.withAlpha(46)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AppColors.gold),
        ),
      ),
    );
  }
}

/// Card base del diseño: fondo #1c1e23, borde blanco .06, radio 14.
class SheetCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final Color? color;
  final double radius;
  final VoidCallback? onTap;

  const SheetCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderColor,
    this.color,
    this.radius = 14,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? AppColors.cardBorder),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return InkWell(
      borderRadius: BorderRadius.circular(radius),
      onTap: onTap,
      child: box,
    );
  }
}

/// Encabezado de sección: LABEL dorado + línea + trailing opcional.
class SectionHeader extends StatelessWidget {
  final String label;
  final String? trailing;
  final EdgeInsetsGeometry margin;
  const SectionHeader(this.label,
      {super.key,
      this.trailing,
      this.margin = const EdgeInsets.fromLTRB(2, 18, 2, 9)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 1.8,
              color: AppColors.gold,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: AppColors.gold.withAlpha(40))),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(trailing!,
                style: const TextStyle(fontSize: 10, color: AppColors.label)),
          ],
        ],
      ),
    );
  }
}

/// Caja de estadística (ARMOR / INITIATIVE / SPEED / pasivas).
class StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final double valueSize;
  final VoidCallback? onTap;
  const StatBox({
    super.key,
    required this.label,
    required this.value,
    this.valueColor = AppColors.name,
    this.valueSize = 24,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SheetCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              letterSpacing: 1.2,
              color: AppColors.label,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(value, style: cinzel(valueSize, color: valueColor)),
        ],
      ),
    );
  }
}

/// Stepper − valor + (modo edición), glifos dorados sobre #2a2d33.
class EditStepper extends StatelessWidget {
  final String value;
  final VoidCallback onDec;
  final VoidCallback onInc;
  final double valueSize;
  const EditStepper({
    super.key,
    required this.value,
    required this.onDec,
    required this.onInc,
    this.valueSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _btn('−', onDec),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(value,
              style: TextStyle(
                  fontSize: valueSize,
                  fontWeight: FontWeight.w700,
                  color: AppColors.name)),
        ),
        _btn('+', onInc),
      ],
    );
  }

  Widget _btn(String glyph, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.panelAlt,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(glyph,
              style: const TextStyle(color: AppColors.gold, fontSize: 17)),
        ),
      );
}

/// Label chiquito en mayúsculas con tracking (reutilizable).
class MicroLabel extends StatelessWidget {
  final String text;
  final Color color;
  const MicroLabel(this.text, {super.key, this.color = AppColors.label});

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          letterSpacing: 1.2,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      );
}
