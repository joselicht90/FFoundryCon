// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'foundry_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FoundryUser _$FoundryUserFromJson(Map<String, dynamic> json) => FoundryUser(
  id: json['id'] as String,
  name: json['name'] as String? ?? 'Unknown',
  role: (json['role'] as num?)?.toInt() ?? 1,
  active: json['active'] as bool? ?? false,
  color: json['color'] as String? ?? '#ffffff',
);

Map<String, dynamic> _$FoundryUserToJson(FoundryUser instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'role': instance.role,
      'active': instance.active,
      'color': instance.color,
    };
