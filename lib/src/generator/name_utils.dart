/// JSON anahtarlarından geçerli Dart tanımlayıcıları üretme yardımcıları.
library;

const Set<String> _dartKeywords = {
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
  'deferred',
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
  'hide',
  'if',
  'implements',
  'import',
  'in',
  'interface',
  'is',
  'late',
  'library',
  'mixin',
  'new',
  'null',
  'of',
  'on',
  'operator',
  'out',
  'part',
  'required',
  'rethrow',
  'return',
  'sealed',
  'set',
  'show',
  'static',
  'super',
  'switch',
  'sync',
  'this',
  'throw',
  'true',
  'try',
  'type',
  'typedef',
  'var',
  'void',
  'when',
  'while',
  'with',
  'yield',
};

/// Object üyeleri ve üreteceğimiz üyelerle çakışan alan adları.
const Set<String> _reservedMemberNames = {
  'hashCode',
  'runtimeType',
  'noSuchMethod',
  'toString',
  'props',
  'copyWith',
  'stringify',
  'json',
  'toJson',
  'toMap',
  'toRawJson',
  'fromJson',
  'fromMap',
  'fromRawJson',
};

/// Çekirdek/yaygın tiplerle çakışmaması gereken sınıf adları.
const Set<String> _reservedClassNames = {
  'String',
  'int',
  'double',
  'num',
  'bool',
  'List',
  'Map',
  'Set',
  'Iterable',
  'Object',
  'Null',
  'DateTime',
  'Duration',
  'Type',
  'Function',
  'Symbol',
  'BigInt',
  'Uri',
  'RegExp',
  'Enum',
  'Record',
  'Comparable',
  'Iterator',
  'Equatable',
  'JsonKey',
  'JsonSerializable',
  'HiveType',
  'HiveField',
};

const Map<String, String> _translitMap = {
  'ç': 'c',
  'Ç': 'C',
  'ğ': 'g',
  'Ğ': 'G',
  'ı': 'i',
  'İ': 'I',
  'ö': 'o',
  'Ö': 'O',
  'ş': 's',
  'Ş': 'S',
  'ü': 'u',
  'Ü': 'U',
  'â': 'a',
  'î': 'i',
  'û': 'u',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'á': 'a',
  'à': 'a',
  'ä': 'a',
  'ó': 'o',
  'ò': 'o',
  'í': 'i',
  'ú': 'u',
  'ñ': 'n',
  'ß': 'ss',
};

String _transliterate(String input) {
  final sb = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    sb.write(_translitMap[ch] ?? ch);
  }
  return sb.toString();
}

/// Bir string'i kelimelere ayırır: ayraçlar (_ - boşluk vs.) ve
/// büyük/küçük harf geçişleri sınır kabul edilir.
List<String> splitIntoWords(String input) {
  final cleaned = _transliterate(
    input,
  ).replaceAll(RegExp(r'[^A-Za-z0-9]+'), ' ').trim();
  if (cleaned.isEmpty) return const [];

  final words = <String>[];
  for (final chunk in cleaned.split(RegExp(r'\s+'))) {
    // camelCase / PascalCase / SCREAMING_CASE sınırlarını ayır.
    final parts = chunk.split(
      RegExp(
        r'(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])|(?<=[A-Za-z])(?=[0-9])',
      ),
    );
    words.addAll(parts.where((p) => p.isNotEmpty));
  }
  return words;
}

String _capitalize(String word) => word.isEmpty
    ? word
    : word[0].toUpperCase() + word.substring(1).toLowerCase();

/// JSON anahtarından camelCase Dart alan adı üretir.
String toCamelCase(String input) {
  final words = splitIntoWords(input);
  if (words.isEmpty) return 'field';
  final sb = StringBuffer(words.first.toLowerCase());
  for (final w in words.skip(1)) {
    sb.write(_capitalize(w));
  }
  var result = sb.toString();
  if (RegExp(r'^[0-9]').hasMatch(result)) result = 'the$result';
  if (_dartKeywords.contains(result)) result = '${result}Value';
  if (_reservedMemberNames.contains(result)) result = '${result}Field';
  return result;
}

/// JSON anahtarından PascalCase Dart sınıf adı üretir.
String toPascalCase(String input) {
  final words = splitIntoWords(input);
  if (words.isEmpty) return 'UnnamedClass';
  final sb = StringBuffer();
  for (final w in words) {
    sb.write(_capitalize(w));
  }
  var result = sb.toString();
  if (RegExp(r'^[0-9]').hasMatch(result)) result = 'The$result';
  if (_dartKeywords.contains(result.toLowerCase()) ||
      _reservedClassNames.contains(result)) {
    result = '${result}Model';
  }
  return result;
}

/// Basit İngilizce tekilleştirme: "routes" -> "route", "cities" -> "city".
String singularize(String word) {
  if (word.length <= 2) return word;
  final lower = word.toLowerCase();
  if (lower.endsWith('ies') && word.length > 3) {
    return '${word.substring(0, word.length - 3)}y';
  }
  if (lower.endsWith('sses') ||
      lower.endsWith('xes') ||
      lower.endsWith('ches') ||
      lower.endsWith('shes') ||
      lower.endsWith('zes')) {
    return word.substring(0, word.length - 2);
  }
  if (lower.endsWith('ss') || lower.endsWith('us') || lower.endsWith('is')) {
    return word; // status, address, analysis...
  }
  if (lower.endsWith('s')) {
    return word.substring(0, word.length - 1);
  }
  return word;
}

/// PascalCase sınıf adını snake_case dosya adına çevirir
/// (part yönergesi için).
String toSnakeCase(String input) {
  final words = splitIntoWords(input);
  if (words.isEmpty) return 'model';
  return words.map((w) => w.toLowerCase()).join('_');
}
