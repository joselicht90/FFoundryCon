import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/actor_controller.dart';
import '../../core/network/image_url.dart';
import '../../core/network/reader_url_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/compendium.dart';
import '../../repositories/foundry_repository.dart';
import 'widgets/sheet_kit.dart';

/// Filtros de tipo de item (mapean a los `type` de dnd5e).
const _typeFilters = <({String label, String? type})>[
  (label: 'Todos', type: null),
  (label: 'Conjuros', type: 'spell'),
  (label: 'Armas', type: 'weapon'),
  (label: 'Equipo', type: 'equipment'),
  (label: 'Dotes', type: 'feat'),
  (label: 'Clases', type: 'class'),
];

const _itemTypeLabels = {
  'spell': 'Conjuro',
  'weapon': 'Arma',
  'equipment': 'Equipo',
  'consumable': 'Consumible',
  'tool': 'Herramienta',
  'loot': 'Botín',
  'feat': 'Dote',
  'class': 'Clase',
  'subclass': 'Subclase',
  'background': 'Trasfondo',
  'race': 'Especie',
  'container': 'Contenedor',
};

class CompendiumScreen extends ConsumerStatefulWidget {
  const CompendiumScreen({super.key});

  @override
  ConsumerState<CompendiumScreen> createState() => _CompendiumScreenState();
}

class _CompendiumScreenState extends ConsumerState<CompendiumScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Compendio'),
          bottom: const TabBar(
            indicatorColor: AppColors.gold,
            labelColor: AppColors.gold,
            unselectedLabelColor: AppColors.muted,
            tabs: [
              Tab(text: 'Buscar'),
              Tab(text: 'Compendios'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _SearchTab(),
            _PacksTab(),
          ],
        ),
      ),
    );
  }
}

// ---------------- Buscar ----------------

class _SearchTab extends ConsumerStatefulWidget {
  const _SearchTab();

  @override
  ConsumerState<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<_SearchTab>
    with AutomaticKeepAliveClientMixin {
  String _q = '';
  String? _type;
  List<CompendiumEntry>? _results;
  bool _loading = false;
  String? _error;
  Timer? _debounce;
  int _reqSeq = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _search);
  }

  Future<void> _search() async {
    final seq = ++_reqSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await ref
          .read(foundryRepositoryProvider)
          .compendiumSearch(_q.trim(), type: _type);
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        _results = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final results = _results;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: SheetSearchField(
            hint: 'Buscar conjuro, objeto, dote…',
            onChanged: (v) {
              _q = v;
              _scheduleSearch();
            },
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final f in _typeFilters)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(f.label),
                    selected: _type == f.type,
                    selectedColor: AppColors.gold.withAlpha(60),
                    onSelected: (_) {
                      setState(() => _type = f.type);
                      _search();
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _CompendiumError(error: _error!, onRetry: _search)
                  : results == null
                      ? const _CompendiumHint(
                          'Escribí un nombre o elegí un filtro para buscar en el compendio.')
                      : results.isEmpty
                          ? const _CompendiumHint('Sin resultados.')
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                              itemCount: results.length,
                              itemBuilder: (_, i) => _EntryRow(entry: results[i]),
                            ),
        ),
      ],
    );
  }
}

// ---------------- Compendios (packs) ----------------

class _PacksTab extends ConsumerStatefulWidget {
  const _PacksTab();

  @override
  ConsumerState<_PacksTab> createState() => _PacksTabState();
}

class _PacksTabState extends ConsumerState<_PacksTab>
    with AutomaticKeepAliveClientMixin {
  late Future<List<CompendiumPack>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = ref.read(foundryRepositoryProvider).compendiumPacks();
  }

  void _reload() {
    setState(() {
      _future = ref.read(foundryRepositoryProvider).compendiumPacks();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<CompendiumPack>>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _CompendiumError(error: '${snap.error}', onRetry: _reload);
        }
        final packs = snap.data ?? const <CompendiumPack>[];
        if (packs.isEmpty) {
          return const _CompendiumHint('No hay compendios disponibles.');
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: packs.length,
          itemBuilder: (_, i) {
            final p = packs[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SheetCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: Icon(
                    p.isItem ? Icons.inventory_2_outlined : Icons.menu_book_outlined,
                    color: AppColors.gold,
                  ),
                  title: Text(p.label,
                      style: const TextStyle(color: AppColors.listText)),
                  subtitle: Text(p.type == 'Item' ? 'Objetos' : 'Reglas / Diario',
                      style: const TextStyle(color: AppColors.label, fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => _PackIndexScreen(pack: p),
                  )),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PackIndexScreen extends ConsumerStatefulWidget {
  final CompendiumPack pack;
  const _PackIndexScreen({required this.pack});

  @override
  ConsumerState<_PackIndexScreen> createState() => _PackIndexScreenState();
}

class _PackIndexScreenState extends ConsumerState<_PackIndexScreen> {
  late Future<List<CompendiumEntry>> _future;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _future = ref.read(foundryRepositoryProvider).compendiumIndex(widget.pack.id);
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    return Scaffold(
      appBar: AppBar(title: Text(widget.pack.label)),
      body: FutureBuilder<List<CompendiumEntry>>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _CompendiumError(
                error: '${snap.error}',
                onRetry: () => setState(() {
                      _future = ref
                          .read(foundryRepositoryProvider)
                          .compendiumIndex(widget.pack.id);
                    }));
          }
          final all = snap.data ?? const <CompendiumEntry>[];
          final entries = q.isEmpty
              ? all
              : all.where((e) => e.name.toLowerCase().contains(q)).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: SheetSearchField(
                  hint: 'Filtrar…',
                  onChanged: (v) => setState(() => _q = v),
                ),
              ),
              Expanded(
                child: entries.isEmpty
                    ? const _CompendiumHint('Sin resultados.')
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                        itemCount: entries.length,
                        itemBuilder: (_, i) => _EntryRow(
                            entry: entries[i], journal: !widget.pack.isItem),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------- Fila de entrada + detalle ----------------

class _EntryRow extends ConsumerWidget {
  final CompendiumEntry entry;
  final bool journal;
  const _EntryRow({required this.entry, this.journal = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ref.watch(readerUrlProvider);
    final url = foundryImageUrl(base, entry.img);
    final sub = [
      if (entry.type != null) _itemTypeLabels[entry.type] ?? entry.type!,
      if (entry.level != null)
        entry.level == 0 ? 'Truco' : 'Nivel ${entry.level}',
      if (entry.packLabel != null) entry.packLabel!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SheetCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: AppColors.card,
              image: url != null
                  ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
                  : null,
            ),
            child: url == null
                ? const Icon(Icons.auto_awesome, size: 18, color: AppColors.muted)
                : null,
          ),
          title:
              Text(entry.name, style: const TextStyle(color: AppColors.listText)),
          subtitle: sub.isEmpty
              ? null
              : Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.label, fontSize: 11)),
          trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
          onTap: () => _showEntryDetail(context, ref, entry, journal: journal),
        ),
      ),
    );
  }
}

Future<void> _showEntryDetail(
  BuildContext context,
  WidgetRef ref,
  CompendiumEntry entry, {
  bool journal = false,
}) async {
  // Cargamos el detalle con un diálogo de progreso.
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  CompendiumDetail? detail;
  String? err;
  try {
    detail = await ref
        .read(foundryRepositoryProvider)
        .compendiumEntry(entry.pack, entry.id);
  } catch (e) {
    err = '$e';
  }
  if (!context.mounted) return;
  Navigator.of(context).pop(); // cierra el spinner
  if (detail == null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('No se pudo cargar: $err')));
    return;
  }

  final d = detail;
  final canAdd = !journal; // solo Items se agregan a la hoja
  await showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.bgAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.gold.withAlpha(60)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75, maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.name,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.name)),
                  if (d.type != null) ...[
                    const SizedBox(height: 2),
                    Text(_itemTypeLabels[d.type] ?? d.type!,
                        style: const TextStyle(fontSize: 11, color: AppColors.gold)),
                  ],
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                child: Text(
                    d.description.trim().isEmpty
                        ? 'Sin descripción.'
                        : d.description,
                    style: const TextStyle(
                        fontSize: 13, height: 1.45, color: AppColors.listText)),
              ),
            ),
            const Divider(height: 1, color: Color(0x14FFFFFF)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cerrar')),
                  if (canAdd)
                    _AddButton(entry: entry, name: d.name),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Botón "Agregar a personaje" con spinner de carga.
class _AddButton extends ConsumerStatefulWidget {
  final CompendiumEntry entry;
  final String name;
  const _AddButton({required this.entry, required this.name});

  @override
  ConsumerState<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends ConsumerState<_AddButton> {
  bool _busy = false;

  Future<void> _add() async {
    if (_busy) return;
    final actor = ref.read(actorControllerProvider).valueOrNull;
    if (actor == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(actorControllerProvider.notifier)
          .addFromCompendium(widget.entry.pack, widget.entry.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.name} agregado a ${actor.name}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo agregar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final actor = ref.watch(actorControllerProvider).valueOrNull;
    return FilledButton.icon(
      style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold, foregroundColor: Colors.black),
      icon: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
          : const Icon(Icons.add, size: 16),
      onPressed: (actor == null || _busy) ? null : _add,
      label: const Text('Agregar'),
    );
  }
}

class _CompendiumHint extends StatelessWidget {
  final String text;
  const _CompendiumHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.label)),
      ),
    );
  }
}

class _CompendiumError extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _CompendiumError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, color: AppColors.orange, size: 36),
            const SizedBox(height: 10),
            const Text('Requiere Foundry abierto (GM online)',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.label)),
            const SizedBox(height: 6),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 11)),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
