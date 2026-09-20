import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/connection_controller.dart';
import '../../core/network/reader_url_provider.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: ref.read(readerUrlProvider) ?? kDefaultReaderUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ok =
        await ref.read(connectionControllerProvider.notifier).connect(_controller.text);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conectado · URL guardada')),
      );
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _reset() async {
    await ref.read(readerUrlProvider.notifier).clear();
    if (!mounted) return;
    _controller.text = kDefaultReaderUrl;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(connectionControllerProvider);
    final loading = state.isLoading;
    final error = state.hasError ? state.error.toString() : null;
    final current = ref.watch(readerUrlProvider);
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('SERVIDOR (READER)',
                style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.4,
                    color: AppColors.gold,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Actual: ${current ?? '—'}',
                style: const TextStyle(fontSize: 12, color: AppColors.label)),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.url,
              autocorrect: false,
              style: const TextStyle(color: AppColors.parchment),
              decoration: const InputDecoration(
                labelText: 'Reader URL',
                hintText: kDefaultReaderUrl,
                prefixIcon: Icon(Icons.link),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error, style: const TextStyle(color: AppColors.red, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: loading ? null : _save,
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: Text(loading ? 'Conectando...' : 'Guardar y conectar'),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: loading ? null : _reset,
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('Restaurar URL por defecto'),
            ),
            const SizedBox(height: 28),
            const Text('COMBATE',
                style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.4,
                    color: AppColors.gold,
                    fontWeight: FontWeight.w600)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.gold,
              title: const Text('Auto-tirar daño',
                  style: TextStyle(color: AppColors.listText)),
              subtitle: Text(
                settings.autoRollDamage
                    ? 'Al atacar, MidiQOL tira el daño solo (1 paso)'
                    : 'El daño se tira aparte después del ataque (2 pasos)',
                style: const TextStyle(fontSize: 12, color: AppColors.label),
              ),
              value: settings.autoRollDamage,
              onChanged: (v) =>
                  ref.read(appSettingsProvider.notifier).setAutoRollDamage(v),
            ),
            const SizedBox(height: 6),
            const Text(
              'El "modo mesa" (que el DM tire) se elige por ataque, con el switch en la pantalla de objetivos.',
              style: TextStyle(fontSize: 11, color: AppColors.label),
            ),
            const SizedBox(height: 28),
            const Text('PANTALLA',
                style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.4,
                    color: AppColors.gold,
                    fontWeight: FontWeight.w600)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.gold,
              title: const Text('Mantener pantalla encendida',
                  style: TextStyle(color: AppColors.listText)),
              subtitle: const Text(
                'La pantalla no se apaga mientras la app esté abierta',
                style: TextStyle(fontSize: 12, color: AppColors.label),
              ),
              value: settings.keepScreenOn,
              onChanged: (v) =>
                  ref.read(appSettingsProvider.notifier).setKeepScreenOn(v),
            ),
          ],
        ),
      ),
    );
  }
}
