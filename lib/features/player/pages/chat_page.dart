import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/actor_controller.dart';
import '../../../controllers/chat_controller.dart';
import '../../../controllers/session_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/chat_message.dart';
import '../widgets/apply_damage_bar.dart';
import '../widgets/roll_card.dart';
import '../widgets/sheet_kit.dart';

({String formula, int total, List<int> values})? _evalDice(String input) {
  final m = RegExp(r'^(\d*)d(\d+)\s*([+-]\s*\d+)?$', caseSensitive: false)
      .firstMatch(input.trim());
  if (m == null) return null;
  final n = int.tryParse(m.group(1) ?? '') ?? 1;
  if (n < 1 || n > 100) return null;
  final faces = int.parse(m.group(2)!);
  final mod = int.tryParse((m.group(3) ?? '0').replaceAll(RegExp(r'\s'), '')) ?? 0;
  final rng = Random();
  final values = List.generate(n, (_) => rng.nextInt(faces) + 1);
  final total = values.fold<int>(0, (a, b) => a + b) + mod;
  final modStr = mod == 0 ? '' : (mod > 0 ? ' + $mod' : ' - ${mod.abs()}');
  return (formula: '${n}d$faces$modStr', total: total, values: values);
}

Color _parseColor(String? hex, Color fallback) {
  if (hex == null) return fallback;
  try {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  } catch (_) {
    return fallback;
  }
}

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  int _lastCount = 0;
  final Set<String> _whisper = {}; // destinatarios; vacío = público
  final Map<int, int> _pool = {}; // caras → cantidad (tirada compuesta)
  bool _diceOpen = false; // bandeja de dados colapsada por defecto
  bool _composerOpen = false; // todo el composer oculto detrás del FAB d20

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _autoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  String get _author {
    final actor = ref.read(actorControllerProvider).valueOrNull;
    final user = ref.read(selectedUserProvider);
    return actor?.name ?? user?.name ?? 'Yo';
  }

  String? get _color => ref.read(selectedUserProvider)?.color;
  String? get _userId => ref.read(selectedUserProvider)?.id;

  Future<void> _send() async {
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) return;
    _ctrl.clear();
    final notifier = ref.read(chatControllerProvider.notifier);

    try {
      if (raw.startsWith('/r ') || raw.startsWith('/roll ')) {
        final formula = raw.replaceFirst(RegExp(r'^/r(oll)? '), '');
        final r = _evalDice(formula);
        if (r == null) {
          _toast('Fórmula inválida (probá /r 2d6+3)');
          return;
        }
        await notifier.send(
          author: _author,
          authorColor: _color,
          userId: _userId,
          flavor: 'Tirada',
          roll: {'formula': r.formula, 'total': r.total, 'values': r.values},
          whisper: _whisper.toList(),
        );
      } else if (raw.startsWith('/ooc ')) {
        await notifier.send(
          author: _author,
          authorColor: _color,
          userId: _userId,
          text: raw.substring(5),
          isOoc: true,
          whisper: _whisper.toList(),
        );
      } else {
        await notifier.send(
          author: _author,
          authorColor: _color,
          userId: _userId,
          text: raw,
          whisper: _whisper.toList());
      }
    } catch (e) {
      _toast('Error: $e');
    }
  }

  Future<void> _quickRoll(String die) async {
    final r = _evalDice(die);
    if (r == null) return;
    await ref.read(chatControllerProvider.notifier).send(
          author: _author,
          authorColor: _color,
          userId: _userId,
          flavor: die,
          roll: {'formula': r.formula, 'total': r.total, 'values': r.values},
          whisper: _whisper.toList(),
        );
  }

  /// Tap en un dado: si hay pool armándose, suma; si no, tira 1 dado.
  void _onDieTap(int faces) {
    if (_pool.isNotEmpty) {
      setState(() => _pool[faces] = (_pool[faces] ?? 0) + 1);
    } else {
      _quickRoll('1d$faces');
    }
  }

  /// Mantener apretado: empieza/agrega al pool.
  void _onDieLong(int faces) =>
      setState(() => _pool[faces] = (_pool[faces] ?? 0) + 1);

  void _clearPool() => setState(_pool.clear);

  String _poolLabel(Map<int, int> pool) {
    final faces = pool.keys.toList()..sort((a, b) => b.compareTo(a));
    return faces.map((f) => '${pool[f]}d$f').join(' + ');
  }

  Future<void> _rollPool() async {
    if (_pool.isEmpty) return;
    final rng = Random();
    final faces = _pool.keys.toList()..sort((a, b) => b.compareTo(a));
    final values = <int>[];
    var total = 0;
    for (final f in faces) {
      for (var i = 0; i < _pool[f]!; i++) {
        final v = rng.nextInt(f) + 1;
        values.add(v);
        total += v;
      }
    }
    final formula = _poolLabel(_pool);
    setState(_pool.clear);
    await ref.read(chatControllerProvider.notifier).send(
          author: _author,
          authorColor: _color,
          userId: _userId,
          flavor: formula,
          roll: {'formula': formula, 'total': total, 'values': values},
          whisper: _whisper.toList(),
        );
  }

  Future<void> _pickRecipients() async {
    final world = ref.read(selectedWorldProvider);
    if (world == null) return;
    final users = ref.read(worldUsersProvider(world.id)).valueOrNull ?? [];
    final me = _userId;
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.public, color: AppColors.gold),
                title: const Text('Público (todos)'),
                trailing: _whisper.isEmpty ? const Icon(Icons.check, color: AppColors.gold) : null,
                onTap: () {
                  setState(_whisper.clear);
                  Navigator.pop(ctx);
                },
              ),
              const Divider(height: 1),
              for (final u in users.where((u) => u.id != me))
                CheckboxListTile(
                  value: _whisper.contains(u.id),
                  title: Text(u.name),
                  subtitle: Text(u.isGM ? 'Game Master' : 'Jugador',
                      style: const TextStyle(fontSize: 11)),
                  activeColor: AppColors.gold,
                  onChanged: (v) => setSheet(() => setState(() {
                        v == true ? _whisper.add(u.id) : _whisper.remove(u.id);
                      })),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _recipientLabel() {
    if (_whisper.isEmpty) return 'Todos';
    final world = ref.read(selectedWorldProvider);
    final users = world == null
        ? const []
        : (ref.read(worldUsersProvider(world.id)).valueOrNull ?? []);
    final names = users.where((u) => _whisper.contains(u.id)).map((u) => u.name).toList();
    if (names.isEmpty) return '${_whisper.length} priv.';
    return names.length == 1 ? names.first : '${names.length} usuarios';
  }

  void _toast(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> _refresh() => ref.read(chatControllerProvider.notifier).refresh();

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar chat'),
        content: const Text(
            'Esto borra la copia local del chat (no afecta a Foundry). ¿Seguro?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(chatControllerProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(chatControllerProvider);
    final user = ref.watch(selectedUserProvider);
    final isGM = user?.isGM ?? false;
    final all = async.valueOrNull ?? const <ChatMessage>[];
    // Filtra los privados que no me corresponden.
    final messages = all.where((m) => m.visibleTo(user?.id, isGM)).toList();
    if (messages.length != _lastCount) {
      _lastCount = messages.length;
      _autoScroll();
    }

    return Stack(
      children: [
        Column(
          children: [
            _ChatHeader(count: messages.length, onRefresh: _refresh, onClear: _clear),
            Expanded(
              child: async.isLoading && messages.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : messages.isEmpty
                      ? const Center(
                          child: Text('Sin mensajes todavía',
                              style: TextStyle(color: AppColors.label)))
                      : ListView.separated(
                          controller: _scroll,
                          padding: EdgeInsets.fromLTRB(11, 10, 11, _composerOpen ? 6 : 80),
                          itemCount: messages.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 7),
                          itemBuilder: (_, i) => _MessageView(msg: messages[i]),
                        ),
            ),
            if (_composerOpen)
              _Composer(
                controller: _ctrl,
                onSend: _send,
                onDieTap: _onDieTap,
                onDieLong: _onDieLong,
                pool: _pool,
                poolLabel: _poolLabel(_pool),
                onRollPool: _rollPool,
                onClearPool: _clearPool,
                recipientLabel: _recipientLabel(),
                isPrivate: _whisper.isNotEmpty,
                onPickRecipients: _pickRecipients,
                diceOpen: _diceOpen,
                onToggleDice: () => setState(() => _diceOpen = !_diceOpen),
                onClose: () => setState(() => _composerOpen = false),
              ),
          ],
        ),
        // FAB d20: habilita todo el composer (oculto por defecto).
        if (!_composerOpen)
          Positioned(
            right: 16,
            bottom: 16,
            child: GestureDetector(
              onTap: () => setState(() {
                _composerOpen = true;
                _diceOpen = true;
              }),
              child: Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFA8843A), Color(0xFF8A6A2A)],
                  ),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(120), blurRadius: 8)],
                ),
                child: const D20Icon(size: 30, color: Color(0xFF1A160C)),
              ),
            ),
          ),
      ],
    );
  }
}

class _MessageView extends ConsumerWidget {
  final ChatMessage msg;
  const _MessageView({required this.msg});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (msg.isSystem) {
      return Center(
        child: Text(msg.text ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.label)),
      );
    }
    if (!msg.isRoll) return _TextBubble(msg: msg);

    final card = RollCardView(
      author: msg.author,
      authorColor: msg.authorColor,
      time: _time(msg.timestamp),
      isPrivate: msg.isPrivate,
      flavor: msg.flavor,
      formula: msg.formula,
      total: msg.total,
      dice: msg.dice,
    );
    // Botón "Aplicar daño" solo para el DM, cuando el roll trae objetivos.
    final ad = msg.applyDamage;
    final isGM = ref.watch(selectedUserProvider)?.isGM ?? false;
    if (ad != null && ad.targets.isNotEmpty && isGM) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [card, const SizedBox(height: 6), ApplyDamageBar(apply: ad)],
      );
    }
    return card;
  }
}

class _TextBubble extends StatelessWidget {
  final ChatMessage msg;
  const _TextBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final author = _parseColor(msg.authorColor, AppColors.gold);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(msg.author,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: author)),
            const SizedBox(width: 7),
            Text(_time(msg.timestamp),
                style: const TextStyle(fontSize: 9, color: Color(0xFF6F6A60))),
            if (msg.isPrivate) ...[
              const SizedBox(width: 5),
              const Icon(Icons.lock, size: 11, color: AppColors.orange),
            ],
            if (msg.isOoc) ...[
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text('OOC',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.label)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: const BoxDecoration(
            color: Color(0xFF1B1D22),
            border: Border.fromBorderSide(BorderSide(color: Color(0x0DFFFFFF))),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(3),
              topRight: Radius.circular(11),
              bottomLeft: Radius.circular(11),
              bottomRight: Radius.circular(11),
            ),
          ),
          child: Text(msg.text ?? '',
              style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  fontStyle: msg.isOoc ? FontStyle.italic : FontStyle.normal,
                  color: msg.isOoc ? AppColors.muted : AppColors.listText)),
        ),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final void Function(int faces) onDieTap;
  final void Function(int faces) onDieLong;
  final Map<int, int> pool;
  final String poolLabel;
  final VoidCallback onRollPool;
  final VoidCallback onClearPool;
  final String recipientLabel;
  final bool isPrivate;
  final VoidCallback onPickRecipients;
  final bool diceOpen;
  final VoidCallback onToggleDice;
  final VoidCallback onClose;
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.onDieTap,
    required this.onDieLong,
    required this.pool,
    required this.poolLabel,
    required this.onRollPool,
    required this.onClearPool,
    required this.recipientLabel,
    required this.isPrivate,
    required this.onPickRecipients,
    required this.diceOpen,
    required this.onToggleDice,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    const dice = [20, 12, 10, 8, 6, 4, 100];
    final pillColor = isPrivate ? AppColors.orange : AppColors.gold;
    final building = pool.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF16171B), Color(0xFF191B20)],
        ),
        border: Border(top: BorderSide(color: Color(0x29C9A86A))),
      ),
      child: Column(
        children: [
          // Barra para cerrar todo el composer (vuelve al FAB d20).
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onClose,
              child: const Padding(
                padding: EdgeInsets.fromLTRB(10, 2, 6, 6),
                child: Icon(Icons.keyboard_arrow_down, size: 22, color: AppColors.label),
              ),
            ),
          ),
          if (diceOpen)
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: dice.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final faces = dice[i];
                final count = pool[faces] ?? 0;
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onDieTap(faces),
                  onLongPress: () => onDieLong(faces),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 46,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: count > 0 ? AppColors.gold.withAlpha(46) : AppColors.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: count > 0
                                  ? AppColors.gold
                                  : AppColors.gold.withAlpha(52)),
                        ),
                        child: Text('d$faces',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.gold)),
                      ),
                      if (count > 0)
                        Positioned(
                          top: -5,
                          right: -5,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(minWidth: 18),
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppColors.gold,
                              shape: BoxShape.circle,
                            ),
                            child: Text('$count',
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black)),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (diceOpen && building) ...[
            const SizedBox(height: 9),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 5, 6, 5),
              decoration: BoxDecoration(
                color: AppColors.gold.withAlpha(28),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.gold.withAlpha(120)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.casino, size: 16, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(poolLabel,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.gold)),
                  ),
                  TextButton(
                    onPressed: onRollPool,
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.gold,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 32)),
                    child: const Text('Tirar',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  InkWell(
                    onTap: onClearPool,
                    borderRadius: BorderRadius.circular(16),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.close, size: 16, color: AppColors.label),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 9),
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onPickRecipients,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: pillColor.withAlpha(110)),
                  color: pillColor.withAlpha(28),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isPrivate ? Icons.lock : Icons.public, size: 13, color: pillColor),
                    const SizedBox(width: 5),
                    Text('Para: $recipientLabel',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: pillColor)),
                    const SizedBox(width: 3),
                    Icon(Icons.expand_more, size: 14, color: pillColor),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              // Botón d20: muestra/oculta la bandeja de dados.
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onToggleDice,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: diceOpen ? AppColors.gold.withAlpha(46) : AppColors.card,
                    border: Border.all(
                        color: diceOpen ? AppColors.gold : AppColors.gold.withAlpha(70)),
                  ),
                  child: const Text('d20',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.gold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(fontSize: 13.5, color: AppColors.parchment),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  inputFormatters: [LengthLimitingTextInputFormatter(500)],
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Mensaje o /r 1d20+5',
                    hintStyle: const TextStyle(color: AppColors.label, fontSize: 13),
                    filled: true,
                    fillColor: AppColors.card,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide: BorderSide(color: AppColors.gold.withAlpha(56)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide: const BorderSide(color: AppColors.gold),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onSend,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFA8843A), Color(0xFF8A6A2A)],
                    ),
                  ),
                  child: const Icon(Icons.send, size: 18, color: Color(0xFF1A160C)),
                ),
              ),
            ],
          ),
          if (diceOpen) ...[
            const SizedBox(height: 6),
            const Text('Tocá un dado para tirar · mantené apretado para sumar varios · /ooc fuera de personaje',
                style: TextStyle(fontSize: 10, color: Color(0xFF5F5A51))),
          ],
        ],
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final int count;
  final VoidCallback onRefresh;
  final VoidCallback onClear;
  const _ChatHeader({
    required this.count,
    required this.onRefresh,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x1FC9A86A))),
      ),
      child: Row(
        children: [
          const Icon(Icons.forum, size: 18, color: AppColors.gold),
          const SizedBox(width: 8),
          Text('Chat', style: cinzel(16, weight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text('· $count', style: const TextStyle(fontSize: 11, color: AppColors.label)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20, color: AppColors.label),
            tooltip: 'Refrescar',
            onPressed: onRefresh,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.label),
            tooltip: 'Borrar chat',
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

String _time(int ts) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.hour)}:${two(d.minute)}';
}
