import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/session_controller.dart';
import '../../core/theme/app_theme.dart';
import '../player/pages/chat_page.dart';
import '../player/token_control_screen.dart';
import '../rules/rules_screen.dart';
import 'dm_combat_screen.dart';
import 'dm_dashboard.dart';

class GmScreen extends ConsumerStatefulWidget {
  const GmScreen({super.key});

  @override
  ConsumerState<GmScreen> createState() => _GmScreenState();
}

class _GmScreenState extends ConsumerState<GmScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(selectedUserProvider);
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(16, top + 12, 16, 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1B1C20), AppColors.frame],
              ),
              border: Border(bottom: BorderSide(color: Color(0x29C9A86A))),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: AppColors.label),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const Icon(Icons.shield, color: AppColors.gold, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? 'Game Master',
                          style: cinzel(18, weight: FontWeight.w600, height: 1.1)),
                      const Text('Game Master',
                          style: TextStyle(fontSize: 12, color: AppColors.sub)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Reglas',
                  icon: const Icon(Icons.gavel, color: AppColors.gold),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RulesScreen()),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: const [
                DmDashboard(),
                DmCombatScreen(),
                ChatPage(),
                TokenControlScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Party',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department),
            label: 'Combate',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Map',
          ),
        ],
      ),
    );
  }
}
