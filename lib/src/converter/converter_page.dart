import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../common/context_ext.dart';
import '../common/dart_highlighter.dart';
import '../common/line_numbered_field.dart';
import '../common/json_repair.dart';
import '../common/json_syntax_controller.dart';
import '../common/widgets.dart';
import '../documents/active_document_editor.dart';
import '../documents/workspace_cubit.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'settings_panel.dart';

/// JSON -> Dart dönüştürücü ekranı (aktif belge üzerinde çalışır).
class ConverterPage extends StatefulWidget {
  const ConverterPage({super.key, required this.onOpenInViewer});

  /// Görüntüleyici sekmesine geçiş (içerik zaten paylaşımlı).
  final VoidCallback onOpenInViewer;

  @override
  State<ConverterPage> createState() => _ConverterPageState();
}

class _ConverterPageState extends State<ConverterPage>
    with ActiveDocumentEditor {
  final JsonSyntaxController _input = JsonSyntaxController();
  final ScrollController _outputScroll = ScrollController();

  @override
  TextEditingController get editorController => _input;

  @override
  void initState() {
    super.initState();
    initEditorContent();
  }

  @override
  void dispose() {
    _input.dispose();
    _outputScroll.dispose();
    super.dispose();
  }

  void _copyOutput(String code) {
    if (code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: code));
    context.showSnack('Dart kodu panoya kopyalandı.');
  }

  /// JSON'u onarır; içeriği değiştirecekse önce onay ister (üzerine yazma
  /// geri döndürülmesi yalnızca "Geri Al"a bağlı olduğundan).
  Future<void> _autoFix() async {
    final rep = repairJson(_input.text);
    if (rep == null) {
      context.showSnack('Onarılamadı: yaygın JSON hataları düzeltilemedi.');
      return;
    }
    if (rep == _input.text) {
      context.showSnack('JSON zaten geçerli.');
      return;
    }
    final ok = await context.confirm(
      title: 'Oto-Düzelt',
      message:
          'JSON onarıldı. Onarım tek tırnak, sondaki virgül ve tırnaksız '
          'anahtar gibi hataları düzeltir; nadiren metin içeriğini '
          'değiştirebilir. Sonuç uygulansın mı? '
          '("Geri Al" ile döndürebilirsiniz.)',
      confirmLabel: 'Uygula',
    );
    if (!mounted || !ok) return;
    cubit.setActiveContent(rep, immediate: true);
  }

  @override
  Widget build(BuildContext context) {
    final codeColors = CodeColors.of(Theme.of(context).brightness);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // JSON girdisi
          Expanded(
            flex: 5,
            child: MultiBlocListener(
              listeners: [contentSyncListener()],
              child: BlocBuilder<WorkspaceCubit, WorkspaceState>(
                buildWhen: (p, c) =>
                    p.jsonErrorLine != c.jsonErrorLine ||
                    p.jsonError != c.jsonError ||
                    p.canUndo != c.canUndo ||
                    p.canRedo != c.canRedo,
                builder: (context, state) {
                  return PaneCard(
                    title: 'JSON',
                    actions: [
                      ToolButton(
                        icon: Icons.content_paste,
                        label: 'Yapıştır',
                        onPressed: pasteIntoActive,
                      ),
                      ToolButton(
                        icon: Icons.upload_file,
                        label: 'İçe Aktar',
                        onPressed: () async {
                          final result = await FilePicker.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['json', 'txt'],
                          );
                          if (result != null && result.files.single.path != null) {
                            final content = await File(result.files.single.path!).readAsString();
                            cubit.setActiveContent(content, immediate: true);
                          }
                        },
                      ),
                      ToolButton(
                        icon: Icons.format_align_left,
                        label: 'Biçimlendir',
                        onPressed: formatActive,
                      ),
                      ToolButton(
                        icon: Icons.auto_fix_high,
                        label: 'Oto-Düzelt',
                        onPressed: _autoFix,
                      ),
                      ToolButton(
                        icon: Icons.undo,
                        label: 'Geri Al',
                        onPressed: state.canUndo ? () => cubit.undo() : null,
                      ),
                      ToolButton(
                        icon: Icons.redo,
                        label: 'İleri Al',
                        onPressed: state.canRedo ? () => cubit.redo() : null,
                      ),
                      ToolButton(
                        icon: Icons.clear,
                        label: 'Temizle',
                        onPressed: () =>
                            cubit.setActiveContent('', immediate: true),
                      ),
                      ToolButton(
                        icon: Icons.account_tree_outlined,
                        label: 'Ağaçta Aç',
                        tooltip: 'Bu JSON\'u görüntüleyici sekmesinde incele',
                        onPressed: widget.onOpenInViewer,
                      ),
                    ],
                    child: Column(
                      children: [
                        Expanded(
                          child: DocumentEditorScope(
                            child: LineNumberedField(
                              controller: _input,
                              errorLine: state.jsonErrorLine,
                              hintText: 'JSON\'u buraya yapıştırın...',
                              onChanged: (t) => cubit.setActiveContent(t),
                            ),
                          ),
                        ),
                        if (state.jsonError != null)
                          ErrorBanner(message: state.jsonError!),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Ayarlar
          SizedBox(
            width: 340,
            child: PaneCard(title: 'Ayarlar', child: const SettingsPanel()),
          ),
          const SizedBox(width: 12),
          // Dart çıktısı
          Expanded(
            flex: 6,
            child: BlocBuilder<WorkspaceCubit, WorkspaceState>(
              buildWhen: (p, c) =>
                  p.dartCode != c.dartCode ||
                  p.genError != c.genError ||
                  p.classCount != c.classCount,
              builder: (context, state) {
                return PaneCard(
                  title: state.classCount > 0
                      ? 'Dart — ${state.classCount} sınıf'
                      : 'Dart',
                  actions: [
                    ToolButton(
                      icon: Icons.copy,
                      label: 'Kodu Kopyala',
                      onPressed: state.dartCode.isEmpty
                          ? null
                          : () => _copyOutput(state.dartCode),
                    ),
                  ],
                  child: state.genError != null
                      ? Align(
                          alignment: Alignment.topCenter,
                          child: ErrorBanner(message: state.genError!),
                        )
                      : state.dartCode.isEmpty
                      ? Center(
                          child: Text(
                            'Çıktı burada görünecek.\n'
                            'Soldaki alana JSON yapıştırın '
                            'veya "Yapıştır" düğmesine basın.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : Scrollbar(
                          controller: _outputScroll,
                          child: SingleChildScrollView(
                            controller: _outputScroll,
                            padding: const EdgeInsets.all(10),
                            child: SelectableText.rich(
                              TextSpan(
                                style: codeTextStyle.copyWith(
                                  color: codeColors.base,
                                ),
                                children: highlightDart(
                                  state.dartCode,
                                  codeColors,
                                ),
                              ),
                            ),
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
