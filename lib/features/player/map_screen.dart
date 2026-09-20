import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/actor_controller.dart';
import '../../controllers/session_controller.dart';
import '../../controllers/token_controller.dart';
import '../../core/network/image_url.dart';
import '../../core/network/reader_url_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/foundry_scene.dart';
import '../../models/foundry_token.dart';
import '../../repositories/foundry_repository.dart';

class MapScreen extends ConsumerStatefulWidget {
  /// embedded = sin Scaffold/AppBar (para usar como pestaña dentro de otra pantalla).
  final bool embedded;
  const MapScreen({super.key, this.embedded = false});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  FoundryScene? _scene;
  List<FoundryToken> _tokens = [];
  String? _selectedId;
  bool _loading = true;
  String? _error;
  Timer? _poll;

  String? _dragId;
  Offset? _dragLocal; // posición del dedo en coords del mapa (sin escalar)
  double _s = 1; // escala px-canvas → px-pantalla (de la escena)

  // Posiciones optimistas (token movido) hasta que Foundry confirme.
  final Map<String, ({double x, double y})> _pending = {};

  // Modo medir distancias.
  bool _measure = false;
  Offset? _measA; // coords canvas
  Offset? _measB;

  @override
  void initState() {
    super.initState();
    _load(first: true);
    _poll = Timer.periodic(const Duration(milliseconds: 1500), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  bool _canControl(FoundryToken t) {
    final user = ref.read(selectedUserProvider);
    return (user?.isGM ?? false) || (user != null && t.ownedBy(user.id));
  }

  List<FoundryToken> _applyPending(List<FoundryToken> tokens) {
    if (_pending.isEmpty) return tokens;
    return tokens.map((t) {
      final p = _pending[t.id];
      if (p == null) return t;
      if ((t.x - p.x).abs() < 1 && (t.y - p.y).abs() < 1) {
        _pending.remove(t.id); // Foundry ya lo aplicó
        return t;
      }
      return t.copyWith(x: p.x, y: p.y); // mantener optimista
    }).toList();
  }

  Future<void> _load({bool first = false}) async {
    try {
      final map = await ref.read(foundryRepositoryProvider).getMap();
      if (!mounted) return;
      setState(() {
        _scene = map.scene ?? _scene;
        _tokens = _applyPending(map.tokens);
        _loading = false;
        _error = null;
        if (_selectedId == null || !_tokens.any((t) => t.id == _selectedId)) {
          final actorId = ref.read(actorControllerProvider).valueOrNull?.id;
          final mine = _tokens.where(_canControl).toList();
          if (mine.isNotEmpty) {
            _selectedId = mine
                .firstWhere((t) => t.actorId == actorId, orElse: () => mine.first)
                .id;
          }
        }
      });
    } catch (e) {
      if (mounted && first) setState(() { _loading = false; _error = '$e'; });
    }
  }

  Future<void> _step(StepDirection dir) async {
    final id = _selectedId;
    if (id == null) return;
    try {
      await ref.read(tokenControllerProvider.notifier).step(id, dir);
      await _load();
    } catch (_) {}
  }

  // ---------- drag ----------
  void _onDragStart(FoundryScene scene, List<FoundryToken> visible, Offset local) {
    if (_measure) return;
    final cx = local.dx / _s + scene.sceneX;
    final cy = local.dy / _s + scene.sceneY;
    for (final t in visible.reversed) {
      if (!_canControl(t)) continue;
      final tw = t.gw * scene.gridSize, th = t.gh * scene.gridSize;
      if (cx >= t.x && cx <= t.x + tw && cy >= t.y && cy <= t.y + th) {
        setState(() { _dragId = t.id; _dragLocal = local; _selectedId = t.id; });
        return;
      }
    }
  }

  Future<void> _onDragEnd(FoundryScene scene) async {
    final id = _dragId;
    final local = _dragLocal;
    if (id == null || local == null) {
      setState(() { _dragId = null; _dragLocal = null; });
      return;
    }
    FoundryToken? t;
    for (final x in _tokens) {
      if (x.id == id) t = x;
    }
    final grid = scene.gridSize;
    final cx = local.dx / _s + scene.sceneX;
    final cy = local.dy / _s + scene.sceneY;
    final gw = t?.gw ?? 1, gh = t?.gh ?? 1;
    final nx = ((cx - gw * grid / 2) / grid).round() * grid;
    final ny = ((cy - gh * grid / 2) / grid).round() * grid;
    setState(() {
      _dragId = null;
      _dragLocal = null;
      _pending[id] = (x: nx.toDouble(), y: ny.toDouble());
      _tokens = _tokens.map((x) => x.id == id ? x.copyWith(x: nx.toDouble(), y: ny.toDouble()) : x).toList();
    });
    try {
      await ref.read(tokenControllerProvider.notifier).moveTo(id, nx, ny);
    } catch (_) {}
  }

  // ---------- measure ----------
  void _onTapMeasure(FoundryScene scene, Offset local) {
    if (!_measure) return;
    final c = Offset(local.dx / _s + scene.sceneX, local.dy / _s + scene.sceneY);
    setState(() {
      if (_measA == null || _measB != null) {
        _measA = c;
        _measB = null;
      } else {
        _measB = c;
      }
    });
  }

  String _measLabel(FoundryScene scene) {
    if (_measA == null || _measB == null) return '';
    final dxCells = (_measB!.dx - _measA!.dx).abs() / scene.gridSize;
    final dyCells = (_measB!.dy - _measA!.dy).abs() / scene.gridSize;
    final cells = max(dxCells, dyCells); // 5e: diagonal = 1 casilla
    final dist = (cells * scene.gridDistance).round();
    return '$dist ${scene.gridUnits}';
  }

  void _toggleMeasure() => setState(() {
        _measure = !_measure;
        _measA = null;
        _measB = null;
      });

  @override
  Widget build(BuildContext context) {
    final scene = _scene;
    final isGM = ref.watch(selectedUserProvider)?.isGM ?? false;
    final content = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(child: Text('Error: $_error'))
            : scene == null
                ? const Center(
                    child: Text('No hay escena activa',
                        style: TextStyle(color: AppColors.label)))
                : Stack(
                    children: [
                      Positioned.fill(child: _map(scene, isGM)),
                      _overlay(scene),
                    ],
                  );

    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(
        title: Text(scene?.name ?? 'Mapa'),
        actions: [
          IconButton(
            tooltip: 'Medir distancia',
            isSelected: _measure,
            icon: const Icon(Icons.straighten),
            selectedIcon: const Icon(Icons.straighten),
            color: _measure ? AppColors.gold : null,
            onPressed: _toggleMeasure,
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _map(FoundryScene scene, bool isGM) {
    final sw = scene.sceneWidth > 0 ? scene.sceneWidth : 1000.0;
    final sh = scene.sceneHeight > 0 ? scene.sceneHeight : 1000.0;
    final ar = (sw / sh).clamp(0.1, 10.0);

    // Fog of war: los jugadores ven solo lo iluminado dentro de la visión de sus tokens.
    final fogTokens = isGM
        ? const <FoundryToken>[]
        : [
            for (final t in _tokens)
              if (_canControl(t) && t.vision.length >= 6) t,
          ];

    // Región visible (coords del canvas) para ocultar tokens en la oscuridad.
    final region = isGM ? null : visibleRegionCanvas(fogTokens, scene);
    final visible = _tokens.where((t) => _tokenVisible(scene, t, isGM, region)).toList();

    return InteractiveViewer(
      minScale: 0.4,
      maxScale: 8,
      boundaryMargin: const EdgeInsets.all(80),
      child: Center(
        child: AspectRatio(
          aspectRatio: ar,
          child: LayoutBuilder(
            builder: (ctx, cons) {
              _s = cons.maxWidth / sw;
              return GestureDetector(
                onTapUp: (d) => _onTapMeasure(scene, d.localPosition),
                onLongPressStart: (d) => _onDragStart(scene, visible, d.localPosition),
                onLongPressMoveUpdate: (d) {
                  if (_dragId != null) setState(() => _dragLocal = d.localPosition);
                },
                onLongPressEnd: (_) => _onDragEnd(scene),
                child: Stack(
                  children: [
                    // Sin fondo: solo una grilla igual a la de Foundry.
                    Positioned.fill(
                      child: Container(
                        color: const Color(0xFF15171B),
                        child: CustomPaint(
                          painter: _GridPainter(scene: scene, s: _s),
                        ),
                      ),
                    ),
                    if (_measA != null)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _MeasurePainter(
                            a: _measA!, b: _measB, scene: scene, s: _s),
                        ),
                      ),
                    for (final t in visible) _marker(scene, t),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Un token se muestra si: es GM, es propio (siempre), o —para jugadores— no
  /// está oculto y su centro cae dentro de la región visible (luz/visión).
  bool _tokenVisible(
      FoundryScene scene, FoundryToken t, bool isGM, Path? region) {
    if (isGM) return true;
    if (t.hidden) return false;
    if (_canControl(t)) return true;
    if (region == null) return true; // sin datos de visión → no ocultamos
    final c = Offset(
        t.x + t.gw * scene.gridSize / 2, t.y + t.gh * scene.gridSize / 2);
    return region.contains(c);
  }

  Widget _marker(FoundryScene scene, FoundryToken t) {
    final base = ref.read(readerUrlProvider);
    final size = (t.gw * scene.gridSize * _s).toDouble();
    final h = (t.gh * scene.gridSize * _s).toDouble();
    final dragging = t.id == _dragId && _dragLocal != null;
    final double left, top;
    if (dragging) {
      left = _dragLocal!.dx - size / 2;
      top = _dragLocal!.dy - h / 2;
    } else {
      left = (t.x - scene.sceneX) * _s;
      top = (t.y - scene.sceneY) * _s;
    }
    final selected = t.id == _selectedId;
    final controllable = _canControl(t);
    final color = t.isHostile
        ? AppColors.tokenEnemy
        : (t.isFriendly || controllable)
            ? AppColors.tokenAlly
            : const Color(0xFF555A63);
    final url = foundryImageUrl(base, t.img);

    return Positioned(
      left: left,
      top: top,
      width: size,
      height: h,
      child: IgnorePointer(
        child: Opacity(
          opacity: dragging ? 0.75 : 1,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              image: url != null
                  ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
                  : null,
              border: Border.all(
                color: (selected || dragging) ? AppColors.gold : color,
                width: (selected || dragging) ? (size * 0.08).clamp(1.5, 4).toDouble() : 1,
              ),
            ),
            alignment: Alignment.center,
            child: url == null && size > 16
                ? Text(t.name.isNotEmpty ? t.name[0].toUpperCase() : '?',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: (size * 0.4).clamp(8, 22).toDouble()))
                : null,
          ),
        ),
      ),
    );
  }

  // ---------- overlay de controles ----------
  Widget _overlay(FoundryScene scene) {
    final movable = _tokens.where(_canControl).toList();
    return Stack(
      children: [
        // Botón de medir (en modo embebido no hay AppBar con la acción).
        if (widget.embedded)
          Positioned(
            top: 10,
            right: 10,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _toggleMeasure,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _measure
                      ? AppColors.gold.withAlpha(60)
                      : Colors.black.withAlpha(160),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _measure ? AppColors.gold : AppColors.gold.withAlpha(110)),
                ),
                child: const Icon(Icons.straighten, color: AppColors.gold, size: 20),
              ),
            ),
          ),
        if (_measure)
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(160),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.gold.withAlpha(90)),
                ),
                child: Text(
                  _measA == null
                      ? 'Tocá el punto A'
                      : _measB == null
                          ? 'Tocá el punto B'
                          : _measLabel(scene),
                  style: const TextStyle(
                      color: AppColors.gold, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
          ),
        // chips de tokens controlables (abajo)
        if (movable.isNotEmpty && !_measure)
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: movable.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final t = movable[i];
                  final seld = t.id == _selectedId;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedId = t.id),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: seld ? AppColors.gold.withAlpha(70) : Colors.black.withAlpha(150),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: seld ? AppColors.gold : AppColors.gold.withAlpha(60)),
                      ),
                      child: Text(t.name,
                          style: TextStyle(
                              fontSize: 12,
                              color: seld ? AppColors.gold : AppColors.parchment)),
                    ),
                  );
                },
              ),
            ),
          ),
        // D-pad flotante (abajo a la derecha)
        if (_selectedId != null && !_measure)
          Positioned(
            right: 10,
            bottom: 48,
            child: _dpad(),
          ),
      ],
    );
  }

  Widget _dpad() {
    Widget btn(IconData ic, StepDirection d) => InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _step(d),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(160),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.gold.withAlpha(110)),
            ),
            child: Icon(ic, color: AppColors.gold, size: 20),
          ),
        );
    const gap = SizedBox(width: 4, height: 4);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(Icons.keyboard_arrow_up, StepDirection.up),
        gap,
        Row(mainAxisSize: MainAxisSize.min, children: [
          btn(Icons.keyboard_arrow_left, StepDirection.left),
          gap,
          btn(Icons.keyboard_arrow_right, StepDirection.right),
        ]),
        gap,
        btn(Icons.keyboard_arrow_down, StepDirection.down),
      ],
    );
  }
}

/// Región que el jugador alcanza a ver, en coordenadas del canvas (no de
/// pantalla), para poder testear si un token cae dentro (fog of war).
/// Devuelve null si no hay tokens con visión (no ocultamos nada).
Path? visibleRegionCanvas(List<FoundryToken> tokens, FoundryScene scene) {
  if (tokens.isEmpty) return null;

  Path poly(List<double> flat) {
    final pts = <Offset>[];
    for (var i = 0; i + 1 < flat.length; i += 2) {
      pts.add(Offset(flat[i], flat[i + 1]));
    }
    final p = Path();
    if (pts.length >= 3) p.addPolygon(pts, true);
    return p;
  }

  Offset center(FoundryToken t) =>
      Offset(t.x + t.gw * scene.gridSize / 2, t.y + t.gh * scene.gridSize / 2);
  Path uni(Path? a, Path b) =>
      a == null ? b : Path.combine(PathOperation.union, a, b);

  Path? lightsU;
  if (!scene.globalLight) {
    for (final l in scene.lights) {
      if (l.poly.length >= 6) lightsU = uni(lightsU, poly(l.poly));
    }
  }
  Path? vis;
  for (final t in tokens) {
    final los = poly(t.vision);
    if (scene.globalLight) {
      vis = uni(vis, los);
      continue;
    }
    var lit = Path();
    if (t.sightRadius > 0) {
      final circle = Path()
        ..addOval(Rect.fromCircle(center: center(t), radius: t.sightRadius));
      lit = Path.combine(PathOperation.intersect, los, circle);
    }
    if (lightsU != null) {
      lit = Path.combine(PathOperation.union, lit,
          Path.combine(PathOperation.intersect, los, lightsU));
    }
    vis = uni(vis, lit);
  }
  return vis;
}

/// Grilla igual a la de Foundry: líneas cada gridSize (coords del canvas),
/// alineadas al origen del canvas y recortadas a la región de la escena.
class _GridPainter extends CustomPainter {
  final FoundryScene scene;
  final double s;
  _GridPainter({required this.scene, required this.s});

  @override
  void paint(Canvas canvas, Size size) {
    final g = scene.gridSize;
    if (g <= 0 || g * s <= 4) return; // demasiado chica para dibujar
    final paint = Paint()
      ..color = const Color(0x1FFFFFFF)
      ..strokeWidth = 1;

    // Líneas verticales: primer múltiplo de g >= sceneX.
    final startX = (scene.sceneX / g).ceilToDouble() * g;
    for (var cx = startX; cx <= scene.sceneX + scene.sceneWidth; cx += g) {
      final x = (cx - scene.sceneX) * s;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // Líneas horizontales.
    final startY = (scene.sceneY / g).ceilToDouble() * g;
    for (var cy = startY; cy <= scene.sceneY + scene.sceneHeight; cy += g) {
      final y = (cy - scene.sceneY) * s;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.s != s || old.scene != scene;
}

class _MeasurePainter extends CustomPainter {
  final Offset a;
  final Offset? b;
  final FoundryScene scene;
  final double s;
  _MeasurePainter({required this.a, required this.b, required this.scene, required this.s});

  Offset _toScreen(Offset c) =>
      Offset((c.dx - scene.sceneX) * s, (c.dy - scene.sceneY) * s);

  @override
  void paint(Canvas canvas, Size size) {
    final pa = _toScreen(a);
    final dot = Paint()..color = AppColors.gold;
    canvas.drawCircle(pa, 5, dot);
    if (b != null) {
      final pb = _toScreen(b!);
      final line = Paint()
        ..color = AppColors.gold
        ..strokeWidth = 2.5;
      canvas.drawLine(pa, pb, line);
      canvas.drawCircle(pb, 5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _MeasurePainter old) =>
      old.a != a || old.b != b || old.s != s;
}
