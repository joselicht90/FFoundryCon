import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/prefs_provider.dart';

const _kReaderUrlKey = 'readerUrl';

/// URL por defecto del reader (hardcodeada). Se puede cambiar desde Settings.
const kDefaultReaderUrl = 'https://reader.r4spi.com';

/// URL base del reader. Persiste en SharedPreferences y, al cambiar, hace que
/// `dioProvider` se reconstruya con la nueva base. Si no hay nada guardado, usa
/// [kDefaultReaderUrl] para no obligar a configurarla al arrancar.
class ReaderUrlController extends Notifier<String?> {
  @override
  String? build() =>
      ref.read(prefsProvider).getString(_kReaderUrlKey) ?? kDefaultReaderUrl;

  Future<void> set(String url) async {
    final clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    await ref.read(prefsProvider).setString(_kReaderUrlKey, clean);
    state = clean;
  }

  /// Vuelve a la URL por defecto (borra la guardada).
  Future<void> clear() async {
    await ref.read(prefsProvider).remove(_kReaderUrlKey);
    state = kDefaultReaderUrl;
  }
}

final readerUrlProvider =
    NotifierProvider<ReaderUrlController, String?>(ReaderUrlController.new);
