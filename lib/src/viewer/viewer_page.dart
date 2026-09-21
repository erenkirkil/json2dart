import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../common/context_ext.dart';
import '../common/json_preview.dart';
import '../common/line_numbered_field.dart';
import '../common/json_repair.dart';
import '../common/json_syntax_controller.dart';
import '../common/widgets.dart';
import '../documents/active_document_editor.dart';
import '../documents/workspace_cubit.dart';
import 'json_search.dart';
import 'json_tree_view.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

class SearchIntent extends Intent {
  const SearchIntent();
}

class CloseSearchIntent extends Intent {
  const CloseSearchIntent();
}

/// JSON görüntüleyici / biçimlendirici ekranı (aktif belge üzerinde çalışır).
class ViewerPage extends StatefulWidget {
  const ViewerPage({
    super.key,
    required this.onConvert,
    this.isActive = true,
  });

  /// Dönüştürücü sekmesine geçiş (içerik paylaşımlı).
  final VoidCallback onConvert;

  /// Bu sayfa görünür sekme mi. IndexedStack gizli çocuklarını ExcludeFocus
  /// ile sardığı için initState'teki autofocus isteği sessizce düşer ve bir
  /// daha denenmez; sekme görünür olunca odak açıkça istenir, aksi hâlde
  /// Cmd/Ctrl+F kullanıcı pane'e tıklayana kadar çalışmaz.
  final bool isActive;

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> with ActiveDocumentEditor {
  final JsonSyntaxController _text = JsonSyntaxController();
  final GlobalKey<JsonTreeViewState> _treeKey = GlobalKey<JsonTreeViewState>();
  final TextEditingController _search = TextEditingController();
  final TextEditingController _replace = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final FocusNode _pageFocus = FocusNode(debugLabel: 'ViewerPage');
  Timer? _searchDebounce;

  bool _showText = false;
  bool _isSearchVisible = false;
  String? _selectedPath;
  dynamic _selectedValue;
  String _searchQuery = '';
  int _matchCount = 0;
  int _matchIndex = -1;
  
  final List<int> _textMatchOffsets = [];
  int _textMatchIndex = -1;

  @override
  TextEditingController get editorController => _text;

  @override
  void initState() {
    super.initState();
    initEditorContent();
  }

  @override
  void didUpdateWidget(ViewerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _pageFocus.requestFocus();
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _search.dispose();
    _replace.dispose();
    _searchFocus.dispose();
    _pageFocus.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() => _searchQuery = value);
        _performSearch();
      }
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _search.clear();
    setState(() {
      _searchQuery = '';
      _performSearch();
    });
  }

  void _performSearch() {
    if (_showText) {
      _textMatchOffsets.clear();
      _textMatchIndex = -1;
      _matchCount = 0;
      _matchIndex = -1;
      if (_searchQuery.isNotEmpty) {
        final text = _text.text;
        int i = 0;
        while (true) {
          final idx = text.toLowerCase().indexOf(_searchQuery.toLowerCase(), i);
          if (idx == -1) break;
          _textMatchOffsets.add(idx);
          i = idx + _searchQuery.length;
        }
        _matchCount = _textMatchOffsets.length;
        if (_matchCount > 0) {
          _textMatchIndex = 0;
          _matchIndex = 0;
          _highlightTextMatch();
        }
      }
      setState(() {});
    } else {
      if (_searchQuery.isEmpty) {
        setState(() {
          _matchCount = 0;
          _matchIndex = -1;
        });
      }
    }
  }

  void _highlightTextMatch() {
    if (_textMatchIndex >= 0 && _textMatchIndex < _textMatchOffsets.length) {
      final start = _textMatchOffsets[_textMatchIndex];
      final end = start + _searchQuery.length;
      _text.selection = TextSelection(baseOffset: start, extentOffset: end);
    }
  }

  void _nextMatch() {
    if (_showText) {
      if (_matchCount > 0) {
        setState(() {
          _textMatchIndex = (_textMatchIndex + 1) % _matchCount;
          _matchIndex = _textMatchIndex;
        });
        _highlightTextMatch();
      }
    } else {
      _treeKey.currentState?.nextMatch();
    }
  }

  void _previousMatch() {
    if (_showText) {
      if (_matchCount > 0) {
        setState(() {
          _textMatchIndex = (_textMatchIndex - 1 + _matchCount) % _matchCount;
          _matchIndex = _textMatchIndex;
        });
        _highlightTextMatch();
      }
    } else {
      _treeKey.currentState?.previousMatch();
    }
  }

  void _closeSearch() {
    setState(() {
      _isSearchVisible = false;
      _searchQuery = '';
      _search.clear();
      _matchCount = 0;
      _matchIndex = -1;
      _textMatchOffsets.clear();
      _textMatchIndex = -1;
    });
  }

  void _minify() {
    final mini = cubit.minify(_text.text);
    if (mini == null) {
      context.showSnack('Sıkıştırılamadı: geçerli bir JSON değil.');
      return;
    }
    cubit.setActiveContent(mini, immediate: true);
  }

  /// JSON'u onarır; içeriği değiştirecekse önce onay ister.
  Future<void> _autoFix() async {
    final rep = repairJson(_text.text);
    if (rep == null) {
      context.showSnack('Onarılamadı: yaygın JSON hataları düzeltilemedi.');
      return;
    }
    if (rep == _text.text) {
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

  /// Aramadaki eşleşmeleri, kullanıcı onayladıktan sonra topluca değiştirir.
  Future<void> _replaceAllAction() async {
    // Ağaç modunda sorgu, aramanın kullandığı normalleştirmenin aynısından
    // geçer (normalizeTreeQuery); metin modunda ham metin aranır, boşluk
    // anlamlı olduğu için trim edilmez.
    final query = _showText ? _searchQuery : normalizeTreeQuery(_searchQuery);
    if (query.isEmpty) return;
    final target = _replace.text;
    final ok = await context.confirm(
      title: 'Tümünü Değiştir',
      message: _showText
          ? '$_matchCount eşleşme "$query" → "$target" olarak '
                'değiştirilecek. Bu, metni geçersiz JSON hâline getirebilir. '
                'Devam edilsin mi? ("Geri Al" ile döndürebilirsiniz.)'
          : '"$query" ifadesi ağaçtaki anahtarlarda ve metin '
                'değerlerinde (büyük/küçük harf duyarsız) "$target" ile '
                'değiştirilecek. Devam edilsin mi? '
                '("Geri Al" ile döndürebilirsiniz.)',
      confirmLabel: 'Değiştir',
    );
    if (!mounted || !ok) return;
    final pattern = RegExp(RegExp.escape(query), caseSensitive: false);
    var changedAny = false;
    if (_showText) {
      final newText = _text.text.replaceAll(pattern, target);
      changedAny = newText != _text.text;
      if (changedAny) cubit.setActiveContent(newText, immediate: true);
    } else if (cubit.state.parsed != null) {
      final (replaced, changed) = replaceAllInJson(
        cubit.state.parsed,
        pattern,
        target,
      );
      changedAny = changed > 0;
      if (changedAny) {
        final formatted = const JsonEncoder.withIndent('  ').convert(replaced);
        cubit.setActiveContent(formatted, immediate: true);
      }
    }
    // Hiçbir şey değişmediyse içeriğe dokunma: yanıltıcı başarı mesajı ve
    // salt-biçimlendirmeden ibaret bir geri-al adımı oluşmasın.
    if (!changedAny) {
      context.showSnack('Değiştirme sonucu içerik değişmedi.');
      return;
    }
    context.showSnack('Değiştirme uygulandı.');
    // İçerik değiştiği için eşleşme sayacı/işaretlemeleri tazele (bayat kalmasın).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _performSearch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): const SearchIntent(),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): const SearchIntent(),
        const SingleActivator(LogicalKeyboardKey.escape): const CloseSearchIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          SearchIntent: CallbackAction<SearchIntent>(
            onInvoke: (SearchIntent intent) {
              setState(() {
                _isSearchVisible = true;
              });
              _searchFocus.requestFocus();
              return null;
            },
          ),
          CloseSearchIntent: CallbackAction<CloseSearchIntent>(
            onInvoke: (CloseSearchIntent intent) {
              if (_isSearchVisible) {
                _closeSearch();
              }
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: _pageFocus,
          autofocus: true,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: MultiBlocListener(
                  listeners: [
                    contentSyncListener(
                      onSwitch: () {
                        if (mounted) {
                          _searchDebounce?.cancel();
                          _search.clear();
                          setState(() {
                            _selectedPath = null;
                            _selectedValue = null;
                            _searchQuery = '';
                            _matchCount = 0;
                            _matchIndex = -1;
                            _textMatchOffsets.clear();
                            _textMatchIndex = -1;
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
                          _buildToolbar(state),
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
              ),
              if (_isSearchVisible)
                Positioned(
                  top: 12,
                  right: 12,
                  child: _buildGlobalSearchBar(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(WorkspaceState state) {
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
          onSelectionChanged: (sel) {
            setState(() => _showText = sel.first);
            if (_isSearchVisible) {
              _performSearch();
            }
          },
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
                  icon: Icons.compress,
                  label: 'Boşlukları Sil',
                  onPressed: _minify,
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
                  onPressed: () => cubit.setActiveContent('', immediate: true),
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
      child: DocumentEditorScope(
        child: LineNumberedField(
          controller: _text,
          errorLine: state.jsonErrorLine,
          hintText: 'JSON\'u buraya yapıştırın...',
          onChanged: (t) => cubit.setActiveContent(t),
        ),
      ),
    );
  }

  Widget _buildGlobalSearchBar() {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      color: scheme.surface,
      surfaceTintColor: scheme.surfaceTint,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Arama kutusu
            SizedBox(
              width: 180,
              height: 32,
              child: TextField(
                controller: _search,
                focusNode: _searchFocus,
                onChanged: _onSearchChanged,
                onSubmitted: (_) => _nextMatch(),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Ara...',
                  prefixIcon: const Icon(Icons.search, size: 16),
                  prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  suffixIcon: _search.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 14),
                          onPressed: _clearSearch,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                _matchCount == 0 ? '0/0' : '${_matchIndex + 1}/$_matchCount',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                tooltip: 'Önceki',
                onPressed: _matchCount == 0 ? null : _previousMatch,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                tooltip: 'Sonraki',
                onPressed: _matchCount == 0 ? null : _nextMatch,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              const SizedBox(width: 8),
              Container(width: 1, height: 20, color: scheme.outlineVariant),
              const SizedBox(width: 8),
              // Değiştir kutusu
              SizedBox(
                width: 160,
                height: 32,
                child: TextField(
                  controller: _replace,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Değiştir...',
                    prefixIcon: const Icon(Icons.edit_note, size: 16),
                    prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.find_replace, size: 16),
                tooltip: 'Tümünü Değiştir',
                onPressed: _matchCount == 0 ? null : _replaceAllAction,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
            const SizedBox(width: 8),
            Container(width: 1, height: 20, color: scheme.outlineVariant),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Kapat',
              onPressed: _closeSearch,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
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
                : 'JSON yapıştırın veya "Yapıştır" düğmesine basın.',
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
            actions: [],
            child: JsonTreeView(
              key: _treeKey,
              root: state.parsed,
              revision: state.parseRevision,
              searchQuery: _searchQuery,
              onSelect: (path, value) => setState(() {
                _selectedPath = path;
                _selectedValue = value;
              }),
              onSearchResult: (total, current) {
                if (!mounted) return;
                if (total == _matchCount && current == _matchIndex) return;
                setState(() {
                  _matchCount = total;
                  _matchIndex = current;
                });
              },
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
    if (path == null) {
      return Center(
        child: Text(
          'Düğüm seçilmedi.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            'Yol: $path',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SelectableText(_preview(value)),
        ],
      ),
    );
  }
}
