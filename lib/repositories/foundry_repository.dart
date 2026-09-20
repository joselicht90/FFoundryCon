import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/dio_provider.dart';
import '../models/chat_message.dart';
import '../models/compendium.dart';
import '../models/foundry_actor.dart';
import '../models/foundry_combat.dart';
import '../models/npc_plan.dart';
import '../models/foundry_scene.dart';
import '../models/foundry_token.dart';
import '../models/foundry_user.dart';
import '../models/foundry_world.dart';
import '../models/ingest_roll_request.dart';
import '../models/roll_request.dart';
import '../models/rule.dart';

/// Resumen liviano de un actor (para la lista de selección).
class ActorSummary {
  final String id;
  final String name;
  final String? img;
  final List<String> userIds;
  const ActorSummary({
    required this.id,
    required this.name,
    this.img,
    required this.userIds,
  });

  factory ActorSummary.fromJson(Map<String, dynamic> j) => ActorSummary(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Personaje',
        img: j['img'] as String?,
        userIds: (j['userIds'] as List?)?.cast<String>() ?? const [],
      );
}

/// Acceso a la API del reader de Foundry.
abstract class FoundryRepository {
  /// Chequea que un reader en [baseUrl] responda (usado en el setup, antes de
  /// fijar la URL global).
  Future<bool> ping(String baseUrl);

  Future<List<FoundryWorld>> getWorlds();
  Future<List<FoundryUser>> getUsers(String worldId);
  Future<List<FoundryToken>> getTokens();
  Future<({FoundryScene? scene, List<FoundryToken> tokens})> getMap();
  Future<void> stepToken(String tokenId, StepDirection direction, {int spaces});
  Future<void> moveToken(String tokenId, num x, num y);
  Future<void> setTargets(List<String> tokenIds);
  Future<void> sendRoll(RollRequest roll);

  /// Estado del combate activo (orden de turnos, ronda, turno actual).
  Future<FoundryCombat> getCombat();

  /// El jugador termina su turno (el módulo valida que sea su turno).
  Future<FoundryCombat> endTurn(String actorId);

  /// Control de combate del DM: dir = next|prev|nextRound|prevRound|start|end.
  Future<FoundryCombat> combatControl(String dir);

  /// Hoja completa del actor de un combatiente (para que el DM vea enemigos).
  Future<FoundryActor> getCombatantActor(String combatantId);

  // --- IA de NPC (experimental) ---
  /// Decide (sin ejecutar) la acción de un NPC combatiente.
  Future<NpcPlan> npcPlan(String combatantId);
  /// Ejecuta un plan devuelto por [npcPlan].
  Future<void> npcExecute(Map<String, dynamic> plan);
  /// Activa/desactiva el modo autónomo global.
  Future<void> setAutonomousNpc(bool value);

  /// El DM aplica daño (o cura) a tokens. multiplier: 1=completo, 0.5=mitad,
  /// 2=doble, -1=curar. [damages] es el desglose tipado (opcional).
  Future<void> applyDamage(List<String> targetIds,
      {List<Map<String, dynamic>>? damages, int? amount, double multiplier});

  // --- Sheet de Foundry (vía command-queue, requiere GM online) ---
  Future<List<ActorSummary>> getActors();
  Future<FoundryActor> getActor(String actorId);
  Future<Map<String, dynamic>> rollActor(
      String actorId, RollKind kind, String key, RollMode mode);
  Future<FoundryActor> updateActor(String actorId, Map<String, dynamic> changes);
  Future<Map<String, dynamic>> useItem(String actorId, String itemId,
      {String action,
      String mode,
      List<String>? targetIds,
      bool? autoDamage,
      bool? manualRoll,
      String? castUserId,
      String? activityId,
      bool? noConsume,
      int? castLevel});

  /// Modo "dados en mesa": postea ataque/daño manuales al chat de Foundry.
  Future<void> manualAttack(String actorId, String itemId,
      {required List<String> targetIds, int? attackTotal, int? damageTotal, bool crit});

  /// Equipa/desequipa un item. Devuelve el actor actualizado.
  Future<Map<String, dynamic>> setEquipped(String actorId, String itemId, bool equipped);

  /// Termina un efecto activo (ej. rage). Devuelve el actor actualizado.
  Future<Map<String, dynamic>> endEffect(String actorId, String effectId);
  Future<void> logRoll(Map<String, dynamic> roll);

  // --- Compendio ---
  Future<List<CompendiumPack>> compendiumPacks();
  Future<List<CompendiumEntry>> compendiumIndex(String pack);
  Future<List<CompendiumEntry>> compendiumSearch(String query, {String? type});
  Future<CompendiumDetail> compendiumEntry(String pack, String entryId);

  /// Agrega una entrada del compendio al actor. Devuelve el actor actualizado.
  Future<Map<String, dynamic>> addToActor(String actorId, String pack, String entryId);

  /// Descanso largo (restaura PV, dados de golpe, usos y slots).
  Future<Map<String, dynamic>> longRest(String actorId);

  /// Regenera solo los espacios de conjuro.
  Future<Map<String, dynamic>> restoreSpellSlots(String actorId);

  // --- Chat ---
  Future<List<ChatMessage>> getChat({int? since, int limit});
  Future<void> sendChat(Map<String, dynamic> body);
  Future<void> clearChat();

  // --- Reglas de la casa (Mongo) ---
  Future<List<Rule>> getRules();
  Future<Rule> saveRule({String? id, required String title, required String body});
  Future<void> deleteRule(String id);
}

class DioFoundryRepository implements FoundryRepository {
  final Dio _dio;
  DioFoundryRepository(this._dio);

  @override
  Future<bool> ping(String baseUrl) async {
    try {
      final dio = buildDio(baseUrl);
      final res = await dio.get('/health');
      dio.close();
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<FoundryWorld>> getWorlds() async {
    final res = await _dio.get('/api/worlds');
    final data = res.data as Map<String, dynamic>;
    final list = (data['worlds'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return list.map(FoundryWorld.fromJson).toList();
  }

  @override
  Future<List<FoundryUser>> getUsers(String worldId) async {
    final res = await _dio.get('/api/worlds/$worldId/users');
    final data = res.data as Map<String, dynamic>;
    final list = (data['users'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return list.map(FoundryUser.fromJson).toList();
  }

  @override
  Future<List<FoundryToken>> getTokens() async {
    final res = await _dio.get('/api/tokens');
    final data = res.data as Map<String, dynamic>;
    final tokens = (data['tokens'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return tokens.map(FoundryToken.fromJson).toList();
  }

  @override
  Future<({FoundryScene? scene, List<FoundryToken> tokens})> getMap() async {
    final res = await _dio.get('/api/tokens');
    final data = res.data as Map<String, dynamic>;
    final tokens = (data['tokens'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final sceneJson = data['scene'] as Map<String, dynamic>?;
    return (
      scene: sceneJson != null ? FoundryScene.fromJson(sceneJson) : null,
      tokens: tokens.map(FoundryToken.fromJson).toList(),
    );
  }

  @override
  Future<void> stepToken(
    String tokenId,
    StepDirection direction, {
    int spaces = 1,
  }) async {
    await _dio.post(
      '/api/tokens/$tokenId/step',
      data: {'direction': direction.wire, 'spaces': spaces},
    );
  }

  @override
  Future<List<ActorSummary>> getActors() async {
    final res = await _dio.get('/api/actors');
    final data = res.data as Map<String, dynamic>;
    final list = (data['actors'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return list.map(ActorSummary.fromJson).toList();
  }

  @override
  Future<FoundryActor> getActor(String actorId) async {
    final res = await _dio.get('/api/actors/$actorId');
    return FoundryActor.fromJson(res.data as Map<String, dynamic>);
  }

  @override
  Future<Map<String, dynamic>> rollActor(
    String actorId,
    RollKind kind,
    String key,
    RollMode mode,
  ) async {
    final res = await _dio.post(
      '/api/actors/$actorId/roll',
      data: {'kind': kind.wire, 'key': key, 'mode': mode.wire},
    );
    return res.data is Map ? (res.data as Map).cast<String, dynamic>() : {};
  }

  @override
  Future<FoundryActor> updateActor(
    String actorId,
    Map<String, dynamic> changes,
  ) async {
    final res = await _dio.post(
      '/api/actors/$actorId/update',
      data: {'changes': changes},
    );
    return FoundryActor.fromJson(res.data as Map<String, dynamic>);
  }

  @override
  Future<void> moveToken(String tokenId, num x, num y) async {
    await _dio.post('/api/tokens/$tokenId/move',
        data: {'x': x.round(), 'y': y.round()});
  }

  @override
  Future<void> setTargets(List<String> tokenIds) async {
    await _dio.post('/api/targets', data: {'tokenIds': tokenIds});
  }

  @override
  Future<FoundryCombat> getCombat() async {
    final res = await _dio.get('/api/combat');
    return FoundryCombat.fromJson(res.data as Map<String, dynamic>);
  }

  @override
  Future<FoundryCombat> endTurn(String actorId) async {
    final res = await _dio.post('/api/combat/end-turn', data: {'actorId': actorId});
    return FoundryCombat.fromJson(res.data as Map<String, dynamic>);
  }

  @override
  Future<FoundryCombat> combatControl(String dir) async {
    final res = await _dio.post('/api/combat/control', data: {'dir': dir});
    return FoundryCombat.fromJson(res.data as Map<String, dynamic>);
  }

  @override
  Future<FoundryActor> getCombatantActor(String combatantId) async {
    final res = await _dio.get('/api/combat/combatant',
        queryParameters: {'id': combatantId});
    return FoundryActor.fromJson(res.data as Map<String, dynamic>);
  }

  @override
  Future<NpcPlan> npcPlan(String combatantId) async {
    final res = await _dio.post('/api/npc/plan', data: {'combatantId': combatantId});
    return NpcPlan.fromJson((res.data as Map).cast<String, dynamic>());
  }

  @override
  Future<void> npcExecute(Map<String, dynamic> plan) async {
    await _dio.post('/api/npc/execute', data: {'plan': plan});
  }

  @override
  Future<void> setAutonomousNpc(bool value) async {
    await _dio.post('/api/npc/autonomous', data: {'value': value});
  }

  @override
  Future<void> applyDamage(List<String> targetIds,
      {List<Map<String, dynamic>>? damages,
      int? amount,
      double multiplier = 1}) async {
    await _dio.post('/api/apply-damage', data: {
      'targetIds': targetIds,
      if (damages != null) 'damages': damages,
      if (amount != null) 'amount': amount,
      'multiplier': multiplier,
    });
  }

  @override
  Future<Map<String, dynamic>> useItem(String actorId, String itemId,
      {String action = 'use',
      String mode = 'normal',
      List<String>? targetIds,
      bool? autoDamage,
      bool? manualRoll,
      String? castUserId,
      String? activityId,
      bool? noConsume,
      int? castLevel}) async {
    final res = await _dio.post('/api/actors/$actorId/use', data: {
      'itemId': itemId,
      'action': action,
      'mode': mode,
      // Si se pasan targets (aunque sea vacío) → flujo MidiQOL.
      if (targetIds != null) 'targetIds': targetIds,
      if (autoDamage != null) 'autoDamage': autoDamage,
      if (manualRoll != null) 'manualRoll': manualRoll,
      // Si está el jugador logueado en Foundry, castea en SU cliente.
      if (castUserId != null) 'castUserId': castUserId,
      // Activity específica elegida (items con varias opciones).
      if (activityId != null) 'activityId': activityId,
      if (noConsume != null) 'noConsume': noConsume,
      // Nivel de slot para upcastear el conjuro.
      if (castLevel != null) 'castLevel': castLevel,
    });
    return res.data is Map ? (res.data as Map).cast<String, dynamic>() : {};
  }

  @override
  Future<void> manualAttack(String actorId, String itemId,
      {required List<String> targetIds,
      int? attackTotal,
      int? damageTotal,
      bool crit = false}) async {
    await _dio.post('/api/actors/$actorId/manual', data: {
      'itemId': itemId,
      'targetIds': targetIds,
      if (attackTotal != null) 'attackTotal': attackTotal,
      if (damageTotal != null) 'damageTotal': damageTotal,
      'crit': crit,
    });
  }

  @override
  Future<Map<String, dynamic>> setEquipped(
      String actorId, String itemId, bool equipped) async {
    final res = await _dio.post('/api/actors/$actorId/equip',
        data: {'itemId': itemId, 'equipped': equipped});
    return res.data is Map ? (res.data as Map).cast<String, dynamic>() : {};
  }

  @override
  Future<Map<String, dynamic>> endEffect(String actorId, String effectId) async {
    final res = await _dio.post('/api/actors/$actorId/effect-end',
        data: {'effectId': effectId});
    return res.data is Map ? (res.data as Map).cast<String, dynamic>() : {};
  }

  @override
  Future<void> logRoll(Map<String, dynamic> roll) async {
    await _dio.post('/api/rolls', data: roll);
  }

  @override
  Future<List<CompendiumPack>> compendiumPacks() async {
    final res = await _dio.get('/api/compendium/packs');
    final data = res.data as Map<String, dynamic>;
    final list = (data['packs'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return list.map(CompendiumPack.fromJson).toList();
  }

  @override
  Future<List<CompendiumEntry>> compendiumIndex(String pack) async {
    final res = await _dio.get('/api/compendium/index',
        queryParameters: {'pack': pack});
    final data = res.data as Map<String, dynamic>;
    final list = (data['entries'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return list.map(CompendiumEntry.fromJson).toList();
  }

  @override
  Future<List<CompendiumEntry>> compendiumSearch(String query,
      {String? type}) async {
    final res = await _dio.get('/api/compendium/search', queryParameters: {
      'q': query,
      if (type != null && type.isNotEmpty) 'type': type,
    });
    final data = res.data as Map<String, dynamic>;
    final list = (data['entries'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return list.map(CompendiumEntry.fromJson).toList();
  }

  @override
  Future<CompendiumDetail> compendiumEntry(String pack, String entryId) async {
    final res = await _dio.get('/api/compendium/entry',
        queryParameters: {'pack': pack, 'id': entryId});
    return CompendiumDetail.fromJson(res.data as Map<String, dynamic>);
  }

  @override
  Future<Map<String, dynamic>> addToActor(
      String actorId, String pack, String entryId) async {
    final res = await _dio.post('/api/actors/$actorId/add',
        data: {'pack': pack, 'entryId': entryId});
    return res.data is Map ? (res.data as Map).cast<String, dynamic>() : {};
  }

  @override
  Future<Map<String, dynamic>> longRest(String actorId) async {
    final res = await _dio.post('/api/actors/$actorId/rest', data: {});
    return res.data is Map ? (res.data as Map).cast<String, dynamic>() : {};
  }

  @override
  Future<Map<String, dynamic>> restoreSpellSlots(String actorId) async {
    final res = await _dio.post('/api/actors/$actorId/slots', data: {});
    return res.data is Map ? (res.data as Map).cast<String, dynamic>() : {};
  }

  @override
  Future<List<ChatMessage>> getChat({int? since, int limit = 60}) async {
    final res = await _dio.get('/api/chat', queryParameters: {
      'limit': limit,
      if (since != null) 'since': since,
    });
    final data = res.data as Map<String, dynamic>;
    final list = (data['messages'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return list.map(ChatMessage.fromNormalized).toList();
  }

  @override
  Future<void> sendChat(Map<String, dynamic> body) async {
    await _dio.post('/api/chat', data: body);
  }

  @override
  Future<void> clearChat() async {
    await _dio.delete('/api/chat');
  }

  @override
  Future<List<Rule>> getRules() async {
    final res = await _dio.get('/api/rules');
    final data = res.data as Map<String, dynamic>;
    final list = (data['rules'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return list.map(Rule.fromJson).toList();
  }

  @override
  Future<Rule> saveRule(
      {String? id, required String title, required String body}) async {
    final res = await _dio.post('/api/rules', data: {
      if (id != null) 'id': id,
      'title': title,
      'body': body,
    });
    return Rule.fromJson((res.data as Map).cast<String, dynamic>());
  }

  @override
  Future<void> deleteRule(String id) async {
    await _dio.delete('/api/rules/$id');
  }

  @override
  Future<void> sendRoll(RollRequest roll) async {
    final payload = IngestRollRequest.fromRollRequest(roll);
    await _dio.post('/ingest', data: payload.toJson());
  }
}

final foundryRepositoryProvider = Provider<FoundryRepository>(
  (ref) => DioFoundryRepository(ref.watch(dioProvider)),
);
