import 'package:flutter/material.dart';

/// Kod vurgulama renk paleti (açık/koyu tema).
class CodeColors {
  const CodeColors({
    required this.base,
    required this.keyword,
    required this.type,
    required this.string,
    required this.number,
    required this.comment,
    required this.annotation,
  });

  factory CodeColors.of(Brightness brightness) =>
      brightness == Brightness.dark ? _dark : _light;

  static const _light = CodeColors(
    base: Color(0xFF24292E),
    keyword: Color(0xFF0033B3),
    type: Color(0xFF00627A),
    string: Color(0xFF067D17),
    number: Color(0xFF1750EB),
    comment: Color(0xFF8C8C8C),
    annotation: Color(0xFF9E880D),
  );

  static const _dark = CodeColors(
    base: Color(0xFFBCBEC4),
    keyword: Color(0xFFCF8E6D),
    type: Color(0xFF56B6C2),
    string: Color(0xFF6AAB73),
    number: Color(0xFF2AACB8),
    comment: Color(0xFF7A7E85),
    annotation: Color(0xFFB3AE60),
  );

  final Color base;
  final Color keyword;
  final Color type;
  final Color string;
  final Color number;
  final Color comment;
  final Color annotation;
}

const Set<String> _keywords = {
  'abstract',
  'as',
  'assert',
  'async',
  'await',
  'base',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'covariant',
  'default',
  'do',
  'dynamic',
  'else',
  'enum',
  'export',
  'extends',
  'extension',
  'external',
  'factory',
  'false',
  'final',
  'finally',
  'for',
  'get',
  'if',
  'implements',
  'import',
  'in',
  'is',
  'late',
  'library',
  'mixin',
  'new',
  'null',
  'on',
  'operator',
  'override',
  'part',
  'required',
  'rethrow',
  'return',
  'sealed',
  'set',
  'static',
  'super',
  'switch',
  'this',
  'throw',
  'true',
  'try',
  'typedef',
  'var',
  'void',
  'when',
  'while',
  'with',
  'yield',
};

const Set<String> _builtinTypes = {
  'int',
  'double',
  'num',
  'bool',
  'String',
  'List',
  'Map',
  'Set',
  'Object',
  'DateTime',
  'Duration',
  'Iterable',
  'Future',
  'Stream',
};

final RegExp _tokenRegExp = RegExp(
  r"//[^\n]*"
  r"|'(?:[^'\\\n]|\\.)*'?"
  r'|@[A-Za-z_$][A-Za-z0-9_$]*'
  r'|[A-Za-z_$][A-Za-z0-9_$]*'
  r'|\d+\.\d+'
  r'|\d+',
);

/// Dart kaynak kodunu renklendirilmiş span listesine çevirir.
List<TextSpan> highlightDart(String code, CodeColors colors) {
  final spans = <TextSpan>[];
  var last = 0;
  for (final match in _tokenRegExp.allMatches(code)) {
    if (match.start > last) {
      spans.add(TextSpan(text: code.substring(last, match.start)));
    }
    final token = match[0]!;
    Color? color;
    if (token.startsWith('//')) {
      color = colors.comment;
    } else if (token.startsWith("'")) {
      color = colors.string;
    } else if (token.startsWith('@')) {
      color = colors.annotation;
    } else if (token.codeUnitAt(0) >= 0x30 && token.codeUnitAt(0) <= 0x39) {
      color = colors.number;
    } else if (_keywords.contains(token)) {
      color = colors.keyword;
    } else if (_builtinTypes.contains(token) ||
        (token.codeUnitAt(0) >= 0x41 && token.codeUnitAt(0) <= 0x5A)) {
      color = colors.type;
    }
    spans.add(
      TextSpan(
        text: token,
        style: color == null ? null : TextStyle(color: color),
      ),
    );
    last = match.end;
  }
  if (last < code.length) {
    spans.add(TextSpan(text: code.substring(last)));
  }
  return spans;
}
