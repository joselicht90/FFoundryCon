import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/actor_controller.dart';
import '../../../controllers/session_controller.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/foundry_actor.dart';
import 'roll_card.dart';
import 'sheet_kit.dart';
import 'target_picker.dart';
import '../../../repositories/foundry_repository.dart';

void sheetToast(BuildContext c, String msg) {
  ScaffoldMessenger.of(c).showSnackBar(
    SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
  );
}

/// Cantidad de popups de tirada abiertos. El watcher global de resultados
/// (ver PlayerScreen) evita mostrar un snackbar cuando ya hay un popup arriba.
final rollPopupOpenProvider = StateProvider<int>((ref) => 0);

/// Igual que [showRollDialog] pero contabiliza el popup abierto para no
/// duplicar el snackbar de resultado.
Future<void> _showRollTracked(
  WidgetRef ref,
  BuildContext c,
  String flavor,
  Future<({int? total, String? formula, List<int> dice})> future,
) async {
  final n = ref.read(rollPopupOpenProvider.notifier);
  n.state++;
  try {
    await showRollDialog(c, flavor, future);
  } finally {
    n.state--;
  }
}

/// Tira ability/save/skill. Con [pick] abre el selector de ventaja/desventaja.
/// Online: tirada nativa de dnd5e al chat. Offline: cálculo local + log en Mongo.
Future<void> rollAction(
  BuildContext c,
  WidgetRef ref,
  RollKind kind,
  String key,
  String label, {
  bool pick = false,
}) async {
  var mode = RollMode.normal;
  if (pick) {
    final m = await showRollModeSheet(c, label);
    if (m == null) return;
    mode = m;
  }

  final actor = ref.read(actorControllerProvider).valueOrNull;
  if (!c.mounted) return;

  if (actor != null && actor.offline) {
    final mod = _modifierFor(actor, kind, key);
    final formula = _d20Formula(mod, mode);
    await _showRollTracked(
      ref,
      c,
      label,
      _sendLocalRoll(c, ref, label, formula).then(_rollResult),
    );
    return;
  }

  await _showRollTracked(
    ref,
    c,
    label,
    ref.read(actorControllerProvider.notifier).roll(kind, key, mode).then(_mapResult),
  );
}

({int? total, String? formula, List<int> dice}) _mapResult(Map<String, dynamic> m) => (
      total: (m['total'] as num?)?.toInt(),
      formula: m['formula'] as String?,
      dice: (m['dice'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [],
    );

({int? total, String? formula, List<int> dice}) _rollResult(
        ({int total, String formula, List<int> dice}) r) =>
    (total: r.total, formula: r.formula, dice: r.dice);

int _modifierFor(FoundryActor a, RollKind kind, String key) {
  switch (kind) {
    case RollKind.ability:
      return a.abilities[key]?.mod ?? 0;
    case RollKind.save:
      return a.abilities[key]?.save ?? 0;
    case RollKind.skill:
      return a.skills[key]?.total ?? 0;
    case RollKind.init:
      return a.initiative ?? 0;
  }
}

/// Evalúa una fórmula con notación de dados, incluyendo keep-highest/lowest:
/// "2d20kh1 + 5" (ventaja = MAX), "2d20kl1 + 5" (desventaja = MIN), "1d8 + 3".
/// [crit] duplica la cantidad de dados de cada término.
({int total, List<int> values}) _evalFormula(String input, {bool crit = false}) {
  final rng = Random();
  final cleaned = input.replaceAll(' ', '');
  final terms = cleaned.split(RegExp(r'(?=[+-])'));
  var total = 0;
  final values = <int>[];
  for (var raw in terms) {
    if (raw.isEmpty) continue;
    final sign = raw.startsWith('-') ? -1 : 1;
    final t = raw.replaceFirst(RegExp(r'^[+-]'), '');
    final dm = RegExp(r'^(\d*)d(\d+)(k[hl]\d*)?$').firstMatch(t);
    if (dm != null) {
      var n = int.tryParse(dm.group(1) ?? '') ?? 1;
      final faces = int.parse(dm.group(2)!);
      final keep = dm.group(3); // kh1 / kl1 / null
      if (crit) n *= 2;
      final rolled = List.generate(n, (_) => rng.nextInt(faces) + 1);
      values.addAll(rolled);
      if (keep != null && rolled.isNotEmpty) {
        final cnt = int.tryParse(keep.substring(2)) ?? 1;
        final sorted = [...rolled]..sort();
        final kept = keep.startsWith('kh')
            ? sorted.sublist(sorted.length - cnt)
            : sorted.sublist(0, cnt);
        total += sign * kept.fold(0, (a, b) => a + b);
      } else {
        total += sign * rolled.fold(0, (a, b) => a + b);
      }
    } else {
      final flat = int.tryParse(t);
      if (flat != null) total += sign * flat;
    }
  }
  return (total: total, values: values);
}

/// Tira una fórmula localmente (offline), la postea al chat y devuelve el resultado.
Future<({int total, String formula, List<int> dice})> _sendLocalRoll(
  BuildContext c,
  WidgetRef ref,
  String flavor,
  String formula, {
  bool crit = false,
}) async {
  final r = _evalFormula(formula, crit: crit);
  final actor = ref.read(actorControllerProvider).valueOrNull;
  final user = ref.read(selectedUserProvider);
  try {
    await ref.read(foundryRepositoryProvider).sendChat({
      'author': actor?.name ?? user?.name ?? '?',
      if (user?.color != null) 'authorColor': user!.color,
      if (user?.id != null) 'userId': user!.id,
      'flavor': flavor,
      'roll': {'formula': formula, 'total': r.total, 'values': r.values},
    });
  } catch (_) {/* best-effort */}
  return (total: r.total, formula: formula, dice: r.values);
}

int? _parseMod(String? s) {
  if (s == null) return null;
  final m = RegExp(r'([+-]?\s*\d+)').firstMatch(s);
  return m == null ? null : int.tryParse(m.group(1)!.replaceAll(' ', ''));
}

/// Dado un modificador y un modo, arma la notación de dados para d20.
String _d20Formula(int mod, RollMode mode) {
  final dice = mode == RollMode.adv
      ? '2d20kh1'
      : mode == RollMode.dis
          ? '2d20kl1'
          : '1d20';
  return mod >= 0 ? '$dice + $mod' : '$dice - ${mod.abs()}';
}

/// Muestra el popup de tirada: spinner mientras se resuelve, luego el resultado.
Future<void> showRollDialog(
  BuildContext c,
  String flavor,
  Future<({int? total, String? formula, List<int> dice})> future,
) {
  return showDialog(
    context: c,
    barrierDismissible: true,
    builder: (ctx) => _RollDialog(flavor: flavor, future: future),
  );
}

class _RollDialog extends StatefulWidget {
  final String flavor;
  final Future<({int? total, String? formula, List<int> dice})> future;
  const _RollDialog({required this.flavor, required this.future});

  @override
  State<_RollDialog> createState() => _RollDialogState();
}

class _RollDialogState extends State<_RollDialog> {
  ({int? total, String? formula, List<int> dice})? _res;
  Object? _err;

  @override
  void initState() {
    super.initState();
    widget.future.then((r) {
      if (mounted) setState(() => _res = r);
    }).catchError((e) {
      if (mounted) setState(() => _err = e);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _res;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_err != null)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1D22),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.red.withAlpha(110)),
              ),
              child: Text('Error: $_err', style: const TextStyle(color: AppColors.red)),
            )
          else if (r == null)
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1D22),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.gold.withAlpha(40)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.flavor,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.name)),
                  const SizedBox(height: 14),
                  const SizedBox(
                      width: 38, height: 38, child: CircularProgressIndicator(strokeWidth: 3)),
                  const SizedBox(height: 12),
                  const Text('Tirando…', style: TextStyle(color: AppColors.label)),
                ],
              ),
            )
          else
            // Misma tarjeta que en el chat.
            RollCardView(
              flavor: widget.flavor,
              formula: r.formula,
              total: r.total,
              dice: r.dice,
            ),
          const SizedBox(height: 10),
          Material(
            color: Colors.transparent,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ),
        ],
      ),
    );
  }
}

/// [action]: use | attack | damage. Con [pick] elige ventaja/desventaja
/// (attack) o crítico (damage).
Future<void> useAction(
  BuildContext c,
  WidgetRef ref,
  String itemId,
  String name, {
  String action = 'use',
  bool pick = false,
  String? toHit, // para tirar el ataque offline
  String? damage, // para tirar el daño offline
}) async {
  final actor = ref.read(actorControllerProvider).valueOrNull;
  var mode = 'normal';
  if (pick) {
    if (action == 'damage') {
      final crit = await _critSheet(c, name);
      if (crit == null) return;
      mode = crit;
    } else {
      final m = await showRollModeSheet(c, name);
      if (m == null) return;
      mode = m.wire;
    }
  }

  if (!c.mounted) return;

  // Offline: si tenemos la fórmula cacheada, tiramos local (con popup) y va al chat.
  if (actor != null && actor.offline) {
    if (action == 'attack' && toHit != null) {
      final m = _parseMod(toHit) ?? 0;
      final rm = mode == 'adv'
          ? RollMode.adv
          : mode == 'dis'
              ? RollMode.dis
              : RollMode.normal;
      await _showRollTracked(ref, c, '$name (ataque)',
          _sendLocalRoll(c, ref, '$name (ataque)', _d20Formula(m, rm)).then(_rollResult));
      return;
    }
    if (action == 'damage' && damage != null) {
      await _showRollTracked(
          ref,
          c,
          '$name (daño)${mode == 'crit' ? ' · crít' : ''}',
          _sendLocalRoll(c, ref, '$name (daño)', damage, crit: mode == 'crit')
              .then(_rollResult));
      return;
    }
    sheetToast(c, 'Foundry offline — esto requiere la tab de Foundry abierta');
    return;
  }

  // Online: 'use' (card) no devuelve tirada → toast; attack/damage → popup.
  if (action == 'use') {
    try {
      await ref.read(actorControllerProvider.notifier).use(itemId, action: action, mode: mode);
      if (c.mounted) sheetToast(c, '▶️ $name → chat');
    } catch (e) {
      if (c.mounted) sheetToast(c, 'Error: $e');
    }
    return;
  }

  final flavor = action == 'attack' ? '$name (ataque)' : '$name (daño)';
  await _showRollTracked(
    ref,
    c,
    flavor,
    ref
        .read(actorControllerProvider.notifier)
        .use(itemId, action: action, mode: mode)
        .then(_mapResult),
  );
}

/// Diálogo de acción (items/features): nombre + descripción + botones abajo a
/// la derecha para ejecutar (igual que el de conjuros).
void showActionInfoDialog(
  BuildContext c,
  WidgetRef ref, {
  required String itemId,
  required String name,
  String? meta,
  String? description,
  bool hasAttack = false,
  bool hasDamage = false,
  bool canUse = false,
  bool needsTargets = true,
  bool hasResource = false,
  List<ItemActivity> activities = const [],
  String? ownerId, // actor dueño si es un item de party (edita para todos)
}) {
  final desc = (description ?? '').trim();
  final canAct = hasAttack || canUse;
  showDialog<void>(
    context: c,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.bgAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.gold.withAlpha(60)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.72, maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.name)),
                  if (meta != null && meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(meta,
                        style: const TextStyle(fontSize: 11, color: AppColors.gold)),
                  ],
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                child: Text(desc.isEmpty ? 'Sin descripción.' : desc,
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
                  if (hasDamage && hasAttack)
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        rollDamageTargeted(c, ref,
                            itemId: itemId, name: name, ownerId: ownerId);
                      },
                      child: const Text('Daño'),
                    ),
                  if (canAct)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: Colors.black),
                      icon: const Icon(Icons.gps_fixed, size: 16),
                      onPressed: () {
                        Navigator.pop(ctx);
                        castWithTargets(c, ref,
                            itemId: itemId,
                            name: name,
                            hasAttack: hasAttack,
                            needsTargets: needsTargets,
                            hasResource: hasResource,
                            activities: activities,
                            ownerId: ownerId);
                      },
                      label: Text(hasAttack ? 'Atacar' : 'Usar'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Flujo MidiQOL — ATAQUE: elige objetivos → ventaja → usa el item (Midi tira
/// el ataque contra los targets). El daño se tira aparte con [rollDamageTargeted].
Future<void> castWithTargets(
  BuildContext c,
  WidgetRef ref, {
  required String itemId,
  required String name,
  bool hasAttack = true, // tiene tirada de ataque → pedir ventaja/desventaja
  bool needsTargets = true, // hay que elegir objetivos (no para AoE/save sin target)
  bool hasResource = false, // tiene usos/slot → ofrecer "no consumir recurso"
  List<ItemActivity> activities = const [], // >1 → el jugador elige cuál usar
  bool? autoDamage, // override del setting (ej. "solo ataque" = false)
  String? ownerId, // actor dueño si es item de party (edita para todos)
  int spellLevel = 0, // nivel base del conjuro (0 = no es conjuro nivelado)
  List<int> slotLevels = const [], // niveles con slot disponible (para upcast)
}) async {
  final actor = ref.read(actorControllerProvider).valueOrNull;
  if (actor != null && actor.offline) {
    sheetToast(c, 'Requiere Foundry abierto (MidiQOL)');
    return;
  }

  // Si el item/spell/feat tiene varias activities (ej. Channel Divinity),
  // el jugador elige cuál; usamos su metadata para el resto del flujo.
  String? activityId;
  if (activities.length > 1) {
    final act = await _activityChooser(c, name, activities);
    if (act == null || !c.mounted) return;
    activityId = act.id;
    hasAttack = act.hasAttack;
    needsTargets = act.needsTargets;
  }

  // Upcast: si es un conjuro nivelado y hay slots más altos, elegir a qué
  // nivel lanzarlo.
  int? castLevel;
  if (spellLevel >= 1 && slotLevels.any((l) => l > spellLevel)) {
    final lvl = await _spellLevelSheet(c, name, spellLevel, slotLevels);
    if (lvl == null || !c.mounted) return;
    if (lvl > spellLevel) castLevel = lvl;
  }

  // Objetivos: solo se eligen si la acción los necesita (ataque o targetea
  // criaturas). Fireball (área) no pide objetivos. El toggle "no consumir
  // recurso" vive junto al de "dados en la mesa", dentro del picker.
  var targets = const <String>[];
  var manual = false;
  var noConsume = false;
  if (needsTargets) {
    final res = await showTargetPicker(c, ref, title: name, hasResource: hasResource);
    if (res == null || !c.mounted) return; // cancelado
    targets = res.ids;
    manual = res.manual;
    noConsume = res.noConsume;
  }

  // Modo "dados en mesa": ingresás los totales y se postean a Foundry.
  if (manual) {
    final r = await _manualRollDialog(c, name);
    if (r == null || !c.mounted) return;
    try {
      await ref.read(actorControllerProvider.notifier).manualAttack(itemId,
          targetIds: targets,
          attackTotal: r.attack,
          damageTotal: r.damage,
          crit: r.crit);
      if (c.mounted) sheetToast(c, '$name (mesa) → Foundry');
    } catch (e) {
      if (c.mounted) sheetToast(c, 'Error: $e');
    }
    return;
  }

  // Opciones: ventaja/desventaja (si ataca) y "solo daño" (si ataca). El
  // "no consumir recurso" ya se eligió en el picker cuando había objetivos;
  // si no hubo picker (acción sin objetivos), se ofrece acá.
  final resourceHere = hasResource && !needsTargets;
  var mode = 'normal';
  if (hasAttack || resourceHere) {
    final opt = await _castOptionsSheet(c, name,
        hasAttack: hasAttack, hasResource: resourceHere);
    if (opt == null || !c.mounted) return;
    if (resourceHere) noConsume = opt.noConsume;
    if (opt.damageOnly) {
      final crit = await _critSheet(c, name);
      if (crit == null || !c.mounted) return;
      try {
        await ref.read(actorControllerProvider.notifier).use(itemId,
            action: 'damage', mode: crit, targetIds: targets, actorId: ownerId);
        if (c.mounted) sheetToast(c, 'Daño de $name → Foundry');
      } catch (e) {
        if (c.mounted) sheetToast(c, 'Error: $e');
      }
      return;
    }
    mode = opt.mode;
  }

  final autoDmg = autoDamage ?? ref.read(appSettingsProvider).autoRollDamage;
  try {
    await ref.read(actorControllerProvider.notifier).use(itemId,
        action: 'use',
        mode: mode,
        targetIds: targets,
        autoDamage: autoDmg,
        activityId: activityId,
        noConsume: noConsume,
        castLevel: castLevel,
        actorId: ownerId);
  } catch (e) {
    if (c.mounted) sheetToast(c, 'Error: $e');
    return;
  }
  if (!c.mounted) return;
  sheetToast(c, castLevel != null ? '$name (nivel $castLevel) → Foundry' : '$name → Foundry');
}

/// Elige a qué nivel de slot lanzar un conjuro (upcast). Devuelve el nivel o
/// null si se cancela.
Future<int?> _spellLevelSheet(
    BuildContext c, String name, int baseLevel, List<int> slotLevels) {
  final levels = ({baseLevel, ...slotLevels.where((l) => l >= baseLevel)}.toList()
    ..sort());
  return showModalBottomSheet<int>(
    context: c,
    backgroundColor: AppColors.bgAlt,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$name · nivel de lanzamiento',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.name)),
            const SizedBox(height: 4),
            const Text('Elegí el slot (más alto = upcast).',
                style: TextStyle(fontSize: 12, color: AppColors.label)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final l in levels)
                  ActionChip(
                    backgroundColor: l == baseLevel
                        ? AppColors.gold.withAlpha(40)
                        : AppColors.card,
                    side: BorderSide(color: AppColors.gold.withAlpha(l == baseLevel ? 140 : 60)),
                    label: Text(
                      l == baseLevel ? 'Nivel $l (base)' : 'Nivel $l',
                      style: const TextStyle(color: AppColors.listText, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () => Navigator.pop(ctx, l),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Flujo MidiQOL — DAÑO (paso aparte, cuando el jugador quiera). Pregunta
/// Normal/Crítico y tira el daño (sobre los targets ya apuntados en Foundry).
Future<void> rollDamageTargeted(
  BuildContext c,
  WidgetRef ref, {
  required String itemId,
  required String name,
  String? ownerId,
}) async {
  final actor = ref.read(actorControllerProvider).valueOrNull;
  if (actor != null && actor.offline) {
    sheetToast(c, 'Requiere Foundry abierto (MidiQOL)');
    return;
  }
  final mode = await _critSheet(c, name);
  if (mode == null || !c.mounted) return;
  try {
    await ref
        .read(actorControllerProvider.notifier)
        .use(itemId, action: 'damage', mode: mode, actorId: ownerId);
    if (c.mounted) sheetToast(c, 'Daño de $name → chat');
  } catch (e) {
    if (c.mounted) sheetToast(c, 'Error en daño: $e');
  }
}

/// Opciones al tirar: modo (ventaja/desventaja) si ataca, "solo daño" si ataca,
/// y "no consumir recurso" si el item tiene usos/slot.
Future<({String mode, bool damageOnly, bool noConsume})?> _castOptionsSheet(
    BuildContext c, String name,
    {required bool hasAttack, required bool hasResource}) {
  var mode = 'normal';
  var noConsume = false;
  const modes = [
    ('normal', 'Normal'),
    ('adv', 'Ventaja'),
    ('dis', 'Desventaja'),
  ];
  return showModalBottomSheet<({String mode, bool damageOnly, bool noConsume})>(
    context: c,
    backgroundColor: AppColors.bgAlt,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.name)),
              if (hasAttack) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final m in modes)
                      ChoiceChip(
                        label: Text(m.$2),
                        selected: mode == m.$1,
                        selectedColor: AppColors.gold.withAlpha(60),
                        onSelected: (_) => setS(() => mode = m.$1),
                      ),
                  ],
                ),
              ],
              if (hasResource)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.gold,
                  dense: true,
                  title: const Text('No consumir recurso',
                      style: TextStyle(fontSize: 13, color: AppColors.listText)),
                  value: noConsume,
                  onChanged: (v) => setS(() => noConsume = v),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (hasAttack) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(
                            ctx, (mode: mode, damageOnly: true, noConsume: noConsume)),
                        child: const Text('Solo daño'),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.gold, foregroundColor: Colors.black),
                      onPressed: () => Navigator.pop(
                          ctx, (mode: mode, damageOnly: false, noConsume: noConsume)),
                      child: Text(hasAttack ? 'Tirar' : 'Lanzar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Selector de activity: para items/spells/feats con varias opciones
/// (ej. Channel Divinity). Devuelve la elegida o null si se cancela.
Future<ItemActivity?> _activityChooser(
    BuildContext c, String name, List<ItemActivity> activities) {
  return showModalBottomSheet<ItemActivity>(
    context: c,
    backgroundColor: AppColors.bgAlt,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
            child: Text(name,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.name)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 0, 18, 6),
            child: Text('Elegí una opción',
                style: TextStyle(fontSize: 12, color: AppColors.label)),
          ),
          for (final a in activities)
            ListTile(
              leading: Icon(
                  a.hasAttack ? Icons.sports_martial_arts : Icons.auto_awesome,
                  color: AppColors.gold),
              title: Text(a.name, style: const TextStyle(color: AppColors.listText)),
              onTap: () => Navigator.pop(ctx, a),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Diálogo del modo mesa: ingresar total de ataque + daño (+ crítico).
Future<({int? attack, int? damage, bool crit})?> _manualRollDialog(
    BuildContext c, String name) {
  final atk = TextEditingController();
  final dmg = TextEditingController();
  var crit = false;
  return showDialog<({int? attack, int? damage, bool crit})>(
    context: c,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        backgroundColor: AppColors.bgAlt,
        title: Text(name, style: const TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: atk,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Ataque (total)',
                prefixIcon: Padding(
                  padding: EdgeInsets.all(12),
                  child: D20Icon(size: 20, color: AppColors.gold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dmg,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Daño (total)',
                prefixIcon: Padding(
                  padding: EdgeInsets.all(12),
                  child: SwordIcon(size: 20, color: AppColors.red),
                ),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.gold,
              dense: true,
              title: const Text('Crítico'),
              value: crit,
              onChanged: (v) => setS(() => crit = v ?? false),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, (
              attack: int.tryParse(atk.text.trim()),
              damage: int.tryParse(dmg.text.trim()),
              crit: crit,
            )),
            child: const Text('Enviar'),
          ),
        ],
      ),
    ),
  );
}

Future<String?> _critSheet(BuildContext c, String label) {
  return showModalBottomSheet<String>(
    context: c,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Daño · $label', style: Theme.of(ctx).textTheme.titleMedium),
          ),
          ListTile(
            leading: const Icon(Icons.bloodtype),
            title: const Text('Normal'),
            onTap: () => Navigator.pop(ctx, 'normal'),
          ),
          ListTile(
            leading: const Icon(Icons.local_fire_department, color: Colors.red),
            title: const Text('Crítico (dados dobles)'),
            onTap: () => Navigator.pop(ctx, 'crit'),
          ),
        ],
      ),
    ),
  );
}

Future<void> editAction(
    BuildContext c, WidgetRef ref, Map<String, dynamic> changes) async {
  try {
    await ref.read(actorControllerProvider.notifier).edit(changes);
  } catch (e) {
    if (c.mounted) sheetToast(c, 'Error al guardar: $e');
  }
}

Future<RollMode?> showRollModeSheet(BuildContext c, String label) {
  return showModalBottomSheet<RollMode>(
    context: c,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(label, style: Theme.of(ctx).textTheme.titleMedium),
          ),
          ListTile(
            leading: const Icon(Icons.keyboard_double_arrow_up,
                color: AppColors.green),
            title: const Text('Ventaja'),
            onTap: () => Navigator.pop(ctx, RollMode.adv),
          ),
          ListTile(
            leading: const Icon(Icons.remove),
            title: const Text('Normal'),
            onTap: () => Navigator.pop(ctx, RollMode.normal),
          ),
          ListTile(
            leading: const Icon(Icons.keyboard_double_arrow_down,
                color: AppColors.red),
            title: const Text('Desventaja'),
            onTap: () => Navigator.pop(ctx, RollMode.dis),
          ),
        ],
      ),
    ),
  );
}

/// Pide una cantidad positiva (para daño/curación).
Future<int?> showAmountDialog(BuildContext c, String title, Color color) {
  final ctrl = TextEditingController();
  return showDialog<int>(
    context: c,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          labelText: 'Cantidad',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v.trim())),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: color),
          onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
          child: Text(title),
        ),
      ],
    ),
  );
}

/// Diálogo de curación: cantidad + si va a Vida o a Temp HP.
/// Para Temp HP el valor REEMPLAZA el temp actual (no se acumula).
Future<({int amount, bool temp})?> showHealDialog(BuildContext c, int curTemp) {
  final ctrl = TextEditingController();
  var temp = false;
  return showDialog<({int amount, bool temp})>(
    context: c,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        int? parse() => int.tryParse(ctrl.text.trim());
        void submit() {
          final v = parse();
          if (v != null) Navigator.pop(ctx, (amount: v, temp: temp));
        }

        return AlertDialog(
          title: const Text('Curación'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                      value: false, icon: Icon(Icons.favorite), label: Text('Vida')),
                  ButtonSegment(
                      value: true, icon: Icon(Icons.shield), label: Text('Temp HP')),
                ],
                selected: {temp},
                onSelectionChanged: (s) => setS(() => temp = s.first),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: temp ? 'Temp HP (reemplaza)' : 'Cantidad a curar',
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => submit(),
              ),
              if (temp) ...[
                const SizedBox(height: 8),
                Text('Temp actual: $curTemp. El temp no se acumula: se toma el mayor.',
                    style: const TextStyle(fontSize: 12, color: AppColors.label)),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: temp ? const Color(0xFF5AA9E6) : AppColors.green),
              onPressed: submit,
              child: Text(temp ? 'Aplicar Temp' : 'Curar'),
            ),
          ],
        );
      },
    ),
  );
}

Future<int?> showNumberDialog(BuildContext c, String title, int current) {
  final ctrl = TextEditingController(text: '$current');
  return showDialog<int>(
    context: c,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(signed: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9-]'))],
        decoration: const InputDecoration(border: OutlineInputBorder()),
        onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v.trim())),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}

/// Devuelve la cantidad y si es curación (true) o daño (false).
Future<({int amount, bool heal})?> showDamageHealDialog(
    BuildContext c, ActorHp hp) {
  final ctrl = TextEditingController();
  return showDialog<({int amount, bool heal})>(
    context: c,
    builder: (ctx) {
      int? parse() => int.tryParse(ctrl.text.trim());
      return AlertDialog(
        title: const Text('Daño / Curación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('PV ${hp.value}/${hp.max}'
                '${hp.temp > 0 ? ' (+${hp.temp} temp)' : ''}'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Cantidad',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.red.withAlpha(40),
              foregroundColor: AppColors.red,
            ),
            icon: const Icon(Icons.bloodtype),
            label: const Text('Daño'),
            onPressed: () {
              final v = parse();
              if (v != null) Navigator.pop(ctx, (amount: v, heal: false));
            },
          ),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.green.withAlpha(40),
              foregroundColor: AppColors.green,
            ),
            icon: const Icon(Icons.healing),
            label: const Text('Curar'),
            onPressed: () {
              final v = parse();
              if (v != null) Navigator.pop(ctx, (amount: v, heal: true));
            },
          ),
        ],
      );
    },
  );
}
