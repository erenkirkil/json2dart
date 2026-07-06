import 'package:equatable/equatable.dart';

/// Üretilecek serileştirme tarzı.
enum SerializerStyle {
  /// Saf Dart: elle yazılmış fromJson/toJson, ek paket gerektirmez
  /// (Equatable açıksa yalnızca equatable).
  manual,

  /// json_serializable anotasyonları + build_runner part dosyası.
  jsonSerializable,

  /// freezed (v3) sınıfları + json_serializable.
  freezed,
}

/// Alanların null durumunun nasıl belirleneceği.
enum NullabilityMode {
  /// JSON örneğinden çıkarım: değeri null olan (veya birleştirilen
  /// örneklerin bazılarında bulunmayan) alanlar nullable olur.
  /// Non-nullable alanlar constructor'da `required` yapılır.
  smart,

  /// Bütün alanlar nullable (`String?`) ve opsiyonel olur.
  allNullable,

  /// Bütün alanlar non-nullable ve `required` olur.
  /// (JSON'da null görülen alanlar yine de nullable kalır, aksi halde
  /// üretilen kod çalışma anında patlar.)
  nonNullable,
}

/// Kod üretimini yönlendiren tüm ayarlar.
class GeneratorSettings extends Equatable {
  const GeneratorSettings({
    this.rootClassName = 'Model',
    this.style = SerializerStyle.jsonSerializable,
    this.nullability = NullabilityMode.smart,
    this.typesOnly = false,
    this.finalFields = true,
    this.copyWith = true,
    this.equatable = true,
    this.rawJsonHelpers = false,
    this.useMapMethodNames = false,
    this.detectDates = true,
    this.detectMaps = true,
    this.mergeSimilarClasses = true,
    this.hiveAnnotations = false,
    this.partName = '',
    this.targetPath = 'lib/models/model.dart',
  });

  /// Kök sınıfın adı.
  final String rootClassName;

  final SerializerStyle style;

  final NullabilityMode nullability;

  /// true ise fromJson/toJson üretilmez, yalnızca sınıf tanımları çıkar.
  final bool typesOnly;

  /// Alanlar `final` olsun (immutability — bloc/cubit için önerilir).
  final bool finalFields;

  /// copyWith metodu üret (freezed zaten kendisi üretir).
  final bool copyWith;

  /// Equatable extend edilsin, props üretilsin (freezed'de gereksiz).
  final bool equatable;

  /// fromRawJson(String) / toRawJson() yardımcıları (dart:convert sarmalayıcı).
  final bool rawJsonHelpers;

  /// fromJson/toJson yerine fromMap/toMap isimlendirmesi (yalnızca saf Dart).
  final bool useMapMethodNames;

  /// ISO-8601 string'leri DateTime olarak üret.
  final bool detectDates;

  /// Anahtarları veri gibi görünen nesneleri (ör. `{"1": {...}, "2": {...}}`)
  /// sınıf yerine `Map<String, T>` olarak üret.
  final bool detectMaps;

  /// Alan adları birebir aynı olan sınıfları tek sınıfta birleştir.
  final bool mergeSimilarClasses;

  /// @HiveType/@HiveField anotasyonları ekle (freezed ile kullanılamaz).
  final bool hiveAnnotations;

  /// `part` yönergesinde kullanılacak dosya adı (boşsa hedef yoldan türetilir).
  final String partName;

  /// Modelin projede yapıştırılacağı dosya yolu; build_runner komutu ve
  /// part dosya adı bundan türetilir (ör. lib/data/models/user_model.dart).
  final String targetPath;

  /// targetPath'i tek yerde normalize edip (dizin, temel ad) olarak böler.
  /// Kenar durumlar (boş yol, klasörsüz dosya adı, ters bölü, sondaki '/',
  /// Dart sonekleri) tek kaynakta ele alınır ki iki getter senkron kalsın.
  ({String dir, String base}) get _splitTarget {
    var p = targetPath.trim().replaceAll('\\', '/');
    if (p.endsWith('/')) p = p.substring(0, p.length - 1);
    final slash = p.lastIndexOf('/');
    final dir = slash < 0 ? 'lib/models' : p.substring(0, slash);
    final rawName = slash < 0 ? p : p.substring(slash + 1);
    final base = rawName
        .replaceAll('.freezed.dart', '')
        .replaceAll('.g.dart', '')
        .replaceAll(RegExp(r'\.dart$'), '')
        .trim();
    return (dir: dir, base: base.isEmpty ? 'model' : base);
  }

  /// Hedef yoldan dosya adı (uzantısız): lib/models/user_model.dart -> user_model
  String get targetBaseName => _splitTarget.base;

  /// Hedef dosyanın dizini: lib/models/user_model.dart -> lib/models
  String get targetDir => _splitTarget.dir;

  /// Üretim tarzı build_runner gerektiriyor mu?
  bool get needsBuildRunner =>
      !typesOnly && effectiveStyle != SerializerStyle.manual;

  static const _noBuildRunnerNote =
      '# Bu üretim tarzı build_runner gerektirmez (saf Dart / sadece tipler).';

  /// Yalnızca bu modelin üretilmiş çıktılarını hedefleyen, diğer klasörlerdeki
  /// önceden üretilmiş .g.dart/.freezed.dart dosyalarını silmeyen ve yeniden
  /// üretmeyen build_runner komutu. `--build-filter` kapsamı bu dosyayla
  /// sınırlar; `--delete-conflicting-outputs` KULLANILMAZ (silme yapmaz).
  String get buildRunnerCommand {
    if (!needsBuildRunner) return _noBuildRunnerNote;
    final (:dir, :base) = _splitTarget;
    final path = '$dir/$base';
    final filters = <String>['"$path.g.dart"'];
    if (isFreezed) filters.insert(0, '"$path.freezed.dart"');
    final filterArgs = filters.map((f) => '--build-filter=$f').join(' ');
    return 'dart run build_runner build $filterArgs';
  }

  /// Tüm projenin üretilmiş çıktılarını yeniden üreten tam build komutu.
  /// `--delete-conflicting-outputs` ile çakışan/öksüz çıktıları temizler
  /// (elle yazılan kaynak kodu etkilenmez). Filtre yoktur: her şey tazelenir.
  String get buildRunnerFullCommand {
    if (!needsBuildRunner) return _noBuildRunnerNote;
    return 'dart run build_runner build --delete-conflicting-outputs';
  }

  /// Etkin üretim tarzı: "sadece tipler" açıkken serileştirme tamamen kapalı
  /// olduğundan anotasyon tarzlarının anlamı kalmaz.
  SerializerStyle get effectiveStyle =>
      typesOnly ? SerializerStyle.manual : style;

  bool get isFreezed => effectiveStyle == SerializerStyle.freezed;

  bool get isJsonSerializable =>
      effectiveStyle == SerializerStyle.jsonSerializable;

  /// freezed kendi copyWith'ini üretir.
  bool get effectiveCopyWith => !isFreezed && copyWith;

  /// freezed kendi ==/hashCode'unu üretir.
  bool get effectiveEquatable => !isFreezed && equatable;

  /// Hive, freezed ile birlikte desteklenmiyor.
  bool get effectiveHive => !isFreezed && !typesOnly && hiveAnnotations;

  /// freezed sınıfına metot eklenemediği için raw JSON yardımcıları
  /// yalnızca diğer tarzlarda üretilir.
  bool get effectiveRawJson => !isFreezed && !typesOnly && rawJsonHelpers;

  /// fromMap/toMap isimlendirmesi yalnızca saf Dart tarzında geçerli.
  bool get effectiveMapNames =>
      effectiveStyle == SerializerStyle.manual && useMapMethodNames;

  String get fromMethodName => effectiveMapNames ? 'fromMap' : 'fromJson';

  String get toMethodName => effectiveMapNames ? 'toMap' : 'toJson';

  GeneratorSettings copyWithSettings({
    String? rootClassName,
    SerializerStyle? style,
    NullabilityMode? nullability,
    bool? typesOnly,
    bool? finalFields,
    bool? copyWith,
    bool? equatable,
    bool? rawJsonHelpers,
    bool? useMapMethodNames,
    bool? detectDates,
    bool? detectMaps,
    bool? mergeSimilarClasses,
    bool? hiveAnnotations,
    String? partName,
    String? targetPath,
  }) {
    return GeneratorSettings(
      rootClassName: rootClassName ?? this.rootClassName,
      style: style ?? this.style,
      nullability: nullability ?? this.nullability,
      typesOnly: typesOnly ?? this.typesOnly,
      finalFields: finalFields ?? this.finalFields,
      copyWith: copyWith ?? this.copyWith,
      equatable: equatable ?? this.equatable,
      rawJsonHelpers: rawJsonHelpers ?? this.rawJsonHelpers,
      useMapMethodNames: useMapMethodNames ?? this.useMapMethodNames,
      detectDates: detectDates ?? this.detectDates,
      detectMaps: detectMaps ?? this.detectMaps,
      mergeSimilarClasses: mergeSimilarClasses ?? this.mergeSimilarClasses,
      hiveAnnotations: hiveAnnotations ?? this.hiveAnnotations,
      partName: partName ?? this.partName,
      targetPath: targetPath ?? this.targetPath,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'rootClassName': rootClassName,
    'style': style.name,
    'nullability': nullability.name,
    'typesOnly': typesOnly,
    'finalFields': finalFields,
    'copyWith': copyWith,
    'equatable': equatable,
    'rawJsonHelpers': rawJsonHelpers,
    'useMapMethodNames': useMapMethodNames,
    'detectDates': detectDates,
    'detectMaps': detectMaps,
    'mergeSimilarClasses': mergeSimilarClasses,
    'hiveAnnotations': hiveAnnotations,
    'partName': partName,
    'targetPath': targetPath,
  };

  factory GeneratorSettings.fromJson(Map<String, dynamic> json) {
    const defaults = GeneratorSettings();
    return GeneratorSettings(
      rootClassName: json['rootClassName'] as String? ?? defaults.rootClassName,
      style:
          SerializerStyle.values.asNameMap()[json['style']] ?? defaults.style,
      nullability:
          NullabilityMode.values.asNameMap()[json['nullability']] ??
          defaults.nullability,
      typesOnly: json['typesOnly'] as bool? ?? defaults.typesOnly,
      finalFields: json['finalFields'] as bool? ?? defaults.finalFields,
      copyWith: json['copyWith'] as bool? ?? defaults.copyWith,
      equatable: json['equatable'] as bool? ?? defaults.equatable,
      rawJsonHelpers:
          json['rawJsonHelpers'] as bool? ?? defaults.rawJsonHelpers,
      useMapMethodNames:
          json['useMapMethodNames'] as bool? ?? defaults.useMapMethodNames,
      detectDates: json['detectDates'] as bool? ?? defaults.detectDates,
      detectMaps: json['detectMaps'] as bool? ?? defaults.detectMaps,
      mergeSimilarClasses:
          json['mergeSimilarClasses'] as bool? ?? defaults.mergeSimilarClasses,
      hiveAnnotations:
          json['hiveAnnotations'] as bool? ?? defaults.hiveAnnotations,
      partName: json['partName'] as String? ?? defaults.partName,
      targetPath: json['targetPath'] as String? ?? defaults.targetPath,
    );
  }

  @override
  List<Object?> get props => [
    rootClassName,
    style,
    nullability,
    typesOnly,
    finalFields,
    copyWith,
    equatable,
    rawJsonHelpers,
    useMapMethodNames,
    detectDates,
    detectMaps,
    mergeSimilarClasses,
    hiveAnnotations,
    partName,
    targetPath,
  ];
}
