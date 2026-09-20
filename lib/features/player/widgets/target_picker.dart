import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/session_controller.dart';
import '../../../core/network/image_url.dart';
import '../../../core/network/reader_url_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/foundry_token.dart';
import '../../../repositories/foundry_repository.dart';

/// Resultado del picker: objetivos elegidos (vacío = sin objetivo), si la
/// tirada es manual (dados en la mesa) y si NO se debe consumir el recurso.
typedef TargetResult = ({List<String> ids, bool manual, bool noConsume});

/// Elige objetivos para un ataque/conjuro. Devuelve [TargetResult] o `null` si
/// se canceló. Si no se elige ningún objetivo, se ataca sin objetivo.
/// [hasResource] habilita el toggle "No consumir recurso".
Future<TargetResult?> showTargetPicker(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  bool multi = true,
  bool hasResource = false,
}) {
  return showModalBottomSheet<TargetResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bgAlt,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _TargetSheet(title: title, multi: multi, hasResource: hasResource),
  );
}

class _TargetSheet extends ConsumerStatefulWidget {
  final String title;
  final bool multi;
  final bool hasResource;
  const _TargetSheet(
      {required this.title, required this.multi, this.hasResource = false});

  @override
  ConsumerState<_TargetSheet> createState() => _TargetSheetState();
}

class _TargetSheetState extends ConsumerState<_TargetSheet> {
  List<FoundryToken> _tokens = [];
  final Set<String> _selected = {};
  bool _loading = true;
  String? _error;
  // Toggle por-ataque, default OFF (no persiste): no contamina el flujo normal.
  bool _manual = false;
  bool _noConsume = false;
  int _tab = 0; // 0 = enemigos (default), 1 = aliados

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final map = await ref.read(foundryRepositoryProvider).getMap();
      if (!mounted) return;
      // Mostrar tokens visibles; los enemigos primero suelen ser el objetivo.
      final user = ref.read(selectedUserProvider);
      final isGM = user?.isGM ?? false;
      final list = map.tokens.where((t) => isGM || !t.hidden).toList()
        ..sort((a, b) => a.disposition.compareTo(b.disposition));
      setState(() {
        _tokens = list;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = '$e'; });
    }
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        if (!widget.multi) _selected.clear();
        _selected.add(id);
      }
    });
  }

  Color _color(FoundryToken t) => t.isHostile
      ? AppColors.tokenEnemy
      : (t.isFriendly ? AppColors.tokenAlly : const Color(0xFF8A8F98));

  String _disp(FoundryToken t) =>
      t.isHostile ? 'Enemigo' : (t.isFriendly ? 'Aliado' : 'Neutral');

  Widget _tabBtn(String label, int idx, Color color) {
    final sel = _tab == idx;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _tab = idx),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? color.withAlpha(40) : AppColors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? color : color.withAlpha(50), width: sel ? 1.5 : 1),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: sel ? color : AppColors.label)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = ref.watch(readerUrlProvider);
    final bottom = MediaQuery.of(context).padding.bottom;
    // Enemigos y aliados en pestañas separadas (enemigos por defecto).
    final enemies = _tokens.where((t) => t.isHostile).toList();
    final allies = _tokens.where((t) => !t.isHostile).toList();
    final shown = _tab == 0 ? enemies : allies;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(0, 10, 0, bottom + 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.gold.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Row(
                children: [
                  const Icon(Icons.gps_fixed, size: 18, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Objetivos · ${widget.title}',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.name)),
                  ),
                ],
              ),
            ),
            if (!_loading && _error == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: Row(
                  children: [
                    _tabBtn('Enemigos (${enemies.length})', 0, AppColors.tokenEnemy),
                    const SizedBox(width: 8),
                    _tabBtn('Aliados (${allies.length})', 1, AppColors.tokenAlly),
                  ],
                ),
              ),
            Flexible(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(28),
                      child: CircularProgressIndicator())
                  : _error != null
                      ? Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text('No se pudieron leer los tokens.\n$_error',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.label)))
                      : shown.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                  _tab == 0 ? 'No hay enemigos visibles' : 'No hay aliados visibles',
                                  style: const TextStyle(color: AppColors.label)))
                          : ListView.builder(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: shown.length,
                              itemBuilder: (_, i) {
                                final t = shown[i];
                                final sel = _selected.contains(t.id);
                                final color = _color(t);
                                final url = foundryImageUrl(base, t.img);
                                return InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _toggle(t.id),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: sel ? color.withAlpha(36) : AppColors.card,
                                      border: Border.all(
                                          color: sel ? color : color.withAlpha(60),
                                          width: sel ? 2 : 1),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: color.withAlpha(40),
                                            image: url != null
                                                ? DecorationImage(
                                                    image: NetworkImage(url),
                                                    fit: BoxFit.cover)
                                                : null,
                                            border: Border.all(color: color, width: 1.5),
                                          ),
                                          alignment: Alignment.center,
                                          child: url == null
                                              ? Text(
                                                  t.name.isNotEmpty
                                                      ? t.name[0].toUpperCase()
                                                      : '?',
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold))
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(t.name,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppColors.listText)),
                                              Text(_disp(t),
                                                  style: TextStyle(
                                                      fontSize: 11, color: color)),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          sel
                                              ? Icons.check_circle
                                              : Icons.radio_button_unchecked,
                                          color: sel ? color : AppColors.muted,
                                          size: 22,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
            const SizedBox(height: 4),
            // Toggle de tirada manual (dados en la mesa), al momento de atacar.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                dense: true,
                activeThumbColor: AppColors.gold,
                title: const Text('Dados en la mesa (manual)',
                    style: TextStyle(fontSize: 13, color: AppColors.listText)),
                value: _manual,
                onChanged: (v) => setState(() => _manual = v),
              ),
            ),
            // Toggle "no consumir recurso" (mismo lugar que dados en la mesa).
            if (widget.hasResource)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  dense: true,
                  activeThumbColor: AppColors.gold,
                  title: const Text('No consumir recurso',
                      style: TextStyle(fontSize: 13, color: AppColors.listText)),
                  value: _noConsume,
                  onChanged: (v) => setState(() => _noConsume = v),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop((
                  ids: _selected.toList(),
                  manual: _manual,
                  noConsume: _noConsume,
                )),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(46),
                ),
                child: Text(_selected.isEmpty
                    ? 'Aceptar (sin objetivo)'
                    : 'Aceptar (${_selected.length})'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
