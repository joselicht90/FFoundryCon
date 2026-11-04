import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../../core/network/foundry_url_provider.dart';
import '../../../core/theme/app_theme.dart';

/// Tab "Foundry": carga el cliente real de Foundry en una WebView (login en el
/// form de Foundry, la app nunca ve la contraseña) y le inyecta el adaptador
/// móvil de `assets/foundry_mobile/`, que abre la hoja de [actorId] a pantalla
/// completa sin canvas. La tab es inmersiva (sin chrome de la app): [onExit]
/// vuelve a la tab anterior. Mientras está [active] maneja el back del
/// sistema. Ver `docs/engineering/architecture.md`.
class FoundrySheetPage extends ConsumerStatefulWidget {
  final String actorId;
  final bool active;
  final VoidCallback onExit;
  const FoundrySheetPage({
    super.key,
    required this.actorId,
    required this.active,
    required this.onExit,
  });

  @override
  ConsumerState<FoundrySheetPage> createState() => _FoundrySheetPageState();
}

class _FoundrySheetPageState extends ConsumerState<FoundrySheetPage>
    with AutomaticKeepAliveClientMixin {
  // Foundry tarda en cargar: no recargar al cambiar de tab.
  @override
  bool get wantKeepAlive => true;

  // Nueva por URL: cambiarla recrea la WebView.
  GlobalKey<_FoundryWebViewState>? _webKey;
  String? _webUrl;

  /// Back del sistema: primero cierra lo que esté encima de la hoja en
  /// Foundry; si no había nada, sale de la tab.
  Future<void> _back() async {
    final web = _webKey?.currentState;
    if (web != null && await web.handleBack()) return;
    widget.onExit();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final url = ref.watch(foundryUrlProvider);
    return PopScope(
      canPop: !widget.active,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: _body(url),
    );
  }

  Widget _body(String? url) {
    if (url == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Configurá la URL de Foundry en Configuración para ver la hoja real.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.sub),
              ),
              const SizedBox(height: 12),
              _ExitButton(onExit: widget.onExit),
            ],
          ),
        ),
      );
    }
    if (url != _webUrl) {
      _webUrl = url;
      _webKey = GlobalKey();
    }
    return _FoundryWebView(
      key: _webKey,
      baseUrl: url,
      actorId: widget.actorId,
      onExit: widget.onExit,
    );
  }
}

class _FoundryWebView extends StatefulWidget {
  final String baseUrl;
  final String actorId;
  final VoidCallback onExit;
  const _FoundryWebView({
    super.key,
    required this.baseUrl,
    required this.actorId,
    required this.onExit,
  });

  @override
  State<_FoundryWebView> createState() => _FoundryWebViewState();
}

class _FoundryWebViewState extends State<_FoundryWebView> {
  late final WebViewController _web;
  late final String _origin;
  late final Uri _join;
  late final Uri _game;
  late final Future<String> _adapter;
  int _progress = 0;
  bool _failed = false;
  // En /game las acciones de la app están en el menú que el adaptador agrega
  // al chat; fuera (login de Foundry) no hay chat y se muestra el overlay.
  bool _inGame = false;
  // Alto del notch/cámara, del indicador de inicio y del teclado: la WebView
  // va por detrás de los tres (no se redimensiona al abrir el teclado: Foundry
  // re-layoutea todo en cada resize) y el adaptador los respeta vía
  // --ffc-safe-top / --ffc-safe-bottom / --ffc-kb.
  double _safeTop = 0;
  double _safeBottom = 0;
  double _keyboard = 0;
  bool _pushingInsets = false;
  bool _insetsDirty = false;

  @override
  void initState() {
    super.initState();
    final base = Uri.parse(widget.baseUrl);
    _origin = base.origin;
    _join = base.replace(path: '${base.path}/join');
    _game = base.replace(path: '${base.path}/game');
    _adapter = _loadAdapter();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.bg)
      ..addJavaScriptChannel('FFoundryCon', onMessageReceived: _onAppCommand)
      ..setNavigationDelegate(
        NavigationDelegate(
          // Solo el origin de Foundry; cualquier otro destino se bloquea.
          onNavigationRequest: (req) {
            final target = Uri.tryParse(req.url);
            final allowed =
                req.url == 'about:blank' ||
                (target != null &&
                    target.hasScheme &&
                    target.origin == _origin);
            return allowed
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageStarted: (url) {
            if (mounted) {
              setState(() {
                _failed = false;
                _inGame = Uri.tryParse(url)?.path.endsWith('/game') ?? false;
              });
            }
          },
          onPageFinished: _inject,
          onWebResourceError: (err) {
            if (err.isForMainFrame ?? false) {
              if (mounted) setState(() => _failed = true);
            }
          },
        ),
      )
      // /game reusa la sesión guardada en las cookies (entra directo); sin
      // sesión el servidor de Foundry redirige a /join.
      ..loadRequest(_game);
    if (kDebugMode) {
      _enableInspection();
      _forwardConsole();
    }
  }

  // Solo debug: errores y warnings de la consola de Foundry (MidiQOL, dnd5e)
  // a la consola de `flutter run`. En release no se registra nada: pueden
  // incluir datos del mundo.
  void _forwardConsole() {
    _web.setOnConsoleMessage((m) {
      if (m.level == JavaScriptLogLevel.error ||
          m.level == JavaScriptLogLevel.warning) {
        debugPrint('[Foundry ${m.level.name}] ${m.message}');
      }
    });
  }

  /// Solo debug: permite inspeccionar el DOM de Foundry desde chrome://inspect
  /// (Android) o Safari Web Inspector (iOS 16.4+) para ajustar el adaptador.
  void _enableInspection() {
    final platform = _web.platform;
    if (platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
    } else if (platform is WebKitWebViewController) {
      platform.setInspectable(true);
    }
  }

  Future<String> _loadAdapter() async {
    final js = await rootBundle.loadString('assets/foundry_mobile/adapter.js');
    final css = await rootBundle.loadString(
      'assets/foundry_mobile/adapter.css',
    );
    final config = jsonEncode({'actorId': widget.actorId, 'css': css});
    // Termina en `true`: WKWebView falla si el script evalúa a undefined. Los
    // errores del adaptador salen por consola (en debug, ver _forwardConsole).
    return '(() => { const FFC = $config;\n$js\n})();\ntrue;';
  }

  /// Foundry marca al usuario como activo (grisado en /join) mientras su
  /// socket siga abierto. Navegar a about:blank lo cierra al salir de la
  /// pantalla, por si la WebView nativa sobrevive al widget.
  @override
  void dispose() {
    _web.loadRequest(Uri.parse('about:blank'));
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final padding = MediaQuery.viewPaddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    if (padding.top != _safeTop ||
        padding.bottom != _safeBottom ||
        keyboard != _keyboard) {
      _safeTop = padding.top;
      _safeBottom = padding.bottom;
      _keyboard = keyboard;
      _pushInsets();
    }
  }

  /// El teclado anima el inset cuadro a cuadro: una sola llamada en vuelo y,
  /// al terminar, se reenvía el último valor si cambió mientras tanto.
  Future<void> _pushInsets() async {
    if (_pushingInsets) {
      _insetsDirty = true;
      return;
    }
    _pushingInsets = true;
    try {
      do {
        _insetsDirty = false;
        await _web.runJavaScript(
          // Bloque: un `const` global repetido fallaría en la segunda llamada.
          '{ const s = document.documentElement.style;'
          " s.setProperty('--ffc-safe-top', '${_safeTop}px');"
          " s.setProperty('--ffc-safe-bottom', '${_safeBottom}px');"
          " s.setProperty('--ffc-kb', '${_keyboard}px'); }",
        );
      } while (_insetsDirty);
    } catch (_) {
      // Sin página cargada todavía: se aplica en el próximo _inject.
    } finally {
      _pushingInsets = false;
    }
  }

  /// Comandos del menú de la app que el adaptador agrega a la barra del chat.
  /// Set cerrado: cualquier otro mensaje (otros scripts de la página) se
  /// ignora.
  void _onAppCommand(JavaScriptMessage message) {
    switch (message.message) {
      case 'exit':
        widget.onExit();
      case 'reload':
        _web.reload();
      case 'logout':
        _logOut();
    }
  }

  /// Back del sistema: el adaptador cierra el panel de objetivos, el chat o la
  /// ventana de más arriba (items, contenedores, diálogos). false si no había
  /// nada que cerrar (o no hay adaptador: login de Foundry).
  Future<bool> handleBack() async {
    try {
      final closed = await _web.runJavaScriptReturningResult(
        'window.__ffcBack?.() === true',
      );
      return closed == true || closed == 1 || closed.toString() == 'true';
    } catch (_) {
      return false;
    }
  }

  /// La sesión de Foundry vive en las cookies de la WebView (al abrir /game
  /// entra directo con el último usuario). Borrarlas y volver a /join permite
  /// elegir otro usuario.
  Future<void> _logOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión de Foundry'),
        content: const Text(
          'Vas a volver a la pantalla de ingreso de Foundry para elegir usuario.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await WebViewCookieManager().clearCookies();
    await _web.loadRequest(_join);
  }

  Future<void> _inject(String url) async {
    try {
      await _web.runJavaScript(await _adapter);
      if (kDebugMode) {
        final ran = await _web.runJavaScriptReturningResult(
          'window.__ffcAdapter === true',
        );
        debugPrint(
          '[FFoundryCon adapter] ${Uri.tryParse(url)?.path}: ran=$ran',
        );
      }
    } catch (e) {
      // Página sin JS ejecutable (p.ej. error de red): no hay nada que adaptar.
      // Solo debug: un error del adaptador mismo quedaría invisible.
      if (kDebugMode) {
        // El NSError de WKWebView solo dice algo en code/domain/userInfo.
        final details = e is PlatformException ? e.details as dynamic : null;
        debugPrint(
          '[FFoundryCon adapter] $e'
          '${details == null ? '' : ' code=${details.code} '
                    'domain=${details.domain} userInfo=${details.userInfo}'}',
        );
      }
    }
    await _pushInsets();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: AppColors.orange),
            const SizedBox(height: 8),
            const Text(
              'No se pudo cargar Foundry',
              style: TextStyle(color: AppColors.sub),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ExitButton(onExit: widget.onExit),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _web.reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ],
        ),
      );
    }
    // Arriba y abajo la WebView va por detrás del notch y del indicador de
    // inicio (los maneja el adaptador); los costados respetan el área segura.
    return SafeArea(
      top: false,
      bottom: false,
      child: Stack(
        children: [
          WebViewWidget(controller: _web),
          if (_progress < 100)
            LinearProgressIndicator(
              value: _progress / 100,
              minHeight: 2,
              color: AppColors.gold,
              backgroundColor: Colors.transparent,
            ),
          // Fuera de /game (login de Foundry): sin chat ni su menú, la salida
          // queda abajo a la izquierda.
          if (!_inGame)
            Positioned(
              left: 12,
              bottom: 16 + _safeBottom,
              child: Material(
                color: AppColors.bg.withAlpha(200),
                shape: StadiumBorder(
                  side: BorderSide(color: AppColors.gold.withAlpha(90)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Volver',
                      visualDensity: VisualDensity.compact,
                      onPressed: widget.onExit,
                      icon: const Icon(
                        Icons.arrow_back,
                        size: 20,
                        color: AppColors.gold,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Recargar Foundry',
                      visualDensity: VisualDensity.compact,
                      onPressed: _web.reload,
                      icon: const Icon(
                        Icons.refresh,
                        size: 20,
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExitButton extends StatelessWidget {
  final VoidCallback onExit;
  const _ExitButton({required this.onExit});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onExit,
    icon: const Icon(Icons.arrow_back),
    label: const Text('Volver'),
  );
}
