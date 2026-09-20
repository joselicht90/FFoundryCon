import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Inyectado en `main()` con la instancia ya resuelta vía
/// `overrideWithValue`. Cualquier provider que necesite prefs lo lee de acá.
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider debe ser sobreescrito'),
);
