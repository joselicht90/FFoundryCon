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
/// vuelve a la tab anterior. Ver `docs/engineering/architecture.md`.
class FoundrySheetPage extends ConsumerStatefulWidget {
  final String actorId;
  final VoidCallback onExit;
  const FoundrySheetPage({
    super.key,
    required this.actorId,
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final url = ref.watch(foundryUrlProvider);
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
    return _FoundryWebView(
      key: ValueKey(url),
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
  late final Future<String> _adapter;
  int _progress = 0;
  bool _failed = false;
  // Alto del notch/cámara: la WebView va por detrás y el adaptador lo respeta
  // vía la variable CSS --ffc-safe-top.
  double _safeTop = 0;

  @override
  void initState() {
    super.initState();
    final base = Uri.parse(widget.baseUrl);
    _origin = base.origin;
    _join = base.replace(path: '${base.path}/join');
    _adapter = _loadAdapter();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.bg)
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
          onPageStarted: (_) {
            if (mounted) setState(() => _failed = false);
          },
          onPageFinished: (_) => _inject(),
          onWebResourceError: (err) {
            if (err.isForMainFrame ?? false) {
              if (mounted) setState(() => _failed = true);
            }
          },
        ),
      )
      ..loadRequest(_join);
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
    return '(() => { const FFC = $config;\n$js\n})();';
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
    final top = MediaQuery.viewPaddingOf(context).top;
    if (top != _safeTop) {
      _safeTop = top;
      _pushSafeTop();
    }
  }

  Future<void> _pushSafeTop() async {
    try {
      await _web.runJavaScript(
        "document.documentElement.style.setProperty('--ffc-safe-top', '${_safeTop}px');",
      );
    } catch (_) {
      // Sin página cargada todavía: se aplica en el próximo _inject.
    }
  }

  /// La sesión de Foundry vive en las cookies de la WebView y sobrevive a
  /// reinicios (entra directo con el último usuario). Borrarlas y volver a
  /// /join permite elegir otro usuario.
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

  Future<void> _inject() async {
    try {
      await _web.runJavaScript(await _adapter);
    } catch (_) {
      // Página sin JS ejecutable (p.ej. error de red): no hay nada que adaptar.
    }
    await _pushSafeTop();
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
    // Arriba la WebView va por detrás del notch (lo maneja el adaptador con
    // --ffc-safe-top); el resto del borde sí respeta el área segura.
    return SafeArea(
      top: false,
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
          // Abajo a la izquierda, por encima de la barra de tabs de la hoja
          // (52px, adapter.css); a la derecha está el botón de chat.
          Positioned(
            left: 12,
            bottom: 64,
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
                  IconButton(
                    tooltip: 'Cerrar sesión de Foundry',
                    visualDensity: VisualDensity.compact,
                    onPressed: _logOut,
                    icon: const Icon(
                      Icons.logout,
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
