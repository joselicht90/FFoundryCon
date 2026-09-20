import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/actor_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/foundry_actor.dart';
import 'sheet_dialogs.dart';
import 'sheet_kit.dart';

const _typeLabels = {
  'weapon': 'Arma',
  'equipment': 'Equipo',
  'consumable': 'Consumible',
  'tool': 'Herramienta',
  'loot': 'Botín',
  'container': 'Contenedor',
  'backpack': 'Contenedor',
};

class _RowEntry {
  final ActorItem item;
  final int depth;
  final bool hasChildren;
  final bool expanded;
  _RowEntry({
    required this.item,
    required this.depth,
    required this.hasChildren,
    required this.expanded,
  });
}

class InventoryList extends ConsumerStatefulWidget {
  final FoundryActor actor;
  const InventoryList({super.key, required this.actor});

  @override
  ConsumerState<InventoryList> createState() => _InventoryListState();
}

class _InventoryListState extends ConsumerState<InventoryList> {
  String _q = '';
  final Set<String> _expanded = {};
  final Set<String> _partyExpanded = {};

  @override
  Widget build(BuildContext context) {
    final actor = widget.actor;
    final party = actor.party;
    final hasParty = party != null && party.items.isNotEmpty;
    if (actor.items.isEmpty && !hasParty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.backpack_outlined, size: 44, color: AppColors.label),
            SizedBox(height: 10),
            Text('Sin objetos', style: TextStyle(color: AppColors.label)),
          ],
        ),
      );
    }

    final q = _q.trim().toLowerCase();
    final rows = _buildRows(actor.items, q, _expanded);
    final partyRows =
        hasParty ? _buildRows(party.items, q, _partyExpanded) : const <_RowEntry>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
      children: [
        SheetSearchField(
          hint: 'Buscar objeto…',
          onChanged: (v) => setState(() => _q = v),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(right: 2, bottom: 9),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text('${actor.items.length} objetos',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.gold, fontWeight: FontWeight.w600)),
          ),
        ),
        _rowsCard(rows, _expanded, null),
        if (hasParty) ...[
          const SizedBox(height: 4),
          SectionHeader('Party · ${party.name}'),
          _rowsCard(partyRows, _partyExpanded, party.id),
        ],
      ],
    );
  }

  /// Tarjeta con las filas del inventario. [ownerId] no nulo = items de party
  /// (las acciones editan al actor compartido).
  Widget _rowsCard(List<_RowEntry> rows, Set<String> expandedSet, String? ownerId) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text('Sin resultados', style: TextStyle(color: AppColors.label)),
        ),
      );
    }
    return SheetCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++)
            _ItemRow(
              entry: rows[i],
              last: i == rows.length - 1,
              ownerId: ownerId,
              onToggleExpand: () => setState(() {
                final id = rows[i].item.id;
                if (expandedSet.contains(id)) {
                  expandedSet.remove(id);
                } else {
                  expandedSet.add(id);
                }
              }),
            ),
        ],
      ),
    );
  }

  /// Arma la lista aplanada (con profundidad) respetando contenedores
  /// expandidos y filtrando por búsqueda (incluye contenido anidado).
  List<_RowEntry> _buildRows(
      List<ActorItem> items, String q, Set<String> expandedSet) {
    final byId = {for (final it in items) it.id: it};
    final childrenOf = <String, List<ActorItem>>{};
    for (final it in items) {
      final cid = it.containerId;
      if (cid != null && byId.containsKey(cid)) {
        (childrenOf[cid] ??= []).add(it);
      }
    }
    final topLevel = items
        .where((it) => it.containerId == null || !byId.containsKey(it.containerId))
        .toList();

    bool selfMatches(ActorItem it) => q.isEmpty || it.name.toLowerCase().contains(q);
    bool subtreeMatches(ActorItem it) {
      if (selfMatches(it)) return true;
      for (final c in childrenOf[it.id] ?? const <ActorItem>[]) {
        if (subtreeMatches(c)) return true;
      }
      return false;
    }

    final rows = <_RowEntry>[];
    void walk(List<ActorItem> list, int depth) {
      final sorted = [...list]..sort((a, b) => a.name.compareTo(b.name));
      for (final it in sorted) {
        if (!subtreeMatches(it)) continue;
        final kids = childrenOf[it.id] ?? const <ActorItem>[];
        final hasKids = kids.isNotEmpty;
        // Mientras se busca, los contenedores con coincidencias se
        // muestran expandidos automáticamente.
        final isOpen = (q.isNotEmpty && hasKids) || expandedSet.contains(it.id);
        rows.add(_RowEntry(item: it, depth: depth, hasChildren: hasKids, expanded: isOpen));
        if (hasKids && isOpen) {
          walk(kids, depth + 1);
        }
      }
    }

    walk(topLevel, 0);
    return rows;
  }
}

bool _equippable(ActorItem it) =>
    it.type == 'weapon' || it.type == 'equipment';

/// Checkbox para equipar / desequipar (armas y equipo), con spinner de carga.
/// Se ubica debajo de la info principal del item, en una fila horizontal.
class _EquipToggle extends ConsumerStatefulWidget {
  final ActorItem item;
  final String? ownerId;
  const _EquipToggle({required this.item, this.ownerId});

  @override
  ConsumerState<_EquipToggle> createState() => _EquipToggleState();
}

class _EquipToggleState extends ConsumerState<_EquipToggle> {
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(actorControllerProvider.notifier)
          .setEquipped(widget.item.id, !widget.item.equipped,
              actorId: widget.ownerId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo equipar: $e')),
        );
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final eq = widget.item.equipped;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _toggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: _busy
                  ? const Padding(
                      padding: EdgeInsets.all(2),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.gold))
                  : Checkbox(
                      value: eq,
                      onChanged: (_) => _toggle(),
                      activeColor: AppColors.gold,
                      checkColor: Colors.black,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
            ),
            const SizedBox(width: 6),
            Text(eq ? 'Equipado' : 'Guardado',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: eq ? AppColors.gold : AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends ConsumerWidget {
  final _RowEntry entry;
  final bool last;
  final String? ownerId; // no nulo = item de party (edita para todos)
  final VoidCallback onToggleExpand;
  const _ItemRow(
      {required this.entry,
      required this.last,
      required this.onToggleExpand,
      this.ownerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final it = entry.item;
    final meta = [
      _typeLabels[it.type] ?? it.type,
      if (it.uses != null) '${it.uses!.value}/${it.uses!.max}',
    ].join(' · ');
    return Container(
      padding: EdgeInsets.fromLTRB(14 + entry.depth * 18, 9, 14, 9),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: Color(0x0BFFFFFF))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            // Tocar la fila abre descripción + acciones.
            onTap: () => showActionInfoDialog(context, ref,
                itemId: it.id,
                name: it.name,
                meta: meta,
                description: it.description,
                hasAttack: it.hasAttack,
                hasDamage: it.damage != null,
                canUse: it.canUse,
                needsTargets: it.needsTargets,
                hasResource: it.uses != null,
                activities: it.activities,
                ownerId: ownerId),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it.name,
                          style: const TextStyle(fontSize: 14, color: AppColors.listText)),
                      Text(
                        it.hasAttack && (it.toHit != null || it.damage != null)
                            ? [
                                if (it.toHit != null) '⚔ ${it.toHit}',
                                if (it.damage != null) it.damage,
                              ].join(' · ')
                            : [
                                _typeLabels[it.type] ?? it.type,
                                if (it.quantity != 1) '×${it.quantity}',
                              ].join(' · '),
                        style: const TextStyle(fontSize: 10, color: AppColors.label),
                      ),
                    ],
                  ),
                ),
                // Indicador de que la fila tiene acciones/descripción.
                Icon(
                  it.hasAttack || it.canUse ? Icons.chevron_right : Icons.info_outline,
                  size: 18,
                  color: AppColors.label,
                ),
                // Botón de expandir contenedor: siempre a la derecha de todo.
                if (entry.hasChildren)
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: onToggleExpand,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6, top: 4, bottom: 4),
                      child: Icon(
                        entry.expanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_equippable(it))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _EquipToggle(item: it, ownerId: ownerId),
            ),
        ],
      ),
    );
  }
}
