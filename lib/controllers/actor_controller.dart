import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging/app_logger.dart';
import '../core/network/reader_events.dart';
import '../models/foundry_actor.dart';
import '../repositories/foundry_repository.dart';

/// Lista de personajes del mundo (vía el módulo, requiere GM online).
final actorsProvider = FutureProvider.autoDispose<List<ActorSummary>>(
  (ref) => ref.watch(foundryRepositoryProvider).getActors(),
);

/// Hoja del actor activo + acciones (tirar / editar).
class ActorController extends AsyncNotifier<FoundryActor?> {
  @override
  FoundryActor? build() {
    // Actualización en vivo: si Foundry cambia el personaje abierto, lo aplicamos.
    ref.listen(readerEventsProvider, (_, next) {
      final m = next.valueOrNull;
      if (m == null || m['type'] != 'actor') return;
      final data = m['data'] as Map<String, dynamic>?;
      if (data == null) return;
      final cur = state.valueOrNull;
      if (cur != null && data['id'] == cur.id) {
        try {
          state = AsyncData(FoundryActor.fromJson(data));
        } catch (e, st) {
          logger.w('No pude aplicar el update en vivo del actor',
              error: e, stackTrace: st);
        }
      }
    });
    return null;
  }

  Future<void> load(String actorId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(foundryRepositoryProvider).getActor(actorId),
    );
    if (state.hasError) {
      logger.e('getActor falló al cargar/parsear',
          error: state.error, stackTrace: state.stackTrace);
    }
  }

  Future<void> refresh() async {
    final id = state.valueOrNull?.id;
    if (id != null) await load(id);
  }

  /// Tira una ability/save/skill nativa de dnd5e (va al chat de Foundry).
  /// Devuelve el resultado `{total, formula, dice}`.
  Future<Map<String, dynamic>> roll(RollKind kind, String key, RollMode mode) async {
    final id = state.valueOrNull?.id;
    if (id == null) return {};
    return ref.read(foundryRepositoryProvider).rollActor(id, kind, key, mode);
  }

  /// Edita la sheet y refleja el resultado (el módulo devuelve el actor fresco).
  Future<void> edit(Map<String, dynamic> changes) async {
    final id = state.valueOrNull?.id;
    if (id == null) return;
    final updated =
        await ref.read(foundryRepositoryProvider).updateActor(id, changes);
    state = AsyncData(updated);
  }

  /// Usa/tira un item o conjuro (va al chat de Foundry).
  /// [action]: use | attack | damage. [mode]: normal | adv | dis | crit.
  Future<Map<String, dynamic>> use(String itemId,
      {String action = 'use',
      String mode = 'normal',
      List<String>? targetIds,
      bool? autoDamage,
      bool? manualRoll,
      String? castUserId,
      String? activityId,
      bool? noConsume,
      int? castLevel,
      String? actorId}) async {
    final curId = state.valueOrNull?.id;
    final target = actorId ?? curId;
    if (target == null) return {};
    final res = await ref.read(foundryRepositoryProvider).useItem(target, itemId,
        action: action,
        mode: mode,
        targetIds: targetIds,
        autoDamage: autoDamage,
        manualRoll: manualRoll,
        castUserId: castUserId,
        activityId: activityId,
        noConsume: noConsume,
        castLevel: castLevel);
    // Item de party (otro actor): recargamos el personaje para reflejar el
    // inventario compartido actualizado (ej. consumibles).
    if (actorId != null && actorId != curId) {
      await refresh();
    }
    return res;
  }

  Future<void> manualAttack(String itemId,
      {required List<String> targetIds,
      int? attackTotal,
      int? damageTotal,
      bool crit = false}) async {
    final id = state.valueOrNull?.id;
    if (id == null) return;
    return ref.read(foundryRepositoryProvider).manualAttack(id, itemId,
        targetIds: targetIds,
        attackTotal: attackTotal,
        damageTotal: damageTotal,
        crit: crit);
  }

  /// Equipa/desequipa un item y actualiza la hoja con el actor devuelto.
  /// [actorId] apunta a otro actor (party): en ese caso recargamos el personaje
  /// para reflejar el inventario compartido, en vez de aplicar su DTO.
  Future<void> setEquipped(String itemId, bool equipped, {String? actorId}) async {
    final curId = state.valueOrNull?.id;
    final target = actorId ?? curId;
    if (target == null) return;
    final data = await ref
        .read(foundryRepositoryProvider)
        .setEquipped(target, itemId, equipped);
    if (actorId != null && actorId != curId) {
      await refresh();
    } else if (data.isNotEmpty && data['id'] != null) {
      state = AsyncData(FoundryActor.fromJson(data));
    }
  }

  /// Agrega una entrada del compendio (item/conjuro/dote) al actor y refleja
  /// la hoja actualizada.
  Future<void> addFromCompendium(String pack, String entryId) async {
    final id = state.valueOrNull?.id;
    if (id == null) return;
    final data =
        await ref.read(foundryRepositoryProvider).addToActor(id, pack, entryId);
    if (data.isNotEmpty && data['id'] != null) {
      state = AsyncData(FoundryActor.fromJson(data));
    }
  }

  /// Termina un efecto activo (ej. rage) y refleja la hoja actualizada.
  Future<void> endEffect(String effectId) async {
    final id = state.valueOrNull?.id;
    if (id == null) return;
    final data =
        await ref.read(foundryRepositoryProvider).endEffect(id, effectId);
    if (data.isNotEmpty && data['id'] != null) {
      state = AsyncData(FoundryActor.fromJson(data));
    }
  }

  /// Descanso largo: restaura PV, dados de golpe, usos y espacios de conjuro.
  Future<void> longRest() async {
    final id = state.valueOrNull?.id;
    if (id == null) return;
    final data = await ref.read(foundryRepositoryProvider).longRest(id);
    if (data.isNotEmpty && data['id'] != null) {
      state = AsyncData(FoundryActor.fromJson(data));
    }
  }

  /// Regenera solo los espacios de conjuro (sin descanso).
  Future<void> restoreSpellSlots() async {
    final id = state.valueOrNull?.id;
    if (id == null) return;
    final data = await ref.read(foundryRepositoryProvider).restoreSpellSlots(id);
    if (data.isNotEmpty && data['id'] != null) {
      state = AsyncData(FoundryActor.fromJson(data));
    }
  }

  void clear() => state = const AsyncData(null);
}

/// Modo edición de la sheet (compartido entre todas las páginas/widgets).
class EditModeController extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
  set value(bool v) => state = v;
}

final editModeProvider =
    NotifierProvider<EditModeController, bool>(EditModeController.new);

final actorControllerProvider =
    AsyncNotifierProvider<ActorController, FoundryActor?>(ActorController.new);
