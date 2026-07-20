import 'package:flutter/material.dart';

class JsonSyntaxColors {
  JsonSyntaxColors(Brightness b)
    : key = b == Brightness.dark ? const Color(0xFF9CDCFE) : const Color(0xFF001080),
      string = b == Brightness.dark ? const Color(0xFFCE9178) : const Color(0xFFA31515),
      number = b == Brightness.dark ? const Color(0xFFB5CEA8) : const Color(0xFF098658),
      boolean = b == Brightness.dark ? const Color(0xFF569CD6) : const Color(0xFF0000FF),
      nil = b == Brightness.dark ? const Color(0xFF569CD6) : const Color(0xFF0000FF),
      base = b == Brightness.dark ? const Color(0xFFD4D4D4) : const Color(0xFF000000);

  final Color key;
  final Color string;
  final Color number;
  final Color boolean;
  final Color nil;
  final Color base;
}

class JsonSyntaxController extends TextEditingController {
  JsonSyntaxController({super.text});

  static final _regex = RegExp(
    r'(?<key>"(?:\\.|[^"\\])*"\s*:)|'
    r'(?<string>"(?:\\.|[^"\\])*")|'
    r'(?<number>-?\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b)|'
    r'(?<boolean>\b(?:true|false)\b)|'
    r'(?<null>\bnull\b)',
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final colors = JsonSyntaxColors(Theme.of(context).brightness);
    final baseStyle = style ?? const TextStyle();

    if (text.isEmpty) {
      return TextSpan(style: baseStyle, text: text);
    }

    final spans = <TextSpan>[];
    int start = 0;

    for (final match in _regex.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(
          text: text.substring(start, match.start),
          style: baseStyle.copyWith(color: colors.base),
        ));
      }

      if (match.namedGroup('key') != null) {
        spans.add(TextSpan(
          text: match.namedGroup('key'),
          style: baseStyle.copyWith(color: colors.key),
        ));
      } else if (match.namedGroup('string') != null) {
        spans.add(TextSpan(
          text: match.namedGroup('string'),
          style: baseStyle.copyWith(color: colors.string),
        ));
      } else if (match.namedGroup('number') != null) {
        spans.add(TextSpan(
          text: match.namedGroup('number'),
          style: baseStyle.copyWith(color: colors.number),
        ));
      } else if (match.namedGroup('boolean') != null) {
        spans.add(TextSpan(
          text: match.namedGroup('boolean'),
          style: baseStyle.copyWith(color: colors.boolean),
        ));
      } else if (match.namedGroup('null') != null) {
        spans.add(TextSpan(
          text: match.namedGroup('null'),
          style: baseStyle.copyWith(color: colors.nil),
        ));
      }

      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: baseStyle.copyWith(color: colors.base),
      ));
    }

    return TextSpan(style: baseStyle, children: spans);
  }
}
