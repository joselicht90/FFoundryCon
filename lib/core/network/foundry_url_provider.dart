import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/prefs_provider.dart';

const _kFoundryUrlKey = 'foundryUrl';

/// URL base de Foundry VTT (no del reader), para la tab que carga la hoja real
/// en una WebView. Persiste en SharedPreferences; null si no está configurada.
class FoundryUrlController extends Notifier<String?> {
  @override
  String? build() => ref.read(prefsProvider).getString(_kFoundryUrlKey);

  /// Guarda la URL normalizada. Solo acepta `https://host[...]` (la WebView
  /// lleva la sesión de Foundry); devuelve false si no es válida. Vacía = borrar.
  Future<bool> set(String url) async {
    final clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (clean.isEmpty) {
      await clear();
      return true;
    }
    final uri = Uri.tryParse(clean);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return false;
    await ref.read(prefsProvider).setString(_kFoundryUrlKey, clean);
    state = clean;
    return true;
  }

  Future<void> clear() async {
    await ref.read(prefsProvider).remove(_kFoundryUrlKey);
    state = null;
  }
}

final foundryUrlProvider = NotifierProvider<FoundryUrlController, String?>(
  FoundryUrlController.new,
);
