import 'package:json_annotation/json_annotation.dart';

part 'foundry_user.g.dart';

/// Un usuario del mundo de Foundry.
@JsonSerializable()
class FoundryUser {
  final String id;

  @JsonKey(defaultValue: 'Unknown')
  final String name;

  /// 4 = GM, 3 = Assistant, 2 = Trusted, 1 = Player.
  @JsonKey(defaultValue: 1)
  final int role;

  @JsonKey(defaultValue: false)
  final bool active;

  @JsonKey(defaultValue: '#ffffff')
  final String color;

  const FoundryUser({
    required this.id,
    required this.name,
    required this.role,
    required this.active,
    required this.color,
  });

  bool get isGM => role >= 3;

  factory FoundryUser.fromJson(Map<String, dynamic> json) =>
      _$FoundryUserFromJson(json);

  Map<String, dynamic> toJson() => _$FoundryUserToJson(this);
}
