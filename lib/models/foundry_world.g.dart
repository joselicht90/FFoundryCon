// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'foundry_world.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FoundryWorld _$FoundryWorldFromJson(Map<String, dynamic> json) => FoundryWorld(
  id: json['id'] as String,
  title: json['title'] as String? ?? 'Foundry',
  image: json['image'] as String?,
  system: json['system'] as String?,
);

Map<String, dynamic> _$FoundryWorldToJson(FoundryWorld instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'image': instance.image,
      'system': instance.system,
    };
