import 'package:json_annotation/json_annotation.dart';

part 'foundry_token.g.dart';

/// Un token en la escena activa de Foundry.
@JsonSerializable()
class FoundryToken {
  final String id;

  @JsonKey(defaultValue: 'Token')
  final String name;

  @JsonKey(defaultValue: 0)
  final double x;

  @JsonKey(defaultValue: 0)
  final double y;

  /// Tamaño del token en celdas de grilla.
  @JsonKey(defaultValue: 1)
  final num gw;
  @JsonKey(defaultValue: 1)
  final num gh;

  final String? actorId;

  final String? img;

  @JsonKey(defaultValue: false)
  final bool hidden;

  /// -2 secreto, -1 hostil, 0 neutral, 1 amistoso.
  @JsonKey(defaultValue: 0)
  final int disposition;

  /// Ids de usuarios que controlan (poseen) el actor del token.
  @JsonKey(defaultValue: <String>[])
  final List<String> ownerIds;

  /// Polígono de línea de visión [x0,y0,x1,y1,...] en coords del canvas.
  /// Vacío si el token no tiene visión (fog of war).
  @JsonKey(defaultValue: <double>[])
  final List<double> vision;

  /// Radio de visión en oscuridad (darkvision) en px del canvas. 0 = no ve a oscuras.
  @JsonKey(defaultValue: 0)
  final double sightRadius;

  const FoundryToken({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    this.gw = 1,
    this.gh = 1,
    this.actorId,
    this.img,
    this.hidden = false,
    this.disposition = 0,
    this.ownerIds = const [],
    this.vision = const [],
    this.sightRadius = 0,
  });

  bool get isFriendly => disposition >= 1;
  bool get isHostile => disposition == -1;
  bool get isSecret => disposition <= -2;

  bool ownedBy(String userId) => ownerIds.contains(userId);

  FoundryToken copyWith({double? x, double? y}) => FoundryToken(
        id: id,
        name: name,
        x: x ?? this.x,
        y: y ?? this.y,
        gw: gw,
        gh: gh,
        actorId: actorId,
        img: img,
        hidden: hidden,
        disposition: disposition,
        ownerIds: ownerIds,
        vision: vision,
        sightRadius: sightRadius,
      );

  factory FoundryToken.fromJson(Map<String, dynamic> json) =>
      _$FoundryTokenFromJson(json);

  Map<String, dynamic> toJson() => _$FoundryTokenToJson(this);
}

/// Direcciones de movimiento por casilla.
enum StepDirection {
  up,
  down,
  left,
  right;

  String get wire => name;
}
