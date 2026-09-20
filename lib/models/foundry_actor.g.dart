// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'foundry_actor.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ActorAbility _$ActorAbilityFromJson(Map<String, dynamic> json) => ActorAbility(
  key: json['key'] as String,
  label: json['label'] as String,
  value: (json['value'] as num?)?.toInt() ?? 10,
  mod: (json['mod'] as num?)?.toInt() ?? 0,
  save: (json['save'] as num?)?.toInt() ?? 0,
  proficient: json['proficient'] as num? ?? 0,
);

Map<String, dynamic> _$ActorAbilityToJson(ActorAbility instance) =>
    <String, dynamic>{
      'key': instance.key,
      'label': instance.label,
      'value': instance.value,
      'mod': instance.mod,
      'save': instance.save,
      'proficient': instance.proficient,
    };

ActorSkill _$ActorSkillFromJson(Map<String, dynamic> json) => ActorSkill(
  key: json['key'] as String,
  label: json['label'] as String,
  ability: json['ability'] as String? ?? 'dex',
  total: (json['total'] as num?)?.toInt() ?? 0,
  passive: (json['passive'] as num?)?.toInt() ?? 0,
  proficient: json['proficient'] as num? ?? 0,
);

Map<String, dynamic> _$ActorSkillToJson(ActorSkill instance) =>
    <String, dynamic>{
      'key': instance.key,
      'label': instance.label,
      'ability': instance.ability,
      'total': instance.total,
      'passive': instance.passive,
      'proficient': instance.proficient,
    };

ActorClass _$ActorClassFromJson(Map<String, dynamic> json) => ActorClass(
  name: json['name'] as String,
  levels: (json['levels'] as num?)?.toInt(),
);

Map<String, dynamic> _$ActorClassToJson(ActorClass instance) =>
    <String, dynamic>{'name': instance.name, 'levels': instance.levels};

ActorHp _$ActorHpFromJson(Map<String, dynamic> json) => ActorHp(
  value: (json['value'] as num?)?.toInt() ?? 0,
  max: (json['max'] as num?)?.toInt() ?? 0,
  temp: (json['temp'] as num?)?.toInt() ?? 0,
  tempmax: (json['tempmax'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$ActorHpToJson(ActorHp instance) => <String, dynamic>{
  'value': instance.value,
  'max': instance.max,
  'temp': instance.temp,
  'tempmax': instance.tempmax,
};

ActorEffect _$ActorEffectFromJson(Map<String, dynamic> json) => ActorEffect(
  id: json['id'] as String,
  name: json['name'] as String? ?? '',
  img: json['img'] as String?,
  statuses:
      (json['statuses'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      [],
);

Map<String, dynamic> _$ActorEffectToJson(ActorEffect instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'img': instance.img,
      'statuses': instance.statuses,
    };

ActorXp _$ActorXpFromJson(Map<String, dynamic> json) => ActorXp(
  value: (json['value'] as num?)?.toInt() ?? 0,
  max: (json['max'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$ActorXpToJson(ActorXp instance) => <String, dynamic>{
  'value': instance.value,
  'max': instance.max,
};

ItemUses _$ItemUsesFromJson(Map<String, dynamic> json) => ItemUses(
  value: (json['value'] as num?)?.toInt() ?? 0,
  max: (json['max'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$ItemUsesToJson(ItemUses instance) => <String, dynamic>{
  'value': instance.value,
  'max': instance.max,
};

ItemActivity _$ItemActivityFromJson(Map<String, dynamic> json) => ItemActivity(
  id: json['id'] as String,
  name: json['name'] as String? ?? 'Acción',
  type: json['type'] as String? ?? '',
  hasAttack: json['hasAttack'] as bool? ?? false,
  needsTargets: json['needsTargets'] as bool? ?? true,
);

Map<String, dynamic> _$ItemActivityToJson(ItemActivity instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': instance.type,
      'hasAttack': instance.hasAttack,
      'needsTargets': instance.needsTargets,
    };

ActorItem _$ActorItemFromJson(Map<String, dynamic> json) => ActorItem(
  id: json['id'] as String,
  name: json['name'] as String? ?? '',
  img: json['img'] as String?,
  type: json['type'] as String? ?? 'loot',
  quantity: (json['quantity'] as num?)?.toInt() ?? 1,
  equipped: json['equipped'] as bool? ?? false,
  rarity: json['rarity'] as String? ?? '',
  weight: json['weight'] as num? ?? 0,
  uses: json['uses'] == null
      ? null
      : ItemUses.fromJson(json['uses'] as Map<String, dynamic>),
  canUse: json['canUse'] as bool? ?? false,
  hasAttack: json['hasAttack'] as bool? ?? false,
  hasSave: json['hasSave'] as bool? ?? false,
  needsTargets: json['needsTargets'] as bool? ?? true,
  activities:
      (json['activities'] as List<dynamic>?)
          ?.map((e) => ItemActivity.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  toHit: json['toHit'] as String?,
  damage: json['damage'] as String?,
  range: json['range'] as String?,
  description: json['description'] as String?,
  containerId: json['containerId'] as String?,
  isContainer: json['isContainer'] as bool? ?? false,
);

Map<String, dynamic> _$ActorItemToJson(ActorItem instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'img': instance.img,
  'type': instance.type,
  'quantity': instance.quantity,
  'equipped': instance.equipped,
  'rarity': instance.rarity,
  'weight': instance.weight,
  'uses': instance.uses,
  'canUse': instance.canUse,
  'hasAttack': instance.hasAttack,
  'hasSave': instance.hasSave,
  'needsTargets': instance.needsTargets,
  'activities': instance.activities,
  'toHit': instance.toHit,
  'damage': instance.damage,
  'range': instance.range,
  'description': instance.description,
  'containerId': instance.containerId,
  'isContainer': instance.isContainer,
};

ActorParty _$ActorPartyFromJson(Map<String, dynamic> json) => ActorParty(
  id: json['id'] as String,
  name: json['name'] as String? ?? '',
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => ActorItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

Map<String, dynamic> _$ActorPartyToJson(ActorParty instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'items': instance.items,
    };

ActorSpell _$ActorSpellFromJson(Map<String, dynamic> json) => ActorSpell(
  id: json['id'] as String,
  name: json['name'] as String? ?? '',
  img: json['img'] as String?,
  level: (json['level'] as num?)?.toInt() ?? 0,
  school: json['school'] as String? ?? '',
  prepared: json['prepared'] as bool? ?? false,
  mode: json['mode'] as String? ?? 'prepared',
  uses: json['uses'] == null
      ? null
      : ItemUses.fromJson(json['uses'] as Map<String, dynamic>),
  canUse: json['canUse'] as bool? ?? false,
  hasAttack: json['hasAttack'] as bool? ?? false,
  hasSave: json['hasSave'] as bool? ?? false,
  needsTargets: json['needsTargets'] as bool? ?? true,
  activities:
      (json['activities'] as List<dynamic>?)
          ?.map((e) => ItemActivity.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  toHit: json['toHit'] as String?,
  damage: json['damage'] as String?,
  save: json['save'] as String?,
  description: json['description'] as String?,
);

Map<String, dynamic> _$ActorSpellToJson(ActorSpell instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'img': instance.img,
      'level': instance.level,
      'school': instance.school,
      'prepared': instance.prepared,
      'mode': instance.mode,
      'uses': instance.uses,
      'canUse': instance.canUse,
      'hasAttack': instance.hasAttack,
      'hasSave': instance.hasSave,
      'needsTargets': instance.needsTargets,
      'activities': instance.activities,
      'toHit': instance.toHit,
      'damage': instance.damage,
      'save': instance.save,
      'description': instance.description,
    };

SpellSlot _$SpellSlotFromJson(Map<String, dynamic> json) => SpellSlot(
  key: json['key'] as String,
  level: (json['level'] as num?)?.toInt() ?? 0,
  value: (json['value'] as num?)?.toInt() ?? 0,
  max: (json['max'] as num?)?.toInt() ?? 0,
  pact: json['pact'] as bool? ?? false,
);

Map<String, dynamic> _$SpellSlotToJson(SpellSlot instance) => <String, dynamic>{
  'key': instance.key,
  'level': instance.level,
  'value': instance.value,
  'max': instance.max,
  'pact': instance.pact,
};

FoundryActor _$FoundryActorFromJson(Map<String, dynamic> json) => FoundryActor(
  id: json['id'] as String,
  name: json['name'] as String? ?? 'Personaje',
  img: json['img'] as String?,
  level: (json['level'] as num?)?.toInt(),
  race: json['race'] as String? ?? '',
  background: json['background'] as String? ?? '',
  classes:
      (json['classes'] as List<dynamic>?)
          ?.map((e) => ActorClass.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  hp: ActorHp.fromJson(json['hp'] as Map<String, dynamic>),
  xp: json['xp'] == null
      ? null
      : ActorXp.fromJson(json['xp'] as Map<String, dynamic>),
  ac: (json['ac'] as num?)?.toInt(),
  acCalc: json['acCalc'] as String?,
  acFlat: (json['acFlat'] as num?)?.toInt(),
  speed: json['speed'] as String?,
  speedUnits: json['speedUnits'] as String? ?? 'ft',
  prof: (json['prof'] as num?)?.toInt(),
  initiative: (json['initiative'] as num?)?.toInt(),
  inspiration: json['inspiration'] as bool? ?? false,
  abilities:
      (json['abilities'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, ActorAbility.fromJson(e as Map<String, dynamic>)),
      ) ??
      {},
  skills:
      (json['skills'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, ActorSkill.fromJson(e as Map<String, dynamic>)),
      ) ??
      {},
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => ActorItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  feats:
      (json['feats'] as List<dynamic>?)
          ?.map((e) => ActorItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  features:
      (json['features'] as List<dynamic>?)
          ?.map((e) => ActorItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  spells:
      (json['spells'] as List<dynamic>?)
          ?.map((e) => ActorSpell.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  spellSlots:
      (json['spellSlots'] as List<dynamic>?)
          ?.map((e) => SpellSlot.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  party: json['party'] == null
      ? null
      : ActorParty.fromJson(json['party'] as Map<String, dynamic>),
  effects:
      (json['effects'] as List<dynamic>?)
          ?.map((e) => ActorEffect.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  offline: json['offline'] as bool? ?? false,
  pending:
      (json['pending'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      [],
);

Map<String, dynamic> _$FoundryActorToJson(FoundryActor instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'img': instance.img,
      'level': instance.level,
      'race': instance.race,
      'background': instance.background,
      'classes': instance.classes.map((e) => e.toJson()).toList(),
      'hp': instance.hp.toJson(),
      'xp': instance.xp?.toJson(),
      'ac': instance.ac,
      'acCalc': instance.acCalc,
      'acFlat': instance.acFlat,
      'speed': instance.speed,
      'speedUnits': instance.speedUnits,
      'prof': instance.prof,
      'initiative': instance.initiative,
      'inspiration': instance.inspiration,
      'abilities': instance.abilities.map((k, e) => MapEntry(k, e.toJson())),
      'skills': instance.skills.map((k, e) => MapEntry(k, e.toJson())),
      'items': instance.items.map((e) => e.toJson()).toList(),
      'feats': instance.feats.map((e) => e.toJson()).toList(),
      'features': instance.features.map((e) => e.toJson()).toList(),
      'spells': instance.spells.map((e) => e.toJson()).toList(),
      'spellSlots': instance.spellSlots.map((e) => e.toJson()).toList(),
      'party': instance.party?.toJson(),
      'effects': instance.effects.map((e) => e.toJson()).toList(),
      'offline': instance.offline,
      'pending': instance.pending,
    };
