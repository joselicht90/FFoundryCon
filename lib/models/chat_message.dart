/// Objetivo de una aplicación de daño (token golpeado).
class DamageTarget {
  final String tokenId;
  final String name;
  const DamageTarget({required this.tokenId, required this.name});

  factory DamageTarget.fromJson(Map<String, dynamic> j) => DamageTarget(
        tokenId: j['tokenId'] as String? ?? '',
        name: j['name'] as String? ?? '?',
      );
}

/// Datos para el botón "Aplicar daño" del DM (viene con el roll de daño de Midi).
class ApplyDamage {
  final int total;
  final List<DamageTarget> targets;
  final List<Map<String, dynamic>> damages; // [{value, type}] tipado

  const ApplyDamage({
    required this.total,
    required this.targets,
    required this.damages,
  });

  factory ApplyDamage.fromJson(Map<String, dynamic> j) => ApplyDamage(
        total: (j['total'] as num?)?.toInt() ?? 0,
        targets: (j['targets'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(DamageTarget.fromJson)
                .toList() ??
            const [],
        damages: (j['damages'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            const [],
      );
}

/// Mensaje del chat. Se construye tanto del shape normalizado (`GET /api/chat`)
/// como del entry crudo que llega por WebSocket (`{type, data}`).
class ChatMessage {
  final String id;
  final String source; // foundry | mobile | ddb
  final String author;
  final String? authorColor;
  final bool isRoll;
  final String? flavor;
  final String? formula;
  final int? total;
  final List<int> dice;
  final String? text;
  final bool isOoc;
  final bool isSystem;
  final String? userId;
  /// Ids de usuario destinatarios. Vacío = público.
  final List<String> whisper;
  /// Datos del botón "Aplicar daño" del DM (null si no aplica).
  final ApplyDamage? applyDamage;
  final int timestamp;

  const ChatMessage({
    required this.id,
    required this.source,
    required this.author,
    this.authorColor,
    required this.isRoll,
    this.flavor,
    this.formula,
    this.total,
    this.dice = const [],
    this.text,
    this.isOoc = false,
    this.isSystem = false,
    this.userId,
    this.whisper = const [],
    this.applyDamage,
    required this.timestamp,
  });

  static ApplyDamage? _apply(dynamic v) =>
      v is Map<String, dynamic> ? ApplyDamage.fromJson(v) : null;

  bool get fromApp => source.startsWith('mobile');
  bool get isPrivate => whisper.isNotEmpty;

  static List<String> _strs(dynamic v) =>
      (v as List?)?.map((e) => '$e').toList() ?? const [];

  /// ¿Es visible para [viewerId]? (público, o soy GM, o soy autor/destinatario)
  bool visibleTo(String? viewerId, bool isGM) {
    if (whisper.isEmpty || isGM) return true;
    if (viewerId == null) return false;
    return userId == viewerId || whisper.contains(viewerId);
  }

  static List<int> _ints(dynamic v) =>
      (v as List?)
          ?.map((e) => e is num ? e.toInt() : int.tryParse('$e') ?? 0)
          .toList() ??
      const [];

  static int? _intOf(dynamic v) =>
      v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

  static String _strip(String? s) =>
      (s ?? '').replaceAll(RegExp(r'<[^>]+>'), '').trim();

  /// Flavor de una tirada como etiqueta corta: sin HTML, solo la primera línea
  /// y acotado. Evita que la descripción del ataque (que Foundry adjunta) se
  /// muestre en el chat de la app — solo queremos el roll.
  static String? _cleanFlavor(String? s) {
    if (s == null) return null;
    var t = s.replaceAll(RegExp(r'<[^>]+>'), ' ');
    t = t.split('\n').first.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isEmpty) return null;
    return t.length > 80 ? '${t.substring(0, 79)}…' : t;
  }

  /// Shape normalizado del reader (`GET /api/chat`).
  factory ChatMessage.fromNormalized(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String? ?? '${j['timestamp']}',
        source: j['source'] as String? ?? 'foundry',
        author: j['author'] as String? ?? '?',
        authorColor: j['authorColor'] as String?,
        isRoll: j['isRoll'] as bool? ?? false,
        flavor: _cleanFlavor(j['flavor'] as String?),
        formula: j['formula'] as String?,
        total: _intOf(j['total']),
        dice: _ints(j['dice']),
        text: j['text'] as String?,
        isOoc: j['isOoc'] as bool? ?? false,
        isSystem: j['isSystem'] as bool? ?? false,
        userId: j['userId'] as String?,
        whisper: _strs(j['whisper']),
        applyDamage: _apply(j['applyDamage']),
        timestamp: _intOf(j['timestamp']) ?? 0,
      );

  /// Entry crudo que llega por WS (`data` de `{type, data}`).
  factory ChatMessage.fromIngest(Map<String, dynamic> e) {
    final rolls = (e['rolls'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final isRoll = rolls.isNotEmpty;
    final roll = isRoll ? rolls.first : null;
    final speaker = e['speaker'] as Map<String, dynamic>?;
    final type = _intOf(e['type']); // en v12+ puede venir String ("base")
    return ChatMessage(
      id: e['id'] as String? ?? '${e['timestamp']}',
      source: e['source'] as String? ?? 'foundry',
      author: speaker?['alias'] as String? ?? e['userName'] as String? ?? '?',
      authorColor: e['color'] as String?,
      isRoll: isRoll,
      flavor: _cleanFlavor(e['flavor'] as String?),
      formula: roll?['formula'] as String?,
      total: _intOf(roll?['total']),
      dice: _ints(roll?['values']),
      text: isRoll ? null : _strip(e['content'] as String? ?? e['text'] as String?),
      isOoc: e['ooc'] == true || type == 2,
      isSystem: type == 4,
      userId: e['userId'] as String?,
      whisper: _strs(e['whisper']),
      applyDamage: _apply(e['applyDamage']),
      timestamp: _intOf(e['timestamp']) ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}
