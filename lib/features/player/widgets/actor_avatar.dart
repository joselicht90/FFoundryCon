import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';

import '../../../core/network/image_url.dart';
import '../../../core/network/reader_url_provider.dart';

/// Foto del personaje (servida por el reader). Cae a la inicial si no hay img.
class ActorAvatar extends ConsumerWidget {
  final String? img;
  final String name;
  final double radius;

  const ActorAvatar({
    super.key,
    required this.img,
    required this.name,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = foundryImageUrl(ref.watch(readerUrlProvider), img);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.gold.withAlpha(60),
      backgroundImage: url != null ? NetworkImage(url) : null,
      child: url == null
          ? Text(initial, style: TextStyle(fontSize: radius * 0.8))
          : null,
    );
  }
}

class ProfDot extends StatelessWidget {
  final num level; // 0, 0.5, 1, 2
  final double size;
  const ProfDot(this.level, {super.key, this.size = 12});

  @override
  Widget build(BuildContext context) {
    if (level >= 2) {
      return Icon(Icons.brightness_7, size: size, color: AppColors.gold);
    }
    if (level >= 1) {
      return Icon(Icons.circle, size: size * 0.85, color: AppColors.green);
    }
    if (level > 0) {
      return Icon(Icons.circle, size: size * 0.85, color: AppColors.orange);
    }
    return Icon(Icons.circle_outlined, size: size * 0.85, color: Colors.grey.shade600);
  }
}
