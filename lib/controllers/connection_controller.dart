import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/reader_url_provider.dart';
import '../repositories/foundry_repository.dart';

/// Estado del intento de conexión en la pantalla de setup.
class ConnectionController extends AsyncNotifier<void> {
  @override
  void build() {}

  /// Hace ping a [url]; si responde, la fija como URL global del reader.
  /// Devuelve true en éxito.
  Future<bool> connect(String url) async {
    state = const AsyncLoading();
    final clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    final ok = await ref.read(foundryRepositoryProvider).ping(clean);
    if (ok) {
      await ref.read(readerUrlProvider.notifier).set(clean);
      state = const AsyncData(null);
    } else {
      state = AsyncError(
        'No se pudo conectar. Verificá la URL y que el reader esté corriendo.',
        StackTrace.current,
      );
    }
    return ok;
  }
}

final connectionControllerProvider =
    AsyncNotifierProvider<ConnectionController, void>(ConnectionController.new);
