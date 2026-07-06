import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../common/context_ext.dart';
import '../common/json_preview.dart';
import '../common/line_numbered_field.dart';
import '../common/sample_json.dart';
import '../common/widgets.dart';
import '../documents/active_document_editor.dart';
import '../documents/workspace_cubit.dart';
import 'json_tree_view.dart';

/// JSON görüntüleyici / biçimlendirici ekranı (aktif belge üzerinde çalışır).
class ViewerPage extends StatefulWidget {
  const ViewerPage({super.key, required this.onConvert});

  /// Dönüştürücü sekmesine geçiş (içerik paylaşımlı).
  final VoidCallback onConvert;

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> with ActiveDocumentEditor {
  final TextEditingController _text = TextEditingController();
  final GlobalKey<JsonTreeViewState> _treeKey = GlobalKey<JsonTreeViewState>();

  bool _showText = false;
  String? _selectedPath;
  dynamic _selectedValue;

  @override
  TextEditingController get editorController => _text;

  @override
  void initState() {
    super.initState();
    _text.text = cubit.state.activeContent;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _minify() {
    final mini = cubit.minify(_text.text);
    if (mini == null) {
      context.showSnack('Sıkıştırılamadı: geçerli bir JSON değil.');
      return;
    }
    cubit.setActiveContent(mini, immediate: true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: MultiBlocListener(
        listeners: [
          contentSyncListener(
            onSwitch: () {
              if (mounted) {
                setState(() {
                  _selectedPath = null;
                  _selectedValue = null;
                });
              }
            },
          ),
        ],
        child: BlocBuilder<WorkspaceCubit, WorkspaceState>(
          builder: (context, state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildToolbar(),
                if (state.jsonError != null)
                  ErrorBanner(message: state.jsonError!),
                const SizedBox(height: 8),
                Expanded(
                  child: _showText
                      ? _buildTextTab(state)
                      : _buildTreeTab(state),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Row(
      children: [
        SegmentedButton<bool>(
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(
              value: false,
              icon: Icon(Icons.account_tree_outlined, size: 16),
              label: Text('Ağaç'),
            ),
            ButtonSegment(
              value: true,
              icon: Icon(Icons.notes, size: 16),
              label: Text('Metin'),
            ),
          ],
          selected: {_showText},
          onSelectionChanged: (sel) => setState(() => _showText = sel.first),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ToolButton(
                  icon: Icons.content_paste,
                  label: 'Yapıştır',
                  onPressed: pasteIntoActive,
                ),
                ToolButton(
                  icon: Icons.format_align_left,
                  label: 'Biçimlendir',
                  onPressed: formatActive,
                ),
                ToolButton(
                  icon: Icons.compress,
                  label: 'Boşlukları Sil',
                  onPressed: _minify,
                ),
                ToolButton(
                  icon: Icons.clear,
                  label: 'Temizle',
                  onPressed: () => cubit.setActiveContent('', immediate: true),
                ),
                ToolButton(
                  icon: Icons.science_outlined,
                  label: 'Örnek',
                  onPressed: () =>
                      cubit.setActiveContent(sampleJson, immediate: true),
                ),
                if (!_showText) ...[
                  const SizedBox(width: 8),
                  ToolButton(
                    icon: Icons.unfold_more,
                    label: 'Tümünü Aç',
                    onPressed: () => _treeKey.currentState?.expandAll(),
                  ),
                  ToolButton(
                    icon: Icons.unfold_less,
                    label: 'Tümünü Kapat',
                    onPressed: () => _treeKey.currentState?.collapseAll(),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          onPressed: widget.onConvert,
          icon: const Icon(Icons.bolt, size: 18),
          label: const Text("Dart'a Dönüştür"),
        ),
      ],
    );
  }

  Widget _buildTextTab(WorkspaceState state) {
    return PaneCard(
      title: 'Metin',
      child: LineNumberedField(
        controller: _text,
        errorLine: state.jsonErrorLine,
        hintText: 'JSON\'u buraya yapıştırın...',
        onChanged: (t) => cubit.setActiveContent(t),
      ),
    );
  }

  Widget _buildTreeTab(WorkspaceState state) {
    if (state.activeContent.trim().isEmpty || state.parsed == null) {
      return PaneCard(
        title: 'Ağaç',
        child: Center(
          child: Text(
            state.jsonError != null
                ? 'Geçerli bir JSON girin (yukarıdaki hataya bakın).'
                : 'JSON yapıştırın veya "Örnek" düğmesine basın.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: PaneCard(
            title: 'Ağaç',
            child: JsonTreeView(
              key: _treeKey,
              root: state.parsed,
              revision: state.parseRevision,
              onSelect: (path, value) => setState(() {
                _selectedPath = path;
                _selectedValue = value;
              }),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 320,
          child: PaneCard(
            title: 'Seçili Düğüm',
            actions: [
              if (_selectedPath != null)
                ToolButton(
                  icon: Icons.copy,
                  label: 'Değeri Kopyala',
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(
                        text: const JsonEncoder.withIndent(
                          '  ',
                        ).convert(_selectedValue),
                      ),
                    );
                    context.showSnack('Değer panoya kopyalandı.');
                  },
                ),
            ],
            child: _DetailPanel(path: _selectedPath, value: _selectedValue),
          ),
        ),
      ],
    );
  }
}

/// Seçili düğümün yolunu ve içeriğini gösteren panel.
class _DetailPanel extends StatelessWidget {
  const _DetailPanel({required this.path, required this.value});

  final String? path;
  final dynamic value;

  // Detay panelinde kısaltmasız, ayrıntılı önizleme.
  String _preview(dynamic v) => jsonValuePreview(v, maxLen: 0, verbose: true);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (path == null) {
      return Center(
        child: Text(
          'Ağaçtan bir düğüm seçin.',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
        ),
      );
    }

    final entries = <MapEntry<String, dynamic>>[];
    if (value is Map) {
      (value as Map).forEach((k, v) => entries.add(MapEntry(k.toString(), v)));
    } else if (value is List) {
      final list = value as List;
      for (var i = 0; i < list.length; i++) {
        entries.add(MapEntry('[$i]', list[i]));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          child: SelectableText(
            path!,
            style: codeTextStyle.copyWith(
              fontSize: 11.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: entries.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(10),
                  child: SelectableText(_preview(value), style: codeTextStyle),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final e = entries[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 120,
                            child: Text(
                              e.key,
                              style: codeTextStyle.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _preview(e.value),
                              style: codeTextStyle.copyWith(fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
