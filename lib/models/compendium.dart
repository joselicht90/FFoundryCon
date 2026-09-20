/// Un pack del compendio (colección de Items o JournalEntries).
class CompendiumPack {
  final String id; // ej. "dnd5e.spells"
  final String label;
  final String type; // "Item" | "JournalEntry"
  final String? system;

  const CompendiumPack({
    required this.id,
    required this.label,
    required this.type,
    this.system,
  });

  bool get isItem => type == 'Item';

  factory CompendiumPack.fromJson(Map<String, dynamic> j) => CompendiumPack(
        id: j['id'] as String? ?? '',
        label: j['label'] as String? ?? (j['id'] as String? ?? 'Pack'),
        type: j['type'] as String? ?? 'Item',
        system: j['system'] as String?,
      );
}

/// Una entrada del índice de un pack (o resultado de búsqueda).
class CompendiumEntry {
  final String id;
  final String name;
  final String? type; // "spell" | "weapon" | "class" | "feat" | ...
  final String? img;
  final String pack; // pack de origen
  final String? packLabel;
  final int? level; // nivel del conjuro (si aplica)

  const CompendiumEntry({
    required this.id,
    required this.name,
    this.type,
    this.img,
    required this.pack,
    this.packLabel,
    this.level,
  });

  factory CompendiumEntry.fromJson(Map<String, dynamic> j) => CompendiumEntry(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        type: j['type'] as String?,
        img: j['img'] as String?,
        pack: j['pack'] as String? ?? '',
        packLabel: j['packLabel'] as String?,
        level: (j['level'] as num?)?.toInt(),
      );
}

/// Detalle completo de una entrada (con descripción).
class CompendiumDetail {
  final String id;
  final String name;
  final String? type;
  final String? img;
  final String description;

  const CompendiumDetail({
    required this.id,
    required this.name,
    this.type,
    this.img,
    required this.description,
  });

  factory CompendiumDetail.fromJson(Map<String, dynamic> j) => CompendiumDetail(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        type: j['type'] as String?,
        img: j['img'] as String?,
        description: j['description'] as String? ?? '',
      );
}
