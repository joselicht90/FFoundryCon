import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/logging/app_logger.dart';
import 'core/storage/prefs_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Errores del framework (build/layout/paint) → al logger en vez de tragárselos.
  FlutterError.onError = (details) {
    logger.e(
      'FlutterError: ${details.summary}',
      error: details.exception,
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  };

  // Errores async no atrapados (futures sin await, callbacks, etc.).
  PlatformDispatcher.instance.onError = (error, stack) {
    logger.e('Uncaught', error: error, stackTrace: stack);
    return true;
  };

  final prefs = await SharedPreferences.getInstance();
  logger.i('App iniciada (debug=$kDebugMode)');

  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
      ],
      child: const FFoundryConApp(),
    ),
  );
}
