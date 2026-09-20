import 'package:json_annotation/json_annotation.dart';

part 'foundry_world.g.dart';

/// Un mundo de Foundry, leído del filesystem del volumen (`worlds/<id>/`).
/// `id` es el nombre de la carpeta; `title` sale del `world.json`.
@JsonSerializable()
class FoundryWorld {
  final String id;

  @JsonKey(defaultValue: 'Foundry')
  final String title;

  /// Ruta de la portada (relativa al volumen de Foundry) o null.
  final String? image;
  final String? system;

  const FoundryWorld({
    required this.id,
    required this.title,
    this.image,
    this.system,
  });

  factory FoundryWorld.fromJson(Map<String, dynamic> json) =>
      _$FoundryWorldFromJson(json);

  Map<String, dynamic> toJson() => _$FoundryWorldToJson(this);
}
