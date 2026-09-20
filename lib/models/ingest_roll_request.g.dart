// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ingest_roll_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$IngestRollRequestToJson(IngestRollRequest instance) =>
    <String, dynamic>{
      'id': instance.id,
      'source': instance.source,
      'userId': instance.userId,
      'userName': instance.userName,
      'speaker': instance.speaker.toJson(),
      'flavor': instance.flavor,
      'rolls': instance.rolls.map((e) => e.toJson()).toList(),
      'type': instance.type,
      'timestamp': instance.timestamp,
    };

Map<String, dynamic> _$IngestSpeakerToJson(IngestSpeaker instance) =>
    <String, dynamic>{'alias': instance.alias};

Map<String, dynamic> _$IngestRollToJson(IngestRoll instance) =>
    <String, dynamic>{
      'formula': instance.formula,
      'total': instance.total,
      'values': instance.values,
    };
