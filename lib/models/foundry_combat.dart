/// PV de un combatiente (solo aliados; los enemigos vienen sin HP).
class CombatantHp {
  final int value;
  final int max;
  final int temp;
  const CombatantHp({required this.value, required this.max, this.temp = 0});

  factory CombatantHp.fromJson(Map<String, dynamic> j) => CombatantHp(
        value: (j['value'] as num?)?.toInt() ?? 0,
        max: (j['max'] as num?)?.toInt() ?? 0,
        temp: (j['temp'] as num?)?.toInt() ?? 0,
      );
}

/// Un combatiente en el orden de iniciativa.
class Combatant {
  final String id;
  final String name;
  final String? img;
  final double? initiative;
  final String? actorId;
  final String? tokenId;
  final bool hidden;
  final bool defeated;
  final int disposition; // -1 hostil, 0 neutral, 1 aliado
  final CombatantHp? hp;

  const Combatant({
    required this.id,
    required this.name,
    this.img,
    this.initiative,
    this.actorId,
    this.tokenId,
    this.hidden = false,
    this.defeated = false,
    this.disposition = 0,
    this.hp,
  });

  bool get isHostile => disposition == -1;
  bool get isFriendly => disposition >= 1;

  factory Combatant.fromJson(Map<String, dynamic> j) => Combatant(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '?',
        img: j['img'] as String?,
        initiative: (j['initiative'] as num?)?.toDouble(),
        actorId: j['actorId'] as String?,
        tokenId: j['tokenId'] as String?,
        hidden: j['hidden'] as bool? ?? false,
        defeated: j['defeated'] as bool? ?? false,
        disposition: (j['disposition'] as num?)?.toInt() ?? 0,
        hp: j['hp'] is Map<String, dynamic>
            ? CombatantHp.fromJson(j['hp'] as Map<String, dynamic>)
            : null,
      );
}

/// Estado del combate activo de Foundry.
class FoundryCombat {
  final bool active;
  final int round;
  final int turn;
  final String? currentId;
  final int roundStartedAt; // ms; para el mini-log por ronda
  final bool autonomousNpc; // setting global de IA de NPC
  final List<Combatant> combatants;

  const FoundryCombat({
    this.active = false,
    this.round = 0,
    this.turn = 0,
    this.currentId,
    this.roundStartedAt = 0,
    this.autonomousNpc = false,
    this.combatants = const [],
  });

  Combatant? get current {
    for (final c in combatants) {
      if (c.id == currentId) return c;
    }
    return null;
  }

  factory FoundryCombat.fromJson(Map<String, dynamic> j) => FoundryCombat(
        active: j['active'] as bool? ?? false,
        round: (j['round'] as num?)?.toInt() ?? 0,
        turn: (j['turn'] as num?)?.toInt() ?? 0,
        currentId: j['currentId'] as String?,
        roundStartedAt: (j['roundStartedAt'] as num?)?.toInt() ?? 0,
        autonomousNpc: j['autonomousNpc'] as bool? ?? false,
        combatants: (j['combatants'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(Combatant.fromJson)
                .toList() ??
            const [],
      );
}
