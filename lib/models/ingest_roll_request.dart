import 'package:json_annotation/json_annotation.dart';

import 'roll_request.dart';

part 'ingest_roll_request.g.dart';

/// Payload de red para enviar una tirada al chat de Foundry vía `/ingest`.
/// Se construye a partir de un [RollRequest] de dominio.
@JsonSerializable(explicitToJson: true, createFactory: false)
class IngestRollRequest {
  final String id;
  final String source;
  final String userId;
  final String userName;
  final IngestSpeaker speaker;
  final String flavor;
  final List<IngestRoll> rolls;

  /// Tipo de mensaje de chat de Foundry (5 = roll).
  final int type;
  final int timestamp;

  const IngestRollRequest({
    required this.id,
    required this.source,
    required this.userId,
    required this.userName,
    required this.speaker,
    required this.flavor,
    required this.rolls,
    required this.type,
    required this.timestamp,
  });

  factory IngestRollRequest.fromRollRequest(RollRequest roll) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return IngestRollRequest(
      id: '${now}_${roll.userId.hashCode & 0xffff}',
      source: 'mobile',
      userId: roll.userId,
      userName: roll.characterName,
      speaker: IngestSpeaker(alias: roll.characterName),
      flavor: roll.flavor,
      rolls: [
        IngestRoll(
          formula: roll.formula,
          total: roll.total,
          values: roll.values,
        ),
      ],
      type: 5,
      timestamp: now,
    );
  }

  Map<String, dynamic> toJson() => _$IngestRollRequestToJson(this);
}

@JsonSerializable(createFactory: false)
class IngestSpeaker {
  final String alias;

  const IngestSpeaker({required this.alias});

  Map<String, dynamic> toJson() => _$IngestSpeakerToJson(this);
}

@JsonSerializable(createFactory: false)
class IngestRoll {
  final String formula;
  final int total;
  final List<int> values;

  const IngestRoll({
    required this.formula,
    required this.total,
    required this.values,
  });

  Map<String, dynamic> toJson() => _$IngestRollToJson(this);
}
