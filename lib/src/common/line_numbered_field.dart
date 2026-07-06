import 'package:flutter/material.dart';

import 'widgets.dart';

/// Sol tarafında satır numarası cetveli olan, kaydırmayla senkron kod editörü.
/// Geçersiz JSON'da [errorLine] satırı kırmızı vurgulanır.
class LineNumberedField extends StatefulWidget {
  const LineNumberedField({
    super.key,
    required this.controller,
    this.onChanged,
    this.errorLine,
    this.hintText,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final int? errorLine;
  final String? hintText;
  final bool readOnly;

  @override
  State<LineNumberedField> createState() => _LineNumberedFieldState();
}

class _LineNumberedFieldState extends State<LineNumberedField> {
  final ScrollController _scroll = ScrollController();

  static const double _fontSize = 13;
  static const double _lineHeight = 1.45;
  static const double _topPad = 10;
  double get _lineExtent => _fontSize * _lineHeight;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  int get _lineCount {
    final text = widget.controller.text;
    if (text.isEmpty) return 1;
    var count = 1;
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) == 0x0A) count++;
    }
    return count;
  }

  double _gutterWidth(int lineCount) {
    final digits = lineCount.toString().length;
    return 20.0 + digits * 8.5;
  }

  /// Satır numarası TextPainter'ları frame'ler arası önbelleği (kaydırma/yazma
  /// sıcak yolunda tekrar layout() yapılmasın diye). Renk değişince temizlenir.
  final Map<String, TextPainter> _gutterCache = {};
  Color? _gutterColorKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textColor = scheme.onSurfaceVariant;
    if (_gutterColorKey != textColor) {
      _gutterCache.clear();
      _gutterColorKey = textColor;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Satır numarası cetveli
        ListenableBuilder(
          listenable: Listenable.merge([_scroll, widget.controller]),
          builder: (context, _) {
            final lineCount = _lineCount;
            final offset = _scroll.hasClients ? _scroll.offset : 0.0;
            return Container(
              width: _gutterWidth(lineCount),
              color: scheme.surfaceContainerLow,
              child: CustomPaint(
                painter: _GutterPainter(
                  lineCount: lineCount,
                  offset: offset,
                  lineExtent: _lineExtent,
                  topPad: _topPad,
                  fontSize: _fontSize,
                  errorLine: widget.errorLine,
                  textColor: textColor,
                  errorColor: scheme.error,
                  errorBg: scheme.error.withValues(alpha: 0.14),
                  cache: _gutterCache,
                ),
              ),
            );
          },
        ),
        VerticalDivider(width: 1, color: scheme.outlineVariant),
        // Metin alanı
        Expanded(
          child: TextField(
            controller: widget.controller,
            scrollController: _scroll,
            readOnly: widget.readOnly,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: codeTextStyle,
            strutStyle: const StrutStyle(
              fontSize: _fontSize,
              height: _lineHeight,
              forceStrutHeight: true,
            ),
            cursorColor: scheme.primary,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.fromLTRB(
                8,
                _topPad,
                10,
                _topPad,
              ),
              border: InputBorder.none,
              hintText: widget.hintText,
              isCollapsed: true,
            ),
            onChanged: widget.onChanged,
          ),
        ),
      ],
    );
  }
}

class _GutterPainter extends CustomPainter {
  _GutterPainter({
    required this.lineCount,
    required this.offset,
    required this.lineExtent,
    required this.topPad,
    required double fontSize,
    required this.errorLine,
    required this.textColor,
    required this.errorColor,
    required this.errorBg,
    required this.cache,
  }) : _normalStyle = _numberStyle(fontSize, textColor, false),
       _errorStyle = _numberStyle(fontSize, errorColor, true);

  final int lineCount;
  final double offset;
  final double lineExtent;
  final double topPad;
  final int? errorLine;
  final Color textColor;
  final Color errorColor;
  final Color errorBg;

  /// Satır numarası -> düzenlenmiş TextPainter önbelleği (State'te tutulur).
  final Map<String, TextPainter> cache;

  final TextStyle _normalStyle;
  final TextStyle _errorStyle;

  static TextStyle _numberStyle(double fontSize, Color color, bool error) =>
      TextStyle(
        fontFamily: 'Consolas',
        fontFamilyFallback: const ['Menlo', 'Courier New', 'monospace'],
        fontSize: fontSize,
        color: color,
        fontWeight: error ? FontWeight.bold : FontWeight.normal,
      );

  @override
  void paint(Canvas canvas, Size size) {
    final first = ((offset - topPad) / lineExtent).floor().clamp(0, lineCount);
    final visible = (size.height / lineExtent).ceil() + 2;
    final last = (first + visible).clamp(0, lineCount);

    for (var i = first; i < last; i++) {
      final lineNo = i + 1;
      final y = topPad + i * lineExtent - offset;
      final isError = errorLine != null && lineNo == errorLine;

      if (isError) {
        canvas.drawRect(
          Rect.fromLTWH(0, y, size.width, lineExtent),
          Paint()..color = errorBg,
        );
      }

      final tp = cache.putIfAbsent(
        '$lineNo|$isError',
        () => TextPainter(
          text: TextSpan(
            text: '$lineNo',
            style: isError ? _errorStyle : _normalStyle,
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
      );
      // sağa hizala (cetvel sağ kenarından 6px içeride)
      final dx = size.width - tp.width - 6;
      final dy = y + (lineExtent - tp.height) / 2;
      tp.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(_GutterPainter old) =>
      old.lineCount != lineCount ||
      old.offset != offset ||
      old.errorLine != errorLine ||
      old.textColor != textColor ||
      old.errorColor != errorColor;
}
