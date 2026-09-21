/// Ağaç araması (JsonTreeView) ile ağaç modundaki "Tümünü Değiştir"
/// (ViewerPage) arasındaki sorgu normalleştirmesinin TEK kaynağı.
///
/// İkisi ayrı ayrı normalleştirdiğinde sessiz bir hata oluşuyordu: arama
/// sorguyu trim'lerken değiştirme ham sorguyu kullanıyor, "name " gibi sonda
/// boşluklu bir sorguda sayaç >0 olup düğme etkinleşiyor, fakat hiçbir şey
/// değişmediği hâlde "uygulandı" deniyor ve geçmişe boş bir adım yazılıyordu.
String normalizeTreeQuery(String raw) => raw.trim();

/// Ayrıştırılmış JSON ağacında anahtar adlarında ve String değerlerde
/// [pattern] eşleşmelerini [replacement] ile değiştirir.
///
/// Fiilen değişen düğüm sayısını da döndürür; çağıran 0 durumunda içeriğe hiç
/// dokunmamalıdır (yanıltıcı başarı mesajı ve salt yeniden biçimlendirmeden
/// ibaret bir geri-al adımı oluşmasın).
///
/// Sayı/bool/null gibi String olmayan skalerler değiştirilmez: JSON tipini
/// korumak için kasıtlıdır, bu yüzden değişmiş sayılmazlar.
(dynamic, int) replaceAllInJson(
  dynamic node,
  RegExp pattern,
  String replacement,
) {
  if (node is Map) {
    var changed = 0;
    final result = <String, dynamic>{};
    for (final entry in node.entries) {
      final key = entry.key.toString();
      final newKey = key.replaceAll(pattern, replacement);
      if (newKey != key) changed++;
      final (value, childChanged) = replaceAllInJson(
        entry.value,
        pattern,
        replacement,
      );
      result[newKey] = value;
      changed += childChanged;
    }
    return (result, changed);
  }
  if (node is List) {
    var changed = 0;
    final result = <dynamic>[];
    for (final item in node) {
      final (value, childChanged) = replaceAllInJson(
        item,
        pattern,
        replacement,
      );
      result.add(value);
      changed += childChanged;
    }
    return (result, changed);
  }
  if (node is String) {
    final replaced = node.replaceAll(pattern, replacement);
    return (replaced, replaced == node ? 0 : 1);
  }
  return (node, 0);
}
