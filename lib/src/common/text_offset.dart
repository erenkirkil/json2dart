/// UTF-16 vekil (surrogate) çiftini ortadan bölmeyen en yakın önceki imleç
/// konumunu döndürür.
///
/// Dizi aralığına sığan bir offset, tek başına geçerli bir imleç konumu
/// DEĞİLDİR: emoji gibi çok kod birimli karakterlerin ortasına düşebilir.
/// Bölünmüş bir çift editöre yazıldığında, sonraki tuş vuruşu araya karakter
/// sokarak eşsiz vekil üretir; gömücü metni Dart'a göndermeden önce UTF-8'e
/// çevirdiği için bu, veri bozulmasına ya da çökmeye yol açar.
///
/// [offset] zaten geçerli bir sınırdaysa aynen döner.
int codePointBoundary(String text, int offset) {
  if (offset <= 0 || offset >= text.length) return offset;
  final before = text.codeUnitAt(offset - 1);
  final at = text.codeUnitAt(offset);
  final splitsPair =
      before >= 0xD800 && before <= 0xDBFF && at >= 0xDC00 && at <= 0xDFFF;
  return splitsPair ? offset - 1 : offset;
}
