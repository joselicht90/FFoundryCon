import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging/app_logger.dart';
import '../core/network/reader_events.dart';
import '../models/chat_message.dart';
import '../repositories/foundry_repository.dart';

/// Chat en vivo: trae historial por REST y escucha el stream WS compartido
/// (`readerEventsProvider`). Poll de respaldo cada 3s por si el WS falla.
class ChatController extends AsyncNotifier<List<ChatMessage>> {
  Timer? _poll;
  bool _disposed = false;

  @override
  Future<List<ChatMessage>> build() async {
    ref.onDispose(() {
      _disposed = true;
      _poll?.cancel();
    });
    // En vivo por el WS compartido.
    ref.listen(readerEventsProvider, (_, next) {
      final m = next.valueOrNull;
      if (m == null) return;
      final type = m['type'];
      if (type != 'roll' && type != 'message') return;
      final data = m['data'] as Map<String, dynamic>?;
      if (data != null) _append(ChatMessage.fromIngest(data));
    });
    _startPolling();
    try {
      return await ref.read(foundryRepositoryProvider).getChat(limit: 80);
    } catch (e, st) {
      logger.w('No pude traer el historial de chat', error: e, stackTrace: st);
      return [];
    }
  }

  // Respaldo: aunque el WS falle, nos ponemos al día cada pocos segundos.
  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _pollOnce());
  }

  Future<void> _pollOnce() async {
    if (_disposed) return;
    final cur = state.valueOrNull;
    if (cur == null) return;
    final since = cur.isEmpty ? 0 : (cur.last.timestamp - 2000);
    try {
      final fresh =
          await ref.read(foundryRepositoryProvider).getChat(since: since, limit: 60);
      for (final m in fresh) {
        _append(m);
      }
    } catch (_) {/* silencioso */}
  }

  void _append(ChatMessage m) {
    final cur = state.valueOrNull ?? const <ChatMessage>[];
    if (cur.any((x) => x.id == m.id)) return;
    final next = [...cur, m]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    state = AsyncData(next.length > 200 ? next.sublist(next.length - 200) : next);
  }

  Future<void> send({
    required String author,
    String? authorColor,
    String? userId,
    String? text,
    bool isOoc = false,
    Map<String, dynamic>? roll,
    String? flavor,
    List<String> whisper = const [],
  }) async {
    try {
      await ref.read(foundryRepositoryProvider).sendChat({
        'author': author,
        if (authorColor != null) 'authorColor': authorColor,
        if (userId != null) 'userId': userId,
        if (text != null) 'text': text,
        'isOoc': isOoc,
        if (roll != null) 'roll': roll,
        if (flavor != null) 'flavor': flavor,
        if (whisper.isNotEmpty) 'whisper': whisper,
      });
    } catch (e, st) {
      logger.w('No pude enviar el mensaje', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(foundryRepositoryProvider).getChat(limit: 80),
    );
  }

  /// Borra el chat (es solo una copia). Limpia Mongo y la vista local.
  Future<void> clear() async {
    try {
      await ref.read(foundryRepositoryProvider).clearChat();
    } catch (e, st) {
      logger.w('No pude borrar el chat', error: e, stackTrace: st);
    }
    state = const AsyncData([]);
  }
}

final chatControllerProvider =
    AsyncNotifierProvider<ChatController, List<ChatMessage>>(ChatController.new);
