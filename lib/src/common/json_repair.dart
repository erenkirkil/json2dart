import 'dart:convert';

/// Yaygın JSON hatalarını onarmaya çalışan basit bir araç.
String? repairJson(String input) {
  if (input.trim().isEmpty) return null;
  
  // Önce doğrudan ayrıştırmayı dene
  try {
    jsonDecode(input);
    return input;
  } catch (_) {}

  var repaired = input;

  // 1. Tek tırnakları çift tırnağa çevir
  // Not: Bu basit yaklaşım string içindeki tek tırnakları bozabilir, ancak onarım aracı olarak kabul edilebilir.
  // Daha güvenli: sadece anahtarlar ve basit değerlerde
  repaired = repaired.replaceAll("'", '"');

  // 2. Sondaki fazlalık virgülleri kaldır: ,} veya ,]
  repaired = repaired.replaceAll(RegExp(r',\s*\}'), '}');
  repaired = repaired.replaceAll(RegExp(r',\s*\]'), ']');

  // 3. Tırnaksız anahtarlara çift tırnak ekle
  // { anahtar: "değer" } -> { "anahtar": "değer" }
  repaired = repaired.replaceAllMapped(RegExp(r'([{,]\s*)([a-zA-Z0-9_]+)(\s*:)'), (match) {
    return '${match[1]}"${match[2]}"${match[3]}';
  });

  try {
    final parsed = jsonDecode(repaired);
    return const JsonEncoder.withIndent('  ').convert(parsed);
  } catch (_) {
    return null; // Onarılamadı
  }
}
