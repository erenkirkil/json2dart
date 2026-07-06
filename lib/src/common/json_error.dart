/// JSON ayrıştırma hatasının 1 tabanlı (satır, sütun) konumu; hesaplanamazsa null.
(int line, int column)? jsonErrorPosition(FormatException e, String source) {
  final offset = e.offset;
  if (offset == null || offset > source.length) return null;
  var line = 1;
  var lastLineStart = 0;
  for (var i = 0; i < offset && i < source.length; i++) {
    if (source.codeUnitAt(i) == 0x0A) {
      line++;
      lastLineStart = i + 1;
    }
  }
  return (line, offset - lastLineStart + 1);
}

/// Hata satırı (1 tabanlı); yoksa null.
int? jsonErrorLineOf(FormatException e, String source) =>
    jsonErrorPosition(e, source)?.$1;

/// JSON ayrıştırma hatasını satır/sütun bilgisiyle okunur hale getirir.
String describeJsonError(FormatException e, String source) {
  final pos = jsonErrorPosition(e, source);
  if (pos == null) return 'Geçersiz JSON: ${e.message}';
  return 'Geçersiz JSON (satır ${pos.$1}, sütun ${pos.$2}): ${e.message}';
}
