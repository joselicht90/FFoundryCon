import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/reader_events.dart';
import '../models/foundry_actor.dart';
import '../repositories/foundry_repository.dart';

/// Dashboard del DM: hojas completas de todos los personajes jugadores, en vivo
/// (escucha el WS `type: 'actor'` y hace poll de respaldo).
class DmPartyController extends AsyncNotifier<List<FoundryActor>> {
  Timer? _poll;
  bool _disposed = false;

  @override
  Future<List<FoundryActor>> build() async {
    ref.onDispose(() {
      _disposed = true;
      _poll?.cancel();
    });
    ref.listen(readerEventsProvider, (_, next) {
      final m = next.valueOrNull;
      if (m == null || m['type'] != 'actor') return;
      final data = m['data'] as Map<String, dynamic>?;
      if (data == null) return;
      try {
        final updated = FoundryActor.fromJson(data);
        final cur = state.valueOrNull ?? const <FoundryActor>[];
        final idx = cur.indexWhere((a) => a.id == updated.id);
        if (idx >= 0) {
          final list = [...cur];
          list[idx] = updated;
          state = AsyncData(list);
        }
      } catch (_) {/* ignore */}
    });
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _reload());
    return _load();
  }

  Future<List<FoundryActor>> _load() async {
    final repo = ref.read(foundryRepositoryProvider);
    final summaries = await repo.getActors();
    final actors = <FoundryActor>[];
    for (final s in summaries) {
      try {
        actors.add(await repo.getActor(s.id));
      } catch (_) {/* saltear el que falle */}
    }
    return actors;
  }

  Future<void> _reload() async {
    if (_disposed) return;
    try {
      final fresh = await _load();
      if (!_disposed) state = AsyncData(fresh);
    } catch (_) {/* silencioso */}
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}

final dmPartyProvider =
    AsyncNotifierProvider<DmPartyController, List<FoundryActor>>(
        DmPartyController.new);
