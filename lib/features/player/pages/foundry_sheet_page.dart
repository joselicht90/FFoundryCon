import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/network/foundry_url_provider.dart';
import '../../../core/theme/app_theme.dart';

/// Tab "Foundry": carga el cliente real de Foundry en una WebView (login en el
/// form de Foundry, la app nunca ve la contraseña) y le inyecta el adaptador
/// móvil de `assets/foundry_mobile/`, que abre la hoja de [actorId] a pantalla
/// completa sin canvas. Ver `docs/engineering/architecture.md`.
class FoundrySheetPage extends ConsumerStatefulWidget {
  final String actorId;
  const FoundrySheetPage({super.key, required this.actorId});

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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Configurá la URL de Foundry en Configuración para ver la hoja real.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.sub),
          ),
        ),
      );
    }
    return _FoundryWebView(
      key: ValueKey(url),
      baseUrl: url,
      actorId: widget.actorId,
    );
  }
}

class _FoundryWebView extends StatefulWidget {
  final String baseUrl;
  final String actorId;
  const _FoundryWebView({
    super.key,
    required this.baseUrl,
    required this.actorId,
  });

  @override
  State<_FoundryWebView> createState() => _FoundryWebViewState();
}

class _FoundryWebViewState extends State<_FoundryWebView> {
  late final WebViewController _web;
  late final String _origin;
  late final Future<String> _adapter;
  int _progress = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final base = Uri.parse(widget.baseUrl);
    _origin = base.origin;
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
      ..loadRequest(base.replace(path: '${base.path}/join'));
  }

  Future<String> _loadAdapter() async {
    final js = await rootBundle.loadString('assets/foundry_mobile/adapter.js');
    final css = await rootBundle.loadString(
      'assets/foundry_mobile/adapter.css',
    );
    final config = jsonEncode({'actorId': widget.actorId, 'css': css});
    return '(() => { const FFC = $config;\n$js\n})();';
  }

  Future<void> _inject() async {
    try {
      await _web.runJavaScript(await _adapter);
    } catch (_) {
      // Página sin JS ejecutable (p.ej. error de red): no hay nada que adaptar.
    }
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
            OutlinedButton.icon(
              onPressed: _web.reload,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    return Stack(
      children: [
        WebViewWidget(controller: _web),
        if (_progress < 100)
          LinearProgressIndicator(
            value: _progress / 100,
            minHeight: 2,
            color: AppColors.gold,
            backgroundColor: Colors.transparent,
          ),
        Positioned(
          left: 12,
          bottom: 12,
          child: IconButton.filledTonal(
            tooltip: 'Recargar Foundry',
            onPressed: _web.reload,
            icon: const Icon(Icons.refresh, size: 20),
          ),
        ),
      ],
    );
  }
}
