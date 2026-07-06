import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'json_document.dart';
import 'workspace_cubit.dart';

/// Soldaki kayıtlı belgeler paneli. Her kayıt yerelde saklanır; tıklayınca
/// sekme olarak açılır.
class DocumentsPanel extends StatelessWidget {
  const DocumentsPanel({super.key, this.onOpen});

  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 6),
            child: Row(
              children: [
                Text('Kayıtlar', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                IconButton(
                  tooltip: 'Yeni belge',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add, size: 20),
                  onPressed: () => context.read<WorkspaceCubit>().newDocument(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: BlocBuilder<WorkspaceCubit, WorkspaceState>(
              buildWhen: (p, c) =>
                  p.documents != c.documents || p.activeId != c.activeId,
              builder: (context, state) {
                final docs = state.sortedDocuments;
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'Kayıt yok',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final active = doc.id == state.activeId;
                    final open = state.openIds.contains(doc.id);
                    return _DocTile(
                      doc: doc,
                      active: active,
                      open: open,
                      onTap: () {
                        context.read<WorkspaceCubit>().openDocument(doc.id);
                        onOpen?.call();
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({
    required this.doc,
    required this.active,
    required this.open,
    required this.onTap,
  });

  final JsonDocument doc;
  final bool active;
  final bool open;
  final VoidCallback onTap;

  String _preview() {
    final t = doc.content.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.isEmpty) return 'boş';
    return t.length > 40 ? '${t.substring(0, 40)}…' : t;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: active ? scheme.primary.withValues(alpha: 0.14) : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(
              open ? Icons.description : Icons.description_outlined,
              size: 16,
              color: active ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  Text(
                    _preview(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: '',
              icon: Icon(
                Icons.more_vert,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              padding: EdgeInsets.zero,
              iconSize: 16,
              onSelected: (v) {
                final cubit = context.read<WorkspaceCubit>();
                if (v == 'rename') {
                  _renameDialog(context, cubit);
                } else if (v == 'delete') {
                  cubit.deleteDocument(doc.id);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'rename', child: Text('Yeniden adlandır')),
                PopupMenuItem(value: 'delete', child: Text('Sil')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameDialog(BuildContext context, WorkspaceCubit cubit) async {
    final controller = TextEditingController(text: doc.title);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeniden adlandır'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Belge adı'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      cubit.renameDocument(doc.id, result.trim());
    }
  }
}
