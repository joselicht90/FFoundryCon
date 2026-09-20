import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/reader_url_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/setup/setup_screen.dart';
import 'features/world/world_select_screen.dart';

class FFoundryConApp extends ConsumerWidget {
  const FFoundryConApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasUrl = ref.watch(readerUrlProvider) != null;
    return MaterialApp(
      title: 'FFoundry',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // La URL del reader tiene default hardcodeado, así que normalmente
      // entra directo a la selección de mundo (se cambia desde Settings).
      home: hasUrl ? const WorldSelectScreen() : const SetupScreen(),
    );
  }
}
