/// Una regla de la casa (guardada en Mongo vía el reader).
class Rule {
  final String id;
  final String title;
  final String body;

  const Rule({required this.id, required this.title, required this.body});

  Rule copyWith({String? title, String? body}) =>
      Rule(id: id, title: title ?? this.title, body: body ?? this.body);

  factory Rule.fromJson(Map<String, dynamic> j) => Rule(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
      );
}
