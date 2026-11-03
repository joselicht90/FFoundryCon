import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/actor_controller.dart';
import '../../controllers/chat_controller.dart';
import '../../controllers/combat_controller.dart';
import '../../controllers/session_controller.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/chat_message.dart';
import '../../models/foundry_actor.dart';
import '../../models/foundry_combat.dart';
import 'combat_screen.dart';
import '../rules/rules_screen.dart';
import 'compendium_screen.dart';
import 'pages/chat_page.dart';
import 'pages/foundry_sheet_page.dart';
import 'pages/skills_page.dart';
import 'pages/summary_page.dart';
import 'widgets/actor_avatar.dart';
import 'widgets/inventory_list.dart';
import 'widgets/roll_card.dart';
import 'widgets/sheet_dialogs.dart';
import 'widgets/spells_list.dart';

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

const _navItems = [
  _NavItem(Icons.shield_outlined, 'Hero'),
  _NavItem(Icons.format_list_bulleted, 'Skills'),
  _NavItem(Icons.auto_awesome, 'Spells'),
  _NavItem(Icons.backpack_outlined, 'Items'),
  _NavItem(Icons.forum_outlined, 'Chat'),
  _NavItem(Icons.public, 'Foundry'),
];

const _foundryIndex = 5; // hoja real de Foundry en WebView

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  final _pc = PageController();
  int _page = 0;
  // Última tab nativa, a la que vuelve el overlay de la hoja de Foundry.
  int _lastPage = 0;
  // Durante animateToPage, onPageChanged reporta cada página intermedia; se
  // ignoran para no alternar el modo inmersivo ni pisar [_lastPage].
  bool _animating = false;

  // Watcher de resultados: baseline para ignorar el historial ya cargado y set
  // de tiradas ya notificadas.
  int? _rollBaseline;
  final Set<String> _notifiedRolls = {};
  // Toasts de tirada: viven en el overlay raíz, así flotan sobre cualquier
  // pantalla pusheada (combate, mapa, compendio…), no solo la principal.
  final _RollToaster _toaster = _RollToaster();
  // Dedup de notificaciones de turno.
  String? _lastMyTurnKey;
  String? _lastNextKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(editModeProvider.notifier).value = false;
      ref.read(notificationServiceProvider).init();
    });
  }

  /// Combatiente que actúa después del actual (salta a los derrotados).
  Combatant? _nextCombatant(FoundryCombat c) {
    final n = c.combatants.length;
    if (n == 0) return null;
    for (var step = 1; step <= n; step++) {
      final cand = c.combatants[(c.turn + step) % n];
      if (!cand.defeated) return cand;
    }
    return null;
  }

  /// Notifica cuando es tu turno o cuando sos el próximo (vía el evento de
  /// combate del WS; sirve mientras la app siga viva).
  void _watchCombatTurn() {
    ref.listen(combatControllerProvider, (_, next) {
      final c = next.valueOrNull;
      if (c == null || !c.active) return;
      final myId = ref.read(actorControllerProvider).valueOrNull?.id;
      if (myId == null) return;
      final notif = ref.read(notificationServiceProvider);

      final cur = c.current;
      final myTurnKey = 'turn-${c.round}-${c.turn}';
      if (cur != null && cur.actorId == myId && _lastMyTurnKey != myTurnKey) {
        _lastMyTurnKey = myTurnKey;
        notif.show(1001, '¡Es tu turno!', 'Ronda ${c.round} — te toca actuar');
      }
      final nxt = _nextCombatant(c);
      final nextKey = 'next-${c.round}-${c.turn}';
      if (nxt != null &&
          nxt.actorId == myId &&
          cur?.actorId != myId &&
          _lastNextKey != nextKey) {
        _lastNextKey = nextKey;
        notif.show(1002, 'Tu turno se acerca', 'Sos el próximo en actuar');
      }
    });
  }

  /// Muestra un snackbar con el resultado de la última tirada del personaje que
  /// llega al chat (cubre los casts de Midi, que no tienen popup propio).
  void _watchRollResults() {
    ref.listen(chatControllerProvider, (_, next) {
      final msgs = next.valueOrNull;
      if (msgs == null || msgs.isEmpty) return;
      // Primera vez: ignoramos todo lo que ya estaba en el historial.
      _rollBaseline ??= msgs.map((m) => m.timestamp).fold<int>(0, max);
      final actor = ref.read(actorControllerProvider).valueOrNull;
      if (actor == null) return;
      if (ref.read(rollPopupOpenProvider) > 0) return; // ya hay un popup arriba

      ChatMessage? latest;
      for (final m in msgs) {
        if (!m.isRoll || m.total == null) continue;
        if (m.author != actor.name) continue;
        if (m.timestamp <= _rollBaseline!) continue;
        if (_notifiedRolls.contains(m.id)) continue;
        _notifiedRolls.add(m.id); // marcamos todas las nuevas como vistas
        if (latest == null || m.timestamp > latest.timestamp) latest = m;
      }
      if (latest != null && mounted) _toaster.show(context, latest);
    });
  }

  @override
  void dispose() {
    if (_page == _foundryIndex) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _toaster.dispose();
    _pc.dispose();
    super.dispose();
  }

  /// La tab Foundry es inmersiva: oculta las barras del sistema mientras está
  /// activa (el chrome propio se omite en [build]).
  void _setPage(int page) {
    final wasFoundry = _page == _foundryIndex;
    final isFoundry = page == _foundryIndex;
    if (!isFoundry) _lastPage = page;
    if (wasFoundry != isFoundry) {
      SystemChrome.setEnabledSystemUIMode(
        isFoundry ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
    }
    setState(() => _page = page);
  }

  Future<void> _go(int page) async {
    _setPage(page);
    _animating = true;
    try {
      await _pc.animateToPage(
        page,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } finally {
      _animating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    _watchRollResults();
    _watchCombatTurn();
    final state = ref.watch(actorControllerProvider);
    final actor = state.valueOrNull;
    // La WebView solo existe con personaje cargado; sin él no hay pantalla
    // completa (si no, quedaría sin chrome y sin salida).
    final fullscreen = _page == _foundryIndex && actor != null;

    final scaffold = Scaffold(
      body: Column(
        children: [
          if (!fullscreen) ...[
            _Header(actor: actor),
            if (actor != null && actor.offline)
              _OfflineBanner(pendingCount: actor.pending.length),
            _CombatBanner(actorId: actor?.id),
          ],
          // Key estable: al quitar/poner el chrome no se recrea el PageView
          // (ni la WebView de Foundry, que es cara de recargar).
          Expanded(
            key: const ValueKey('pages'),
            child: state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorBody(error: '$e'),
              data: (a) {
                if (a == null) {
                  return const Center(child: Text('No hay personaje cargado'));
                }
                return PageView(
                  controller: _pc,
                  // En la hoja de Foundry el swipe no compite con sus gestos.
                  physics: _page == _foundryIndex
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  onPageChanged: (i) {
                    if (!_animating) _setPage(i);
                  },
                  children: [
                    SummaryPage(actor: a),
                    SkillsPage(actor: a),
                    SpellsList(actor: a),
                    InventoryList(actor: a),
                    const ChatPage(),
                    FoundrySheetPage(
                      actorId: a.id,
                      onExit: () => _go(_lastPage),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: fullscreen
          ? null
          : _BottomNav(
              current: _page,
              onTap: _go,
              offline: actor?.offline ?? false,
            ),
    );

    // Back del sistema en la hoja de Foundry: vuelve a la tab anterior.
    return PopScope(
      canPop: !fullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(_lastPage);
      },
      child: scaffold,
    );
  }
}

class _Header extends ConsumerWidget {
  final FoundryActor? actor;
  const _Header({required this.actor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final world = ref.watch(selectedWorldProvider);
    final top = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(16, top + 10, 16, 11),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B1C20), AppColors.frame],
        ),
        border: Border(bottom: BorderSide(color: Color(0x29C9A86A))),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () => Navigator.of(context).maybePop(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.chevron_left,
                    size: 18,
                    color: AppColors.label,
                  ),
                  Text(
                    world?.title ?? 'Volver',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.label,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold.withAlpha(128)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withAlpha(26),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: ActorAvatar(
                  img: actor?.img,
                  name: actor?.name ?? '?',
                  radius: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      actor?.name ?? 'Jugador',
                      style: cinzel(18, weight: FontWeight.w600, height: 1.1),
                    ),
                    if (actor != null)
                      Text(
                        [
                          actor!.classLine,
                          if (actor!.level != null) 'Nivel ${actor!.level}',
                        ].where((s) => s.isNotEmpty).join(' • '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.sub,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (actor != null && !actor!.offline)
                _LongRestButton(actorName: actor!.name),
              IconButton(
                tooltip: 'Reglas',
                icon: const Icon(Icons.gavel, color: AppColors.gold),
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const RulesScreen())),
              ),
              IconButton(
                tooltip: 'Compendio',
                icon: const Icon(
                  Icons.menu_book_outlined,
                  color: AppColors.gold,
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CompendiumScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Banner de combate: visible solo cuando hay combate activo. Muestra ronda y
/// turno actual; resalta si es tu turno. Toca para abrir la pantalla de combate.
class _CombatBanner extends ConsumerWidget {
  final String? actorId;
  const _CombatBanner({required this.actorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final combat = ref.watch(combatControllerProvider).valueOrNull;
    if (combat == null || !combat.active) return const SizedBox.shrink();
    final cur = combat.current;
    final myTurn = cur != null && actorId != null && cur.actorId == actorId;
    final color = myTurn ? AppColors.gold : AppColors.orange;

    return Material(
      color: color.withAlpha(myTurn ? 46 : 28),
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CombatScreen())),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 7, 10, 7),
          child: Row(
            children: [
              Icon(myTurn ? Icons.bolt : Icons.shield, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  myTurn
                      ? '¡Tu turno! · Ronda ${combat.round}'
                      : 'Combate · Ronda ${combat.round} · Turno: ${cur?.name ?? '—'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              Text(
                'Ver',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

/// Maneja los toasts de tirada en el overlay raíz, para que floten por encima
/// de cualquier ruta pusheada (combate, mapa, etc.).
class _RollToaster {
  final _key = GlobalKey<_RollToastLayerState>();
  OverlayEntry? _entry;

  void show(BuildContext context, ChatMessage m) {
    if (_entry == null) {
      _entry = OverlayEntry(builder: (_) => _RollToastLayer(key: _key));
      Overlay.of(context, rootOverlay: true).insert(_entry!);
    }
    // El estado puede no estar montado en el primer frame tras insertar.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _key.currentState?.add(m),
    );
  }

  void dispose() {
    _entry?.remove();
    _entry = null;
  }
}

/// Capa de overlay que apila los toasts activos (auto-descartables a los 8s).
class _RollToastLayer extends StatefulWidget {
  const _RollToastLayer({super.key});

  @override
  State<_RollToastLayer> createState() => _RollToastLayerState();
}

class _RollToastLayerState extends State<_RollToastLayer> {
  final List<ChatMessage> _toasts = [];

  void add(ChatMessage m) {
    setState(() {
      _toasts.removeWhere((x) => x.id == m.id);
      _toasts.add(m);
      if (_toasts.length > 4) _toasts.removeRange(0, _toasts.length - 4);
    });
    Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _toasts.removeWhere((x) => x.id == m.id));
    });
  }

  void _dismiss(String id) {
    if (mounted) setState(() => _toasts.removeWhere((x) => x.id == id));
  }

  @override
  Widget build(BuildContext context) {
    if (_toasts.isEmpty) return const SizedBox.shrink();
    final bottom = MediaQuery.of(context).padding.bottom;
    return Positioned(
      left: 12,
      right: 12,
      bottom: bottom + 14,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in _toasts)
            _RollToast(
              key: ValueKey(m.id),
              msg: m,
              onDismiss: () => _dismiss(m.id),
            ),
        ],
      ),
    );
  }
}

/// Toast de tirada: misma tarjeta que el chat, con animación de entrada y
/// swipe para descartar. Se apilan varios (el más nuevo abajo).
class _RollToast extends StatefulWidget {
  final ChatMessage msg;
  final VoidCallback onDismiss;
  const _RollToast({super.key, required this.msg, required this.onDismiss});

  @override
  State<_RollToast> createState() => _RollToastState();
}

class _RollToastState extends State<_RollToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  )..forward();

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.msg;
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: _ac, curve: Curves.easeOut),
      axisAlignment: -1,
      child: FadeTransition(
        opacity: _ac,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Dismissible(
            key: ValueKey('toast-${m.id}'),
            direction: DismissDirection.horizontal,
            onDismissed: (_) => widget.onDismiss(),
            child: Material(
              color: Colors.transparent,
              elevation: 8,
              shadowColor: Colors.black54,
              borderRadius: BorderRadius.circular(13),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: RollCardView(
                  author: m.author,
                  authorColor: m.authorColor,
                  isPrivate: m.isPrivate,
                  flavor: m.flavor,
                  formula: m.formula,
                  total: m.total,
                  dice: m.dice,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón de descanso largo (restaura PV, dados de golpe, usos y slots).
class _LongRestButton extends ConsumerStatefulWidget {
  final String actorName;
  const _LongRestButton({required this.actorName});

  @override
  ConsumerState<_LongRestButton> createState() => _LongRestButtonState();
}

class _LongRestButtonState extends ConsumerState<_LongRestButton> {
  bool _busy = false;

  Future<void> _rest() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgAlt,
        title: const Text('Descanso largo'),
        content: Text(
          'Se restauran PV, dados de golpe, usos y espacios de conjuro de ${widget.actorName}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descansar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(actorControllerProvider.notifier).longRest();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Descanso largo completado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo descansar: $e')));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Descanso largo',
      icon: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.gold,
              ),
            )
          : const Icon(Icons.bedtime_outlined, color: AppColors.gold),
      onPressed: _busy ? null : _rest,
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  final bool offline;
  const _BottomNav({
    required this.current,
    required this.onTap,
    this.offline = false,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(4, 9, 4, bottom + 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC141519), AppColors.bg],
        ),
        border: Border(top: BorderSide(color: Color(0x29C9A86A))),
      ),
      child: Row(
        children: [
          for (int i = 0; i < _navItems.length; i++)
            Expanded(
              child: () {
                final disabled = i == _foundryIndex && offline;
                final color = disabled
                    ? AppColors.muted.withAlpha(70)
                    : (i == current ? AppColors.gold : AppColors.muted);
                return InkWell(
                  onTap: disabled ? null : () => onTap(i),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_navItems[i].icon, size: 22, color: color),
                      const SizedBox(height: 4),
                      Text(
                        _navItems[i].label,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                );
              }(),
            ),
        ],
      ),
    );
  }
}

class _OfflineBanner extends ConsumerStatefulWidget {
  final int pendingCount;
  const _OfflineBanner({required this.pendingCount});

  @override
  ConsumerState<_OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends ConsumerState<_OfflineBanner> {
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    await ref.read(actorControllerProvider.notifier).refresh();
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.orange.withAlpha(36),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
        child: Row(
          children: [
            const Icon(Icons.cloud_off, size: 16, color: AppColors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.pendingCount > 0
                    ? 'Foundry offline · ${widget.pendingCount} cambio(s) se aplicarán al reabrir'
                    : 'Foundry offline · datos desde la base local',
                style: const TextStyle(color: AppColors.orange, fontSize: 12),
              ),
            ),
            _retrying
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.orange,
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(
                      Icons.refresh,
                      size: 18,
                      color: AppColors.orange,
                    ),
                    tooltip: 'Reintentar conexión',
                    onPressed: _retry,
                  ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends ConsumerWidget {
  final String error;
  const _ErrorBody({required this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () =>
                  ref.read(actorControllerProvider.notifier).refresh(),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
