/// Una fuente de luz de la escena (antorcha, fogata, etc.).
class SceneLight {
  final double x;
  final double y;
  final double radius; // radio exterior (px)
  final double ratio; // fracción brillante (0..1): hasta acá luz plena, después cae
  final int? color; // ARGB; null = luz neutra
  final List<double> poly; // polígono iluminado (canvas coords)

  const SceneLight({
    required this.x,
    required this.y,
    required this.radius,
    required this.ratio,
    required this.color,
    required this.poly,
  });

  static double _d(dynamic v) =>
      v is num ? v.toDouble() : (v is String ? double.tryParse(v) ?? 0 : 0);

  static int? _color(dynamic v) {
    if (v is! String) return null;
    final h = v.replaceFirst('#', '');
    final n = int.tryParse(h, radix: 16);
    if (n == null) return null;
    return 0xFF000000 | (n & 0xFFFFFF);
  }

  factory SceneLight.fromJson(Map<String, dynamic> j) => SceneLight(
        x: _d(j['x']),
        y: _d(j['y']),
        radius: _d(j['radius']),
        ratio: j['ratio'] is num ? (j['ratio'] as num).toDouble() : 0.5,
        color: _color(j['color']),
        poly: (j['poly'] as List?)?.map((n) => (n as num).toDouble()).toList() ??
            const [],
      );
}

/// Escena activa de Foundry, para renderizar el mapa en la app.
/// Coordenadas en el espacio del canvas (incluye padding).
class FoundryScene {
  final String id;
  final String name;
  final String? thumb; // imagen pre-renderizada de la escena
  final String? background;
  final double canvasWidth;
  final double canvasHeight;
  final double sceneX;
  final double sceneY;
  final double sceneWidth;
  final double sceneHeight;
  final double gridSize;
  final double gridDistance; // ej. 5 (ft por celda)
  final String gridUnits; // ej. "ft"
  final bool globalLight; // iluminación global de la escena
  final double darkness; // nivel de oscuridad 0..1
  final List<SceneLight> lights; // fuentes de luz
  final bool fogExploration; // mapa con capa de exploración (overland)
  final String? fogOverlay; // imagen que ve el jugador en zonas no exploradas

  const FoundryScene({
    required this.id,
    required this.name,
    this.thumb,
    this.background,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.sceneX,
    required this.sceneY,
    required this.sceneWidth,
    required this.sceneHeight,
    required this.gridSize,
    this.gridDistance = 5,
    this.gridUnits = 'ft',
    this.globalLight = false,
    this.darkness = 0,
    this.lights = const [],
    this.fogExploration = false,
    this.fogOverlay,
  });

  /// Preferimos el background full-res; el thumb es el fallback (borroso).
  String? get image => background ?? thumb;

  /// Imagen según el rol: en mapas de exploración el jugador ve el overlay
  /// (con el pergamino en lo no explorado); el GM ve el mapa completo.
  String? imageFor({required bool isGM}) {
    if (!isGM && fogExploration && fogOverlay != null) return fogOverlay;
    return image;
  }

  static double _d(dynamic v, double fb) =>
      v is num ? v.toDouble() : (v is String ? double.tryParse(v) ?? fb : fb);

  factory FoundryScene.fromJson(Map<String, dynamic> j) => FoundryScene(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? 'Escena',
        thumb: j['thumb'] as String?,
        background: j['background'] as String?,
        canvasWidth: _d(j['canvasWidth'], 1000),
        canvasHeight: _d(j['canvasHeight'], 1000),
        sceneX: _d(j['sceneX'], 0),
        sceneY: _d(j['sceneY'], 0),
        sceneWidth: _d(j['sceneWidth'], 1000),
        sceneHeight: _d(j['sceneHeight'], 1000),
        gridSize: _d(j['gridSize'], 100),
        gridDistance: _d(j['gridDistance'], 5),
        gridUnits: j['gridUnits'] as String? ?? 'ft',
        globalLight: j['globalLight'] as bool? ?? false,
        darkness: _d(j['darkness'], 0),
        lights: (j['lights'] as List?)
                ?.map((l) => SceneLight.fromJson(l as Map<String, dynamic>))
                .toList() ??
            const [],
        fogExploration: j['fogExploration'] as bool? ?? false,
        fogOverlay: j['fogOverlay'] as String?,
      );
}
