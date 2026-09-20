import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Scaffold de las pantallas de intro (world/character select), con el fondo
/// radial y el header (label chiquito + título Cinzel) del diseño de referencia.
class SceneScaffold extends StatelessWidget {
  final String overline;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final Widget child;

  const SceneScaffold({
    super.key,
    required this.overline,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1),
            radius: 1.1,
            colors: [Color(0xFF1C1A16), AppColors.bg],
            stops: [0.0, 0.6],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (leading != null || actions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      leading ?? const SizedBox(width: 8),
                      const Spacer(),
                      ...actions,
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  children: [
                    Text(
                      overline.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 3,
                        color: AppColors.goldDim,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(title,
                        textAlign: TextAlign.center,
                        style: cinzel(26, color: AppColors.name)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitle!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: AppColors.label)),
                    ],
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
