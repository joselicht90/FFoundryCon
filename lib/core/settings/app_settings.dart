import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../storage/prefs_provider.dart';

const _kAutoRollDamage = 'autoRollDamage';
const _kKeepScreenOn = 'keepScreenOn';

/// Preferencias de la app (persisten en SharedPreferences).
class AppSettings {
  /// Si true, al atacar MidiQOL tira el daño automáticamente (1 paso).
  /// Si false, el daño se tira aparte (2 pasos).
  final bool autoRollDamage;

  /// Si true, mantiene la pantalla del teléfono encendida con la app abierta.
  final bool keepScreenOn;

  const AppSettings({this.autoRollDamage = true, this.keepScreenOn = false});

  AppSettings copyWith({bool? autoRollDamage, bool? keepScreenOn}) => AppSettings(
        autoRollDamage: autoRollDamage ?? this.autoRollDamage,
        keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      );
}

class AppSettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final prefs = ref.read(prefsProvider);
    final s = AppSettings(
      // Por defecto ON: al atacar se tira el daño en el mismo paso.
      autoRollDamage: prefs.getBool(_kAutoRollDamage) ?? true,
      keepScreenOn: prefs.getBool(_kKeepScreenOn) ?? false,
    );
    // Aplicar el wake lock al arrancar según lo guardado.
    _applyWakelock(s.keepScreenOn);
    return s;
  }

  void _applyWakelock(bool on) {
    try {
      WakelockPlus.toggle(enable: on);
    } catch (_) {/* plataforma sin soporte */}
  }

  Future<void> setAutoRollDamage(bool value) async {
    await ref.read(prefsProvider).setBool(_kAutoRollDamage, value);
    state = state.copyWith(autoRollDamage: value);
  }

  Future<void> setKeepScreenOn(bool value) async {
    await ref.read(prefsProvider).setBool(_kKeepScreenOn, value);
    _applyWakelock(value);
    state = state.copyWith(keepScreenOn: value);
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(AppSettingsController.new);
