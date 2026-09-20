import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Logger global de la app. Usalo en cualquier lado: `logger.d/i/w/e(...)`.
///
/// En release solo loguea warnings y errores; en debug, todo.
final Logger logger = Logger(
  level: kReleaseMode ? Level.warning : Level.debug,
  printer: PrettyPrinter(
    methodCount: 1, // frames de stack en logs normales
    errorMethodCount: 8, // frames cuando hay un error/excepción
    lineLength: 100,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);
