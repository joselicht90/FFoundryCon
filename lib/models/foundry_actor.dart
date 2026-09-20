import 'package:json_annotation/json_annotation.dart';

part 'foundry_actor.g.dart';

@JsonSerializable()
class ActorAbility {
  final String key;
  final String label;
  @JsonKey(defaultValue: 10)
  final int value;
  @JsonKey(defaultValue: 0)
  final int mod;
  @JsonKey(defaultValue: 0)
  final int save;
  @JsonKey(defaultValue: 0)
  final num proficient;

  const ActorAbility({
    required this.key,
    required this.label,
    required this.value,
    required this.mod,
    required this.save,
    required this.proficient,
  });

  bool get saveProficient => proficient >= 1;
  String get modStr => mod >= 0 ? '+$mod' : '$mod';
  String get saveStr => save >= 0 ? '+$save' : '$save';

  factory ActorAbility.fromJson(Map<String, dynamic> json) =>
      _$ActorAbilityFromJson(json);
  Map<String, dynamic> toJson() => _$ActorAbilityToJson(this);
}

@JsonSerializable()
class ActorSkill {
  final String key;
  final String label;
  @JsonKey(defaultValue: 'dex')
  final String ability;
  @JsonKey(defaultValue: 0)
  final int total;
  @JsonKey(defaultValue: 0)
  final int passive;
  /// 0 = ninguna, 0.5 = media, 1 = competente, 2 = experticia.
  @JsonKey(defaultValue: 0)
  final num proficient;

  const ActorSkill({
    required this.key,
    required this.label,
    required this.ability,
    required this.total,
    required this.passive,
    required this.proficient,
  });

  String get totalStr => total >= 0 ? '+$total' : '$total';

  factory ActorSkill.fromJson(Map<String, dynamic> json) =>
      _$ActorSkillFromJson(json);
  Map<String, dynamic> toJson() => _$ActorSkillToJson(this);
}

@JsonSerializable()
class ActorClass {
  final String name;
  final int? levels;
  const ActorClass({required this.name, this.levels});

  factory ActorClass.fromJson(Map<String, dynamic> json) =>
      _$ActorClassFromJson(json);
  Map<String, dynamic> toJson() => _$ActorClassToJson(this);
}

@JsonSerializable()
class ActorHp {
  @JsonKey(defaultValue: 0)
  final int value;
  @JsonKey(defaultValue: 0)
  final int max;
  @JsonKey(defaultValue: 0)
  final int temp;
  @JsonKey(defaultValue: 0)
  final int tempmax;

  const ActorHp({
    required this.value,
    required this.max,
    required this.temp,
    required this.tempmax,
  });

  factory ActorHp.fromJson(Map<String, dynamic> json) =>
      _$ActorHpFromJson(json);
  Map<String, dynamic> toJson() => _$ActorHpToJson(this);
}

/// Efecto activo temporal (rage, bless, condición…). Se puede terminar.
@JsonSerializable()
class ActorEffect {
  final String id;
  @JsonKey(defaultValue: '')
  final String name;
  final String? img;
  @JsonKey(defaultValue: <String>[])
  final List<String> statuses;

  const ActorEffect({
    required this.id,
    required this.name,
    this.img,
    this.statuses = const [],
  });

  factory ActorEffect.fromJson(Map<String, dynamic> json) =>
      _$ActorEffectFromJson(json);
  Map<String, dynamic> toJson() => _$ActorEffectToJson(this);
}

@JsonSerializable()
class ActorXp {
  @JsonKey(defaultValue: 0)
  final int value;
  @JsonKey(defaultValue: 0)
  final int max;

  const ActorXp({required this.value, required this.max});

  factory ActorXp.fromJson(Map<String, dynamic> json) =>
      _$ActorXpFromJson(json);
  Map<String, dynamic> toJson() => _$ActorXpToJson(this);
}

@JsonSerializable()
class ItemUses {
  @JsonKey(defaultValue: 0)
  final int value;
  @JsonKey(defaultValue: 0)
  final int max;
  const ItemUses({required this.value, required this.max});

  factory ItemUses.fromJson(Map<String, dynamic> json) =>
      _$ItemUsesFromJson(json);
  Map<String, dynamic> toJson() => _$ItemUsesToJson(this);
}

@JsonSerializable()
class ItemActivity {
  final String id;
  @JsonKey(defaultValue: 'Acción')
  final String name;
  @JsonKey(defaultValue: '')
  final String type;
  @JsonKey(defaultValue: false)
  final bool hasAttack;
  @JsonKey(defaultValue: true)
  final bool needsTargets;

  const ItemActivity({
    required this.id,
    required this.name,
    required this.type,
    this.hasAttack = false,
    this.needsTargets = true,
  });

  factory ItemActivity.fromJson(Map<String, dynamic> json) =>
      _$ItemActivityFromJson(json);
  Map<String, dynamic> toJson() => _$ItemActivityToJson(this);
}

@JsonSerializable()
class ActorItem {
  final String id;
  @JsonKey(defaultValue: '')
  final String name;
  final String? img;
  @JsonKey(defaultValue: 'loot')
  final String type;
  @JsonKey(defaultValue: 1)
  final int quantity;
  @JsonKey(defaultValue: false)
  final bool equipped;
  @JsonKey(defaultValue: '')
  final String rarity;
  @JsonKey(defaultValue: 0)
  final num weight;
  final ItemUses? uses;
  @JsonKey(defaultValue: false)
  final bool canUse;
  @JsonKey(defaultValue: false)
  final bool hasAttack;
  @JsonKey(defaultValue: false)
  final bool hasSave;
  @JsonKey(defaultValue: true)
  final bool needsTargets;
  @JsonKey(defaultValue: <ItemActivity>[])
  final List<ItemActivity> activities;
  final String? toHit; // "+5"
  final String? damage; // "1d8 + 3"
  final String? range; // "5 ft"
  final String? description;
  final String? containerId;
  @JsonKey(defaultValue: false)
  final bool isContainer;

  const ActorItem({
    required this.id,
    required this.name,
    this.img,
    required this.type,
    required this.quantity,
    required this.equipped,
    required this.rarity,
    required this.weight,
    this.uses,
    required this.canUse,
    this.hasAttack = false,
    this.hasSave = false,
    this.needsTargets = true,
    this.activities = const [],
    this.toHit,
    this.damage,
    this.range,
    this.description,
    this.containerId,
    this.isContainer = false,
  });

  /// Modificador de ataque parseado (para tirar offline).
  int? get toHitMod {
    if (toHit == null) return null;
    final m = RegExp(r'([+-]?\s*\d+)').firstMatch(toHit!);
    return m == null ? null : int.tryParse(m.group(1)!.replaceAll(' ', ''));
  }

  factory ActorItem.fromJson(Map<String, dynamic> json) =>
      _$ActorItemFromJson(json);
  Map<String, dynamic> toJson() => _$ActorItemToJson(this);
}

/// Inventario compartido de la party (actor tipo "group"). Editable por todos.
@JsonSerializable()
class ActorParty {
  final String id;
  @JsonKey(defaultValue: '')
  final String name;
  @JsonKey(defaultValue: <ActorItem>[])
  final List<ActorItem> items;

  const ActorParty({required this.id, required this.name, required this.items});

  factory ActorParty.fromJson(Map<String, dynamic> json) =>
      _$ActorPartyFromJson(json);
  Map<String, dynamic> toJson() => _$ActorPartyToJson(this);
}

@JsonSerializable()
class ActorSpell {
  final String id;
  @JsonKey(defaultValue: '')
  final String name;
  final String? img;
  @JsonKey(defaultValue: 0)
  final int level;
  @JsonKey(defaultValue: '')
  final String school;
  @JsonKey(defaultValue: false)
  final bool prepared;
  @JsonKey(defaultValue: 'prepared')
  final String mode;
  final ItemUses? uses;
  @JsonKey(defaultValue: false)
  final bool canUse;
  @JsonKey(defaultValue: false)
  final bool hasAttack;
  @JsonKey(defaultValue: false)
  final bool hasSave;
  @JsonKey(defaultValue: true)
  final bool needsTargets;
  @JsonKey(defaultValue: <ItemActivity>[])
  final List<ItemActivity> activities;
  final String? toHit;
  final String? damage;
  final String? save;
  final String? description;

  const ActorSpell({
    required this.id,
    required this.name,
    this.img,
    required this.level,
    required this.school,
    required this.prepared,
    required this.mode,
    this.uses,
    required this.canUse,
    this.hasAttack = false,
    this.hasSave = false,
    this.needsTargets = true,
    this.activities = const [],
    this.toHit,
    this.damage,
    this.save,
    this.description,
  });

  bool get isCantrip => level == 0;

  factory ActorSpell.fromJson(Map<String, dynamic> json) =>
      _$ActorSpellFromJson(json);
  Map<String, dynamic> toJson() => _$ActorSpellToJson(this);
}

@JsonSerializable()
class SpellSlot {
  final String key;
  @JsonKey(defaultValue: 0)
  final int level;
  @JsonKey(defaultValue: 0)
  final int value;
  @JsonKey(defaultValue: 0)
  final int max;
  @JsonKey(defaultValue: false)
  final bool pact;

  const SpellSlot({
    required this.key,
    required this.level,
    required this.value,
    required this.max,
    required this.pact,
  });

  factory SpellSlot.fromJson(Map<String, dynamic> json) =>
      _$SpellSlotFromJson(json);
  Map<String, dynamic> toJson() => _$SpellSlotToJson(this);
}

@JsonSerializable(explicitToJson: true)
class FoundryActor {
  final String id;
  @JsonKey(defaultValue: 'Personaje')
  final String name;
  final String? img;
  final int? level;
  @JsonKey(defaultValue: '')
  final String race;
  @JsonKey(defaultValue: '')
  final String background;
  @JsonKey(defaultValue: <ActorClass>[])
  final List<ActorClass> classes;
  final ActorHp hp;
  final ActorXp? xp;
  final int? ac;
  final String? acCalc;
  final int? acFlat;
  final String? speed;
  @JsonKey(defaultValue: 'ft')
  final String speedUnits;
  final int? prof;
  final int? initiative;
  @JsonKey(defaultValue: false)
  final bool inspiration;
  @JsonKey(defaultValue: <String, ActorAbility>{})
  final Map<String, ActorAbility> abilities;
  @JsonKey(defaultValue: <String, ActorSkill>{})
  final Map<String, ActorSkill> skills;
  @JsonKey(defaultValue: <ActorItem>[])
  final List<ActorItem> items;
  @JsonKey(defaultValue: <ActorItem>[])
  final List<ActorItem> feats;
  @JsonKey(defaultValue: <ActorItem>[])
  final List<ActorItem> features; // rasgos pasivos (solo lectura)
  @JsonKey(defaultValue: <ActorSpell>[])
  final List<ActorSpell> spells;
  @JsonKey(defaultValue: <SpellSlot>[])
  final List<SpellSlot> spellSlots;
  /// Inventario compartido de la party (null si no pertenece a ninguna).
  final ActorParty? party;
  @JsonKey(defaultValue: <ActorEffect>[])
  final List<ActorEffect> effects;

  /// True cuando el dato viene de Mongo (Foundry offline).
  @JsonKey(defaultValue: false)
  final bool offline;

  /// Paths derivados (ej: `abilities.str.mod`) con edición offline sin
  /// recalcular en Foundry todavía.
  @JsonKey(defaultValue: <String>[])
  final List<String> pending;

  const FoundryActor({
    required this.id,
    required this.name,
    this.img,
    this.level,
    required this.race,
    required this.background,
    required this.classes,
    required this.hp,
    this.xp,
    this.ac,
    this.acCalc,
    this.acFlat,
    this.speed,
    required this.speedUnits,
    this.prof,
    this.initiative,
    this.inspiration = false,
    required this.abilities,
    required this.skills,
    required this.items,
    this.feats = const [],
    this.features = const [],
    required this.spells,
    required this.spellSlots,
    this.party,
    this.effects = const [],
    this.offline = false,
    this.pending = const [],
  });

  bool isPending(String path) => pending.contains(path);

  /// Abilities en orden canónico de D&D.
  List<ActorAbility> get abilityList {
    const order = ['str', 'dex', 'con', 'int', 'wis', 'cha'];
    final list = order
        .where(abilities.containsKey)
        .map((k) => abilities[k]!)
        .toList();
    // Cualquier ability extra que no esté en el orden canónico.
    for (final e in abilities.entries) {
      if (!order.contains(e.key)) list.add(e.value);
    }
    return list;
  }

  /// Skills ordenadas por label.
  List<ActorSkill> get skillList {
    final list = skills.values.toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    return list;
  }

  String get classLine {
    final cls = classes
        .map((c) => c.levels != null ? '${c.name} ${c.levels}' : c.name)
        .join(' / ');
    final bits = [cls, race].where((s) => s.isNotEmpty).toList();
    return bits.join(' • ');
  }

  /// AC editable solo si el cálculo es "flat".
  bool get acEditable => acCalc == 'flat';

  /// Conjuros agrupados por nivel (0 = trucos), ordenados.
  Map<int, List<ActorSpell>> get spellsByLevel {
    final map = <int, List<ActorSpell>>{};
    for (final s in spells) {
      (map[s.level] ??= []).add(s);
    }
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  SpellSlot? slotForLevel(int level) {
    for (final s in spellSlots) {
      if (s.level == level) return s;
    }
    return null;
  }

  factory FoundryActor.fromJson(Map<String, dynamic> json) =>
      _$FoundryActorFromJson(json);
  Map<String, dynamic> toJson() => _$FoundryActorToJson(this);
}

/// Tipo de tirada.
enum RollKind {
  ability,
  save,
  skill,
  init;

  String get wire => name;
}

/// Modo de tirada.
enum RollMode {
  normal,
  adv,
  dis;

  String get wire => name;
}
