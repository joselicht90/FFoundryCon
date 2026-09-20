import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/rule.dart';
import '../repositories/foundry_repository.dart';

/// Reglas de la casa (CRUD contra el reader/Mongo).
class RulesController extends AsyncNotifier<List<Rule>> {
  @override
  Future<List<Rule>> build() =>
      ref.read(foundryRepositoryProvider).getRules();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(foundryRepositoryProvider).getRules(),
    );
  }

  /// Crea (id null) o edita una regla y refleja el resultado en la lista.
  Future<void> save({String? id, required String title, required String body}) async {
    final saved = await ref
        .read(foundryRepositoryProvider)
        .saveRule(id: id, title: title, body: body);
    final cur = [...(state.valueOrNull ?? const <Rule>[])];
    final idx = cur.indexWhere((r) => r.id == saved.id);
    if (idx >= 0) {
      cur[idx] = saved;
    } else {
      cur.insert(0, saved);
    }
    state = AsyncData(cur);
  }

  Future<void> delete(String id) async {
    await ref.read(foundryRepositoryProvider).deleteRule(id);
    final cur = [...(state.valueOrNull ?? const <Rule>[])]
      ..removeWhere((r) => r.id == id);
    state = AsyncData(cur);
  }
}

final rulesControllerProvider =
    AsyncNotifierProvider<RulesController, List<Rule>>(RulesController.new);
