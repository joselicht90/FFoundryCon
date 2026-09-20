import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/reader_events.dart';
import '../models/foundry_actor.dart';
import '../models/foundry_combat.dart';
import '../repositories/foundry_repository.dart';

/// Estado del combate en vivo: escucha el WS compartido (`type: 'combat'`) y
/// hace poll de respaldo cada 4s por si el WS falla.
class CombatController extends AsyncNotifier<FoundryCombat> {
  Timer? _poll;
  bool _disposed = false;

  @override
  Future<FoundryCombat> build() async {
    ref.onDispose(() {
      _disposed = true;
      _poll?.cancel();
    });
    ref.listen(readerEventsProvider, (_, next) {
      final m = next.valueOrNull;
      if (m == null || m['type'] != 'combat') return;
      final data = m['data'];
      if (data is Map<String, dynamic>) {
        state = AsyncData(FoundryCombat.fromJson(data));
      }
    });
    _startPolling();
    try {
      return await ref.read(foundryRepositoryProvider).getCombat();
    } catch (_) {
      return const FoundryCombat();
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _pollOnce());
  }

  Future<void> _pollOnce() async {
    if (_disposed) return;
    try {
      final fresh = await ref.read(foundryRepositoryProvider).getCombat();
      if (!_disposed) state = AsyncData(fresh);
    } catch (_) {/* silencioso */}
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(foundryRepositoryProvider).getCombat(),
    );
  }

  /// El jugador termina su turno; refleja el combate devuelto por Foundry.
  Future<void> endTurn(String actorId) async {
    final fresh = await ref.read(foundryRepositoryProvider).endTurn(actorId);
    state = AsyncData(fresh);
  }

  /// Control de turnos del DM (next/prev/nextRound/prevRound/start/end).
  Future<void> control(String dir) async {
    final fresh = await ref.read(foundryRepositoryProvider).combatControl(dir);
    state = AsyncData(fresh);
  }
}

final combatControllerProvider =
    AsyncNotifierProvider<CombatController, FoundryCombat>(CombatController.new);

/// Hoja del actor de un combatiente (para el detalle del DM). Se recarga sola
/// cuando cambia el combatiente seleccionado.
final combatantActorProvider =
    FutureProvider.family.autoDispose<FoundryActor, String>(
  (ref, combatantId) =>
      ref.read(foundryRepositoryProvider).getCombatantActor(combatantId),
);
