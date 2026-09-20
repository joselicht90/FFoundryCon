import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'reader_url_provider.dart';

/// Stream compartido de eventos del reader por WebSocket
/// (`{type:'roll'|'message'|'actor'|'connected', data}`). Reconecta solo.
/// Lo consumen el chat (roll/message) y la hoja del actor (actor).
final readerEventsProvider =
    StreamProvider<Map<String, dynamic>>((ref) {
  final base = ref.watch(readerUrlProvider);
  final controller = StreamController<Map<String, dynamic>>.broadcast();

  if (base == null || base.isEmpty) {
    controller.close();
    return controller.stream;
  }

  final wsUrl = base.replaceFirst(RegExp(r'^http'), 'ws');
  WebSocketChannel? ws;
  StreamSubscription? sub;
  var disposed = false;

  void connect() {
    if (disposed) return;
    try {
      ws = WebSocketChannel.connect(Uri.parse(wsUrl));
      sub = ws!.stream.listen(
        (raw) {
          try {
            final m = jsonDecode(raw as String) as Map<String, dynamic>;
            controller.add(m);
          } catch (_) {/* frames no-JSON */}
        },
        onDone: () {
          if (disposed) return;
          Future.delayed(const Duration(seconds: 3), connect);
        },
        onError: (_) {
          if (disposed) return;
          Future.delayed(const Duration(seconds: 3), connect);
        },
        cancelOnError: true,
      );
    } catch (_) {
      if (!disposed) Future.delayed(const Duration(seconds: 3), connect);
    }
  }

  connect();
  ref.onDispose(() {
    disposed = true;
    sub?.cancel();
    ws?.sink.close();
    controller.close();
  });

  return controller.stream;
});
