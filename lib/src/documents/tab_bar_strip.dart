import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'workspace_cubit.dart';

/// Açık belgeleri gösteren üst sekme şeridi (kapatılabilir + yeni sekme).
class TabBarStrip extends StatelessWidget {
  const TabBarStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BlocBuilder<WorkspaceCubit, WorkspaceState>(
      buildWhen: (p, c) =>
          p.openIds != c.openIds ||
          p.activeId != c.activeId ||
          p.documents != c.documents,
      builder: (context, state) {
        final cubit = context.read<WorkspaceCubit>();
        final open = state.openDocuments;
        return SizedBox(
          height: 38,
          child: Row(
            children: [
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: open.length,
                  itemBuilder: (context, i) {
                    final doc = open[i];
                    final active = doc.id == state.activeId;
                    return _Tab(
                      title: doc.title,
                      active: active,
                      onTap: () => cubit.openDocument(doc.id),
                      onClose: () => cubit.closeTab(doc.id),
                    );
                  },
                ),
              ),
              IconButton(
                tooltip: 'Yeni sekme',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add, size: 18),
                onPressed: () => cubit.newDocument(),
              ),
              const SizedBox(width: 4),
              // Aktif belge sınıf/durum rozeti
              if (state.classCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(
                    '${state.classCount} sınıf',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.title,
    required this.active,
    required this.onTap,
    required this.onClose,
  });

  final String title;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 190),
        decoration: BoxDecoration(
          color: active ? scheme.surface : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: active ? scheme.primary : Colors.transparent,
              width: 2,
            ),
            right: BorderSide(color: scheme.outlineVariant, width: 1),
          ),
        ),
        padding: const EdgeInsets.only(left: 12, right: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
