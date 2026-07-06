/// Bir JSON değerinin kısa, tek satırlık metin önizlemesini üretir.
/// Ağaç düğümleri ve detay panelinde ortak kullanılır.
///
/// [maxLen] > 0 ise string'ler kısaltılır (0 = kısaltma yok).
/// [verbose] true ise konteynerler eleman türünü de yazar ('{…} 3 alan').
String jsonValuePreview(
  dynamic value, {
  int maxLen = 80,
  bool verbose = false,
}) {
  if (value == null) return 'null';
  if (value is String) {
    final oneLine = value.replaceAll('\n', r'\n');
    final shown = maxLen > 0 && oneLine.length > maxLen
        ? '${oneLine.substring(0, maxLen)}…'
        : oneLine;
    return '"$shown"';
  }
  if (value is Map) {
    return verbose ? '{…} ${value.length} alan' : '{…} ${value.length}';
  }
  if (value is List) {
    return verbose ? '[…] ${value.length} öğe' : '[…] ${value.length}';
  }
  return value.toString();
}
