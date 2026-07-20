import 'package:flutter_test/flutter_test.dart';
import 'package:json2dart_studio/src/generator/json_to_dart_generator.dart';
import 'package:json2dart_studio/src/generator/name_utils.dart';

const _gen = JsonToDartGenerator();

// Testlerin çoğu saf Dart çıktısını doğruladığı için taban varsayılan olarak
// manual tarzı kullanılır; uygulama varsayılanı (json_serializable) ayrı bir
// testle doğrulanır.
GenerationResult _generate(String json, [GeneratorSettings? settings]) =>
    _gen.generate(
      json,
      settings ?? const GeneratorSettings(style: SerializerStyle.manual),
    );

void main() {
  group('isim yardımcıları', () {
    test('camelCase dönüşümü', () {
      expect(toCamelCase('stop_location_id'), 'stopLocationId');
      expect(toCamelCase('HttpStatus'), 'httpStatus');
      expect(toCamelCase('UPPER_CASE'), 'upperCase');
      expect(toCamelCase('e-mail adresi'), 'eMailAdresi');
    });

    test('rakamla başlayan ve rezerve adlar', () {
      expect(toCamelCase('1st_place'), 'the1stPlace');
      expect(toCamelCase('class'), 'classValue');
      expect(toCamelCase('hashCode'), 'hashCodeField');
      expect(toCamelCase('json'), 'jsonField');
      expect(toCamelCase(''), 'field');
      expect(toCamelCase('###'), 'field');
    });

    test('Türkçe karakterler translitere edilir', () {
      expect(toCamelCase('şehir_adı'), 'sehirAdi');
      expect(toCamelCase('ülke'), 'ulke');
    });

    test('PascalCase ve çekirdek tip çakışması', () {
      expect(toPascalCase('user_profile'), 'UserProfile');
      expect(toPascalCase('string'), 'StringModel');
      expect(toPascalCase('list'), 'ListModel');
    });

    test('tekilleştirme', () {
      expect(singularize('routes'), 'route');
      expect(singularize('cities'), 'city');
      expect(singularize('boxes'), 'box');
      expect(singularize('status'), 'status');
      expect(singularize('address'), 'address');
      expect(singularize('legs'), 'leg');
    });

    test('snake_case', () {
      expect(toSnakeCase('RoutePlanResponse'), 'route_plan_response');
    });
  });

  group('tip çıkarımı', () {
    test('temel tipler', () {
      final r = _generate('{"a": 1, "b": 2.5, "c": true, "d": "x", "e": null}');
      expect(r.isSuccess, isTrue);
      expect(r.code, contains('final int a;'));
      expect(r.code, contains('final double b;'));
      expect(r.code, contains('final bool c;'));
      expect(r.code, contains('final String d;'));
      expect(r.code, contains('final dynamic e;'));
    });

    test('int ve double karışımı double olur', () {
      final r = _generate('{"values": [1, 2.5, 3]}');
      expect(r.code, contains('final List<double> values;'));
    });

    test('ISO tarih DateTime olur', () {
      final r = _generate('{"created_at": "2026-07-06T09:30:00Z"}');
      expect(r.code, contains('final DateTime createdAt;'));
      expect(r.code, contains('DateTime.parse'));
      expect(r.code, contains('toIso8601String()'));
    });

    test('tarih algılama kapalıysa String kalır', () {
      final r = _generate(
        '{"created_at": "2026-07-06T09:30:00Z"}',
        const GeneratorSettings(detectDates: false),
      );
      expect(r.code, contains('final String createdAt;'));
    });

    test('tarih benzeri olmayan string String kalır', () {
      final r = _generate('{"desc": "2026 yılında"}');
      expect(r.code, contains('final String desc;'));
    });

    test('boş liste List<dynamic>', () {
      final r = _generate('{"items": []}');
      expect(r.code, contains('final List<dynamic> items;'));
    });

    test('iç içe listeler', () {
      final r = _generate('{"matrix": [[1, 2], [3]]}');
      expect(r.code, contains('final List<List<int>> matrix;'));
    });

    test('heterojen liste List<dynamic>', () {
      final r = _generate('{"mixed": [1, "a"]}');
      expect(r.code, contains('final List<dynamic> mixed;'));
    });

    test('null içeren liste nullable eleman üretir', () {
      final r = _generate('{"vals": [1, null, 3]}');
      expect(r.code, contains('final List<int?> vals;'));
    });
  });

  group('nullability modları', () {
    const json = '{"a": 1, "b": null, "items": [{"x": 1}, {"y": 2}]}';

    test('akıllı mod: null görülen dynamic, görülmeyen required', () {
      final r = _generate(json);
      expect(r.code, contains('required this.a'));
      expect(r.code, contains('this.b'));
      expect(r.code, contains('final dynamic b;'));
      // items elemanlarında x ve y birbirinde eksik -> nullable
      expect(r.code, contains('final int? x;'));
      expect(r.code, contains('final int? y;'));
    });

    test('hepsi nullable', () {
      final r = _generate(
        json,
        const GeneratorSettings(nullability: NullabilityMode.allNullable),
      );
      expect(r.code, contains('final int? a;'));
      expect(r.code, isNot(contains('required')));
    });

    test('hepsi non-null: null görülmeyen alanlar required olur', () {
      final r = _generate(
        json,
        const GeneratorSettings(nullability: NullabilityMode.nonNullable),
      );
      expect(r.code, contains('final int a;'));
      expect(r.code, contains('required this.a'));
    });

    test('hepsi non-null: yalnızca eksik olan (null görülmeyen) alan required olur', () {
      // x ve y birbirlerinin örneğinde EKSİK ama hiç null GÖRÜLMEDİ.
      // smart modda ikisi de nullable; nonNullable modda required non-null olmalı.
      // Bu, iki modun gerçekten farklılaştığını doğrular.
      const j = '{"items": [{"x": 1}, {"y": 2}]}';

      final smart = _generate(j);
      expect(smart.code, contains('final int? x;'));
      expect(smart.code, contains('final int? y;'));

      final nonNull = _generate(
        j,
        const GeneratorSettings(
          style: SerializerStyle.manual,
          nullability: NullabilityMode.nonNullable,
        ),
      );
      expect(nonNull.code, contains('final int x;'));
      expect(nonNull.code, contains('final int y;'));
      expect(nonNull.code, contains('required this.x'));
      expect(nonNull.code, contains('required this.y'));
      expect(nonNull.code, isNot(contains('final int? x;')));
    });

    test('hepsi non-null: veride null görülen alan yine de nullable kalır', () {
      // [{"name":"a"},{"name":null}] -> name veride null görülür.
      // nonNullable modunda bile `String?` üretilmeli, yoksa fromJson patlar.
      final r = _generate(
        '{"items": [{"name": "a"}, {"name": null}]}',
        const GeneratorSettings(
          style: SerializerStyle.manual,
          nullability: NullabilityMode.nonNullable,
        ),
      );
      expect(r.code, contains('final String? name;'));
      expect(r.code, isNot(contains('final String name;')));
      // Non-null erişim (`as String` soru işaretsiz) üretilmemeli.
      expect(r.code, contains('json[\'name\'] as String?'));
    });
  });

  group('sınıf birleştirme', () {
    const json =
        '{"origin": {"lat": 1.0, "lng": 2.0}, '
        '"destination": {"lat": 3.0, "lng": 4.0}}';

    test('aynı alanlara sahip sınıflar birleşir', () {
      final r = _generate(json);
      expect(r.code, contains('class Origin'));
      expect(r.code, isNot(contains('class Destination')));
      expect(r.code, contains('final Origin destination;'));
      expect(r.classCount, 2); // kök + Origin
    });

    test('birleştirme kapalıyken ayrı sınıflar üretilir', () {
      final r = _generate(
        json,
        const GeneratorSettings(mergeSimilarClasses: false),
      );
      expect(r.code, contains('class Origin'));
      expect(r.code, contains('class Destination'));
    });

    test('dizi elemanları birleşirken eksik alanlar nullable olur', () {
      final r = _generate(
        '{"legs": [{"mode": "WALK", "line": null}, '
        '{"mode": "BUS", "line": "34AS"}]}',
      );
      expect(r.code, contains('final String mode;'));
      expect(r.code, contains('final String? line;'));
    });
  });

  group('üretim tarzları', () {
    const json = '{"user_name": "e", "age": 3}';

    test('varsayılan üretim tarzı json_serializable', () {
      expect(const GeneratorSettings().style, SerializerStyle.jsonSerializable);
      // Varsayılan ayarla üretince json_serializable çıktısı gelmeli.
      final r = _gen.generate(json, const GeneratorSettings());
      expect(r.code, contains('@JsonSerializable(explicitToJson: true)'));
    });

    test('saf Dart varsayılanları: Equatable + copyWith + final', () {
      final r = _generate(json);
      expect(r.code, contains("import 'package:equatable/equatable.dart';"));
      expect(r.code, contains('class Model extends Equatable'));
      expect(r.code, contains('Model copyWith('));
      expect(r.code, contains('List<Object?> get props'));
      expect(r.code, contains('const Model({'));
      expect(r.code, contains("userName: json['user_name'] as String"));
    });

    test('json_serializable', () {
      final r = _generate(
        json,
        const GeneratorSettings(style: SerializerStyle.jsonSerializable),
      );
      expect(
        r.code,
        contains("import 'package:json_annotation/json_annotation.dart';"),
      );
      expect(r.code, contains("part 'model.g.dart';"));
      expect(r.code, contains('@JsonSerializable(explicitToJson: true)'));
      expect(r.code, contains("@JsonKey(name: 'user_name')"));
      expect(r.code, contains(r'_$ModelFromJson(json)'));
      expect(r.code, contains(r'_$ModelToJson(this)'));
    });

    test('freezed', () {
      final r = _generate(
        json,
        const GeneratorSettings(style: SerializerStyle.freezed),
      );
      expect(
        r.code,
        contains(
          "import 'package:freezed_annotation/freezed_annotation.dart';",
        ),
      );
      expect(r.code, contains("part 'model.freezed.dart';"));
      expect(r.code, contains("part 'model.g.dart';"));
      expect(r.code, contains('@freezed'));
      expect(r.code, contains(r'abstract class Model with _$Model'));
      expect(r.code, contains('const factory Model({'));
      expect(r.code, contains("@JsonKey(name: 'user_name')"));
      // freezed kendi copyWith/== ürettiği için bunlar olmamalı
      expect(r.code, isNot(contains('extends Equatable')));
      expect(r.code, isNot(contains('Model copyWith(')));
      // İç içe nesne yok -> build.yaml ipucu da olmamalı
      expect(r.code, isNot(contains('explicit_to_json')));
      // freezed sınıfına @JsonSerializable EKLENMEMELİ (build'i kırar)
      expect(r.code, isNot(contains('@JsonSerializable')));
    });

    test('freezed: iç içe nesnede build.yaml ipucu', () {
      final r = _generate(
        '{"user": {"name": "e"}, "items": [{"id": 1}]}',
        const GeneratorSettings(style: SerializerStyle.freezed),
      );
      expect(r.code, contains('explicit_to_json: true'));
      // Yine de sınıfa anotasyon eklenmemeli, sadece yorum
      expect(r.code, isNot(contains('@JsonSerializable')));
    });

    test('sadece tipler', () {
      final r = _generate(json, const GeneratorSettings(typesOnly: true));
      expect(r.code, isNot(contains('fromJson')));
      expect(r.code, isNot(contains('toJson')));
      expect(r.code, contains('final String userName;'));
    });

    test('fromMap/toMap isimlendirmesi', () {
      final r = _generate(
        json,
        const GeneratorSettings(
          style: SerializerStyle.manual,
          useMapMethodNames: true,
        ),
      );
      expect(r.code, contains('factory Model.fromMap('));
      expect(r.code, contains('Map<String, dynamic> toMap()'));
      expect(r.code, isNot(contains('fromJson')));
    });

    test('raw json yardımcıları', () {
      final r = _generate(json, const GeneratorSettings(rawJsonHelpers: true));
      expect(r.code, contains("import 'dart:convert';"));
      expect(r.code, contains('factory Model.fromRawJson(String str)'));
      expect(r.code, contains('String toRawJson()'));
    });

    test('hive anotasyonları', () {
      final r = _generate(json, const GeneratorSettings(hiveAnnotations: true));
      expect(r.code, contains("import 'package:hive/hive.dart';"));
      expect(r.code, contains('@HiveType(typeId: 0)'));
      expect(r.code, contains('@HiveField(0)'));
      expect(r.code, contains('@HiveField(1)'));
      expect(r.code, contains("part 'model.g.dart';"));
    });

    test('copyWith ve Equatable kapatılabilir', () {
      final r = _generate(
        json,
        const GeneratorSettings(copyWith: false, equatable: false),
      );
      expect(r.code, isNot(contains('copyWith')));
      expect(r.code, isNot(contains('Equatable')));
      expect(r.code, isNot(contains('props')));
    });

    test('final kapatılabilir', () {
      final r = _generate(
        json,
        const GeneratorSettings(finalFields: false, equatable: false),
      );
      expect(r.code, contains('String userName;'));
      expect(r.code, isNot(contains('final String userName;')));
      expect(r.code, isNot(contains('const Model({')));
    });

    test('part adı özelleştirilebilir', () {
      final r = _generate(
        json,
        const GeneratorSettings(
          style: SerializerStyle.jsonSerializable,
          partName: 'user_model.dart',
        ),
      );
      expect(r.code, contains("part 'user_model.g.dart';"));
    });
  });

  group('map algılama', () {
    test('sayısal anahtarlar Map olur', () {
      final r = _generate('{"scores": {"1": {"点": 5}, "2": {"点": 9}}}');
      expect(r.code, contains('Map<String, Score>'));
    });

    test('kapalıyken sınıf üretir', () {
      final r = _generate(
        '{"scores": {"1": 5, "2": 9}}',
        const GeneratorSettings(detectMaps: false),
      );
      expect(r.code, isNot(contains('Map<String, int>')));
      expect(r.code, contains('class Scores'));
    });
  });

  group('hedef yol & build_runner', () {
    test('part adı hedef yolun temel adından türetilir', () {
      final r = _generate(
        '{"a": 1}',
        const GeneratorSettings(
          style: SerializerStyle.jsonSerializable,
          targetPath: 'lib/data/models/user_model.dart',
        ),
      );
      expect(r.code, contains("part 'user_model.g.dart';"));
    });

    test('partName hedef yolu geçersiz kılar', () {
      final r = _generate(
        '{"a": 1}',
        const GeneratorSettings(
          style: SerializerStyle.jsonSerializable,
          targetPath: 'lib/models/user_model.dart',
          partName: 'ozel',
        ),
      );
      expect(r.code, contains("part 'ozel.g.dart';"));
    });

    test('build_runner komutu json_serializable için tek filtre', () {
      const s = GeneratorSettings(
        style: SerializerStyle.jsonSerializable,
        targetPath: 'lib/data/models/user_model.dart',
      );
      expect(
        s.buildRunnerCommand,
        'dart run build_runner build '
        '--build-filter="lib/data/models/user_model.g.dart"',
      );
    });

    test('build_runner komutu freezed için iki filtre', () {
      const s = GeneratorSettings(
        style: SerializerStyle.freezed,
        targetPath: 'lib/models/order.dart',
      );
      expect(
        s.buildRunnerCommand,
        'dart run build_runner build '
        '--build-filter="lib/models/order.freezed.dart" '
        '--build-filter="lib/models/order.g.dart"',
      );
    });

    test('tam build komutu filtresiz ve delete-conflicting içerir', () {
      const s = GeneratorSettings(
        style: SerializerStyle.jsonSerializable,
        targetPath: 'lib/models/user_model.dart',
      );
      expect(
        s.buildRunnerFullCommand,
        'dart run build_runner build --delete-conflicting-outputs',
      );
      // Tam komut bir dosyayla sınırlı değildir.
      expect(s.buildRunnerFullCommand, isNot(contains('--build-filter')));
    });

    test('tam build komutu manual/sadece-tip için uyarı verir', () {
      expect(
        const GeneratorSettings(
          style: SerializerStyle.manual,
        ).buildRunnerFullCommand,
        contains('gerektirmez'),
      );
    });

    test('build_runner komutu manual/sadece-tip için uyarı verir', () {
      expect(
        const GeneratorSettings(
          style: SerializerStyle.manual,
        ).buildRunnerCommand,
        contains('gerektirmez'),
      );
      expect(
        const GeneratorSettings(
          style: SerializerStyle.jsonSerializable,
          typesOnly: true,
        ).buildRunnerCommand,
        contains('gerektirmez'),
      );
    });

    test('targetBaseName ve targetDir ayrıştırması', () {
      const s = GeneratorSettings(targetPath: 'lib/a/b/foo_bar.dart');
      expect(s.targetBaseName, 'foo_bar');
      expect(s.targetDir, 'lib/a/b');
    });

    test('targetBaseName kenar durumları: boşluk, .g.dart, klasörsüz, boş', () {
      // Baş/son boşluk temizlenir (trim asimetrisi düzeltmesi).
      expect(
        const GeneratorSettings(
          targetPath: 'lib/models/ user .dart',
        ).targetBaseName,
        'user',
      );
      // .g.dart ve .freezed.dart sonekleri de temizlenir.
      expect(
        const GeneratorSettings(targetPath: 'lib/m/user.g.dart').targetBaseName,
        'user',
      );
      expect(
        const GeneratorSettings(
          targetPath: 'lib/m/user.freezed.dart',
        ).targetBaseName,
        'user',
      );
      // Klasörsüz dosya adı: dir varsayılana düşer, base korunur.
      const folderless = GeneratorSettings(targetPath: 'user_model.dart');
      expect(folderless.targetBaseName, 'user_model');
      expect(folderless.targetDir, 'lib/models');
      // Boş yol: varsayılanlar.
      const empty = GeneratorSettings(targetPath: '   ');
      expect(empty.targetBaseName, 'model');
      expect(empty.targetDir, 'lib/models');
    });

    test('needsBuildRunner tarza göre', () {
      expect(
        const GeneratorSettings(
          style: SerializerStyle.jsonSerializable,
        ).needsBuildRunner,
        isTrue,
      );
      expect(
        const GeneratorSettings(
          style: SerializerStyle.freezed,
        ).needsBuildRunner,
        isTrue,
      );
      expect(
        const GeneratorSettings(style: SerializerStyle.manual).needsBuildRunner,
        isFalse,
      );
      expect(
        const GeneratorSettings(
          style: SerializerStyle.freezed,
          typesOnly: true,
        ).needsBuildRunner,
        isFalse,
      );
    });
  });

  group('kök tipleri', () {
    test('kök liste: yardımcı yorum ve eleman sınıfı', () {
      final r = _generate('[{"id": 1}, {"id": 2}]');
      expect(r.code, contains('class Model'));
      expect(r.code, contains('// Kök JSON bir liste'));
    });

    test('kök liste + raw json: gerçek yardımcı fonksiyonlar', () {
      final r = _generate(
        '[{"id": 1}]',
        const GeneratorSettings(rawJsonHelpers: true),
      );
      expect(r.code, contains('List<Model> modelListFromRawJson(String str)'));
      expect(r.code, contains('String modelListToRawJson(List<Model> data)'));
    });

    test('kök primitif: bilgi yorumu', () {
      final r = _generate('[1, 2, 3]');
      expect(r.isSuccess, isTrue);
      expect(r.code, contains('üretilecek sınıf yok'));
      expect(r.code, contains('List<int>'));
    });
  });

  group('kenar durumlar', () {
    test('geçersiz JSON satır/sütun bildirir', () {
      final r = _generate('{"a": 1,\n  "b": }');
      expect(r.isSuccess, isFalse);
      expect(r.error, contains('satır 2'));
    });

    test('boş girdi', () {
      final r = _generate('   ');
      expect(r.isSuccess, isFalse);
    });

    test('boş nesne', () {
      final r = _generate('{}');
      expect(r.isSuccess, isTrue);
      expect(r.code, contains('class Model'));
      expect(r.code, contains('const Model();'));
    });

    test('özel karakterli anahtarlar', () {
      final r = _generate(r'''{"a b": 1, "c-d": 2, "e$f": 3, "'": 4}''');
      expect(r.isSuccess, isTrue);
      expect(r.code, contains('final int aB;'));
      expect(r.code, contains('final int cD;'));
      expect(r.code, contains(r"json['\'']"));
    });

    test('aynı ada sanitize olan anahtarlar çakışmaz', () {
      final r = _generate('{"user_name": 1, "userName": 2}');
      expect(r.code, contains('final int userName;'));
      expect(r.code, contains('final int userName2;'));
    });

    test('sınıf adı çakışması numaralanır', () {
      final r = _generate(
        '{"data": {"x": 1}, "meta": {"data": {"y": "z"}}}',
        const GeneratorSettings(mergeSimilarClasses: false),
      );
      expect(r.isSuccess, isTrue);
      expect(r.code, contains('class Data'));
      expect(r.code, contains('class MetaData'));
    });

    test('derin iç içe yapı', () {
      final r = _generate('{"a": {"b": {"c": {"d": {"e": {"f": 1}}}}}}');
      expect(r.isSuccess, isTrue);
      expect(r.classCount, 6);
    });

    test('unicode anahtarlar', () {
      final r = _generate('{"şehir": "İzmit", "ülke": "TR"}');
      expect(r.code, contains('final String sehir;'));
      expect(r.code, contains('final String ulke;'));
      expect(r.code, contains("json['şehir']"));
    });

    test('üretilen kod biçimlendirilmiş (dart_style)', () {
      final r = _generate('{"a": 1}');
      // dart_style çıktısı her zaman satır sonu ile biter ve girinti 2'dir
      expect(r.code, endsWith('\n'));
      expect(r.code, contains('const Model({'));
    });
  });
}
