// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'foundry_token.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FoundryToken _$FoundryTokenFromJson(Map<String, dynamic> json) => FoundryToken(
  id: json['id'] as String,
  name: json['name'] as String? ?? 'Token',
  x: (json['x'] as num?)?.toDouble() ?? 0,
  y: (json['y'] as num?)?.toDouble() ?? 0,
  gw: json['gw'] as num? ?? 1,
  gh: json['gh'] as num? ?? 1,
  actorId: json['actorId'] as String?,
  img: json['img'] as String?,
  hidden: json['hidden'] as bool? ?? false,
  disposition: (json['disposition'] as num?)?.toInt() ?? 0,
  ownerIds:
      (json['ownerIds'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      [],
  vision:
      (json['vision'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList() ??
      [],
  sightRadius: (json['sightRadius'] as num?)?.toDouble() ?? 0,
);

Map<String, dynamic> _$FoundryTokenToJson(FoundryToken instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'x': instance.x,
      'y': instance.y,
      'gw': instance.gw,
      'gh': instance.gh,
      'actorId': instance.actorId,
      'img': instance.img,
      'hidden': instance.hidden,
      'disposition': instance.disposition,
      'ownerIds': instance.ownerIds,
      'vision': instance.vision,
      'sightRadius': instance.sightRadius,
    };
