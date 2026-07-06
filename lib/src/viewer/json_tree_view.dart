import 'dart:convert';

import 'package:flutter/material.dart';

import '../common/json_preview.dart';
import '../common/widgets.dart';

/// Ağaçtaki düğüm renkleri.
class _TreeColors {
  _TreeColors(Brightness b)
    : key = b == Brightness.dark
          ? const Color(0xFF9CDCFE)
          : const Color(0xFF001080),
      string = b == Brightness.dark
          ? const Color(0xFF6AAB73)
          : const Color(0xFF067D17),
      number = b == Brightness.dark
          ? const Color(0xFF2AACB8)
          : const Color(0xFF1750EB),
      boolean = b == Brightness.dark
          ? const Color(0xFFCF8E6D)
          : const Color(0xFF871094),
      nil = b == Brightness.dark
          ? const Color(0xFFE06C75)
          : const Color(0xFFB71C1C),
      container = b == Brightness.dark
          ? const Color(0xFF7A7E85)
          : const Color(0xFF6E6E6E);

  final Color key;
  final Color string;
  final Color number;
  final Color boolean;
  final Color nil;
  final Color container;
}

class _FlatNode {
  _FlatNode({
    required this.path,
    required this.label,
    required this.value,
    required this.depth,
  });

  final String path;

  /// Nesne anahtarı ya da dizi indeksi ("[3]"); kökte null.
  final String? label;

  final dynamic value;
  final int depth;

  bool get isContainer => value is Map || value is List;
}

/// Anahtar/indeksten benzersiz, kaçışlı yol üretir. Anahtar içinde '.', '['
/// veya ']' geçse bile iki farklı düğümün aynı yolu almasını önler
/// (JSONPath köşeli-parantez notasyonu; anahtarlar tırnaklanır).
String _childPath(String parent, Object keyOrIndex, {required bool isKey}) =>
    isKey ? '$parent[${jsonEncode(keyOrIndex)}]' : '$parent[$keyOrIndex]';

/// Genişletilebilir/daraltılabilir JSON ağacı.
class JsonTreeView extends StatefulWidget {
  const JsonTreeView({
    super.key,
    required this.root,
    required this.revision,
    this.onSelect,
  });

  final dynamic root;

  /// Yeni bir JSON ayrıştırıldığında artar; ağaç durumunu sıfırlar.
  final int revision;

  final void Function(String path, dynamic value)? onSelect;

  @override
  State<JsonTreeView> createState() => JsonTreeViewState();
}

class JsonTreeViewState extends State<JsonTreeView> {
  static const int _maxAutoExpandNodes = 20000;

  final Set<String> _expanded = <String>{r'$'};
  String? _selectedPath;

  /// Düzleştirilmiş düğüm listesi önbelleği; yalnızca yapı (genişletme)
  /// değişince geçersizleştirilir. Seçim değişiminde yeniden hesaplanmaz.
  List<_FlatNode>? _cachedNodes;

  @override
  void didUpdateWidget(covariant JsonTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) {
      _expanded
        ..clear()
        ..add(r'$');
      // Kökün ilk seviyesini otomatik aç.
      final root = widget.root;
      if (root is Map) {
        for (final key in root.keys) {
          final child = root[key];
          if (child is Map || child is List) {
            _expanded.add(_childPath(r'$', key.toString(), isKey: true));
          }
        }
      }
      _selectedPath = null;
      _cachedNodes = null;
    }
  }

  /// Tüm düğümleri aç (çok büyük JSON'larda üst sınırla).
  void expandAll() {
    setState(() {
      var count = 0;
      void visit(dynamic value, String path) {
        if (count > _maxAutoExpandNodes) return;
        if (value is Map) {
          _expanded.add(path);
          count++;
          value.forEach(
            (k, v) => visit(v, _childPath(path, k.toString(), isKey: true)),
          );
        } else if (value is List) {
          _expanded.add(path);
          count++;
          for (var i = 0; i < value.length; i++) {
            visit(value[i], _childPath(path, i, isKey: false));
          }
        }
      }

      visit(widget.root, r'$');
      _cachedNodes = null;
    });
  }

  void collapseAll() {
    setState(() {
      _expanded
        ..clear()
        ..add(r'$');
      _cachedNodes = null;
    });
  }

  List<_FlatNode> _flatten() {
    final nodes = <_FlatNode>[];

    void visit(dynamic value, String? label, String path, int depth) {
      nodes.add(
        _FlatNode(path: path, label: label, value: value, depth: depth),
      );
      if (!_expanded.contains(path)) return;
      if (value is Map) {
        value.forEach((k, v) {
          visit(
            v,
            k.toString(),
            _childPath(path, k.toString(), isKey: true),
            depth + 1,
          );
        });
      } else if (value is List) {
        for (var i = 0; i < value.length; i++) {
          visit(value[i], '[$i]', _childPath(path, i, isKey: false), depth + 1);
        }
      }
    }

    visit(widget.root, null, r'$', 0);
    return nodes;
  }

  void _toggle(_FlatNode node) {
    setState(() {
      if (!_expanded.remove(node.path)) {
        _expanded.add(node.path);
      }
      _selectedPath = node.path;
      _cachedNodes = null;
    });
    widget.onSelect?.call(node.path, node.value);
  }

  void _select(_FlatNode node) {
    setState(() => _selectedPath = node.path);
    widget.onSelect?.call(node.path, node.value);
  }

  Color _valueColor(dynamic value, _TreeColors colors) {
    if (value == null) return colors.nil;
    if (value is String) return colors.string;
    if (value is num) return colors.number;
    if (value is bool) return colors.boolean;
    return colors.container;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _TreeColors(theme.brightness);
    final nodes = _cachedNodes ??= _flatten();

    return ListView.builder(
      itemExtent: 24,
      itemCount: nodes.length,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (context, index) {
        final node = nodes[index];
        final selected = node.path == _selectedPath;
        return InkWell(
          onTap: () => node.isContainer ? _toggle(node) : _select(node),
          child: Container(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : null,
            padding: EdgeInsets.only(left: 4.0 + node.depth * 18),
            child: Row(
              children: [
                if (node.isContainer)
                  Icon(
                    _expanded.contains(node.path)
                        ? Icons.arrow_drop_down
                        : Icons.arrow_right,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  )
                else
                  const SizedBox(width: 18),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: codeTextStyle.copyWith(fontSize: 12.5),
                      children: [
                        if (node.label != null) ...[
                          TextSpan(
                            text: node.label,
                            style: TextStyle(color: colors.key),
                          ),
                          const TextSpan(text: ' : '),
                        ] else
                          TextSpan(
                            text: node.value is List ? 'JSON []' : 'JSON ',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        TextSpan(
                          text: jsonValuePreview(node.value),
                          style: TextStyle(
                            color: _valueColor(node.value, colors),
                            fontStyle: node.value == null
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
