import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';

import '../../controllers/connection_controller.dart';
import '../../core/network/reader_url_provider.dart';
import '../world/world_select_screen.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    final saved = ref.read(readerUrlProvider);
    if (saved != null) _controller.text = saved;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final ok = await ref
        .read(connectionControllerProvider.notifier)
        .connect(_controller.text);
    if (!mounted || !ok) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const WorldSelectScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(connectionControllerProvider);
    final loading = state.isLoading;
    final error = state.hasError ? state.error.toString() : null;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.1,
            colors: [Color(0xFF211F18), AppColors.bg],
            stops: [0.0, 0.6],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              const Icon(Icons.shield_moon, size: 64, color: AppColors.gold),
              const SizedBox(height: 18),
              const Text(
                'FOUNDRY',
                style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 3,
                    color: AppColors.goldDim,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 3),
              Text(
                'FFoundry',
                style: cinzel(28, color: AppColors.name),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Companion para Foundry VTT',
                style: TextStyle(color: AppColors.label),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 44),
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'Reader URL',
                  hintText: 'https://reader.r4spi.com',
                  prefixIcon: Icon(Icons.link),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                onSubmitted: (_) => _connect(),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: loading ? null : _connect,
                icon: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.bolt),
                label: Text(loading ? 'Conectando...' : 'Conectar'),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
