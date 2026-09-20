/// Plan de acción de un NPC decidido por el módulo (IA experimental).
/// Guarda el JSON crudo para poder reenviarlo a "ejecutar".
class NpcPlan {
  final Map<String, dynamic> raw;
  final String npcName;
  final String targetName;
  final String weaponName;
  final String reason;
  final int distanceFt;
  final int reachFt;
  final bool needsMove;
  final bool willAttack;
  final bool autonomous;
  final String style; // instinto | normal | táctico

  const NpcPlan({
    required this.raw,
    required this.npcName,
    required this.targetName,
    required this.weaponName,
    required this.reason,
    required this.distanceFt,
    required this.reachFt,
    required this.needsMove,
    required this.willAttack,
    required this.autonomous,
    required this.style,
  });

  factory NpcPlan.fromJson(Map<String, dynamic> j) => NpcPlan(
        raw: j,
        npcName: j['npcName'] as String? ?? '?',
        targetName: j['targetName'] as String? ?? '?',
        weaponName: j['weaponName'] as String? ?? '?',
        reason: j['reason'] as String? ?? '',
        distanceFt: (j['distanceFt'] as num?)?.toInt() ?? 0,
        reachFt: (j['reachFt'] as num?)?.toInt() ?? 0,
        needsMove: j['needsMove'] as bool? ?? false,
        willAttack: j['willAttack'] as bool? ?? false,
        autonomous: j['autonomous'] as bool? ?? false,
        style: (j['intelligence'] as Map?)?['style'] as String? ?? 'normal',
      );
}
