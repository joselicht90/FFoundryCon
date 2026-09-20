import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/rules_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../models/rule.dart';
import '../player/widgets/sheet_kit.dart';

class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(rulesControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reglas'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(rulesControllerProvider.notifier).refresh(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Nueva regla'),
        onPressed: () => _edit(context, ref, null),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Error(error: '$e', onRetry: () => ref.read(rulesControllerProvider.notifier).refresh()),
        data: (rules) {
          if (rules.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text('Todavía no hay reglas.\nTocá "Nueva regla" para agregar una.',
                    textAlign: TextAlign.center, style: TextStyle(color: AppColors.label)),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
            itemCount: rules.length,
            itemBuilder: (_, i) => _RuleCard(
              rule: rules[i],
              onTap: () => _view(context, ref, rules[i]),
            ),
          );
        },
      ),
    );
  }

  // Ver la regla (con botones editar / eliminar).
  Future<void> _view(BuildContext context, WidgetRef ref, Rule rule) async {
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
              maxHeight: MediaQuery.of(ctx).size.height * 0.75, maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
                child: Text(rule.title.isEmpty ? '(sin título)' : rule.title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.name)),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                  child: Text(rule.body.trim().isEmpty ? 'Sin contenido.' : rule.body,
                      style: const TextStyle(
                          fontSize: 14, height: 1.5, color: AppColors.listText)),
                ),
              ),
              const Divider(height: 1, color: Color(0x14FFFFFF)),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.red),
                      label: const Text('Eliminar', style: TextStyle(color: AppColors.red)),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _confirmDelete(context, ref, rule);
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Editar'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _edit(context, ref, rule);
                      },
                    ),
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Alta (rule null) o edición.
  Future<void> _edit(BuildContext context, WidgetRef ref, Rule? rule) async {
    final titleC = TextEditingController(text: rule?.title ?? '');
    final bodyC = TextEditingController(text: rule?.body ?? '');
    var busy = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.bgAlt,
          title: Text(rule == null ? 'Nueva regla' : 'Editar regla'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleC,
                  autofocus: rule == null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyC,
                  minLines: 4,
                  maxLines: 12,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Contenido',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: busy ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold, foregroundColor: Colors.black),
              onPressed: busy
                  ? null
                  : () async {
                      final title = titleC.text.trim();
                      if (title.isEmpty) return;
                      setS(() => busy = true);
                      try {
                        await ref.read(rulesControllerProvider.notifier).save(
                            id: rule?.id, title: title, body: bodyC.text.trim());
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setS(() => busy = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('No se pudo guardar: $e')),
                          );
                        }
                      }
                    },
              child: Text(busy ? 'Guardando…' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Rule rule) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgAlt,
        title: const Text('Eliminar regla'),
        content: Text('¿Eliminar "${rule.title}"? No se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref.read(rulesControllerProvider.notifier).delete(rule.id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
        }
      }
    }
  }
}

class _RuleCard extends StatelessWidget {
  final Rule rule;
  final VoidCallback onTap;
  const _RuleCard({required this.rule, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final preview = rule.body.replaceAll('\n', ' ').trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SheetCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                const Icon(Icons.menu_book_outlined, size: 20, color: AppColors.gold),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rule.title.isEmpty ? '(sin título)' : rule.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.listText)),
                      if (preview.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppColors.label)),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _Error({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('No se pudieron cargar las reglas.\n$error',
                textAlign: TextAlign.center, style: const TextStyle(color: AppColors.label)),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
