/// Resultado de una tirada calculada localmente, listo para enviar al chat
/// de Foundry vía `/ingest`. El armado del payload de red vive en el
/// repositorio; este es el modelo de dominio.
class RollRequest {
  final String userId;
  final String characterName;
  final String flavor;
  final String formula;
  final int total;
  final List<int> values;

  const RollRequest({
    required this.userId,
    required this.characterName,
    required this.flavor,
    required this.formula,
    required this.total,
    required this.values,
  });
}
