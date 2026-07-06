// Komut satırından üretici motorunu çalıştıran test aracı.
//
// Kullanım:
//   dart run tool/generate.dart <json-dosyası> [seçenekler]
//
// Seçenekler:
//   --root=<ad>           Kök sınıf adı (varsayılan: Model)
//   --style=<tarz>        manual | jsonSerializable | freezed
//   --nullability=<mod>   smart | allNullable | nonNullable
//   --types-only          Sadece tipler
//   --no-final            final alanları kapat
//   --no-copywith         copyWith kapat
//   --no-equatable        Equatable kapat
//   --raw-json            fromRawJson/toRawJson üret
//   --map-names           fromMap/toMap isimlendirmesi
//   --no-detect-dates     Tarih algılamayı kapat
//   --no-detect-maps      Map algılamayı kapat
//   --no-merge            Benzer sınıf birleştirmeyi kapat
//   --hive                Hive anotasyonları üret
//   --part=<ad>           part dosya adı
import 'dart:io';

import 'package:json2dart_studio/src/generator/json_to_dart_generator.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Kullanım: dart run tool/generate.dart '
      '<json-dosyası> [seçenekler]',
    );
    exit(64);
  }

  final file = File(args.first);
  if (!file.existsSync()) {
    stderr.writeln('Dosya bulunamadı: ${args.first}');
    exit(66);
  }
  final source = file.readAsStringSync();

  GeneratorSettings settings;
  try {
    settings = _parseArgs(args.skip(1));
  } on ArgumentError catch (e) {
    stderr.writeln('Hata: ${e.message}');
    exit(64);
  }

  final result = const JsonToDartGenerator().generate(source, settings);
  if (!result.isSuccess) {
    stderr.writeln('HATA: ${result.error}');
    exit(1);
  }
  stdout.write(result.code);
}

/// `--prefix=` biçimindeki bir bayrağın değerini döndürür; eşleşmezse null.
/// substring indeksinin önek uzunluğuyla otomatik eşleşmesini sağlar.
String? _valueOf(String arg, String prefix) =>
    arg.startsWith(prefix) ? arg.substring(prefix.length) : null;

/// [T] enum'ının ada göre değerini güvenle çözer; geçersizse yol gösterici
/// bir [ArgumentError] fırlatır.
T _enumByName<T extends Enum>(List<T> values, String name, String flag) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  throw ArgumentError(
    'Geçersiz $flag değeri: "$name". Geçerli: '
    '${values.map((e) => e.name).join(', ')}',
  );
}

/// CLI argümanlarını ayrıştırır. Geçersiz bayrak/değerde [ArgumentError].
GeneratorSettings _parseArgs(Iterable<String> args) {
  var settings = const GeneratorSettings();
  for (final arg in args) {
    final root = _valueOf(arg, '--root=');
    if (root != null) {
      settings = settings.copyWithSettings(rootClassName: root);
      continue;
    }
    final style = _valueOf(arg, '--style=');
    if (style != null) {
      settings = settings.copyWithSettings(
        style: _enumByName(SerializerStyle.values, style, '--style'),
      );
      continue;
    }
    final nullability = _valueOf(arg, '--nullability=');
    if (nullability != null) {
      settings = settings.copyWithSettings(
        nullability: _enumByName(
          NullabilityMode.values,
          nullability,
          '--nullability',
        ),
      );
      continue;
    }
    final part = _valueOf(arg, '--part=');
    if (part != null) {
      settings = settings.copyWithSettings(partName: part);
      continue;
    }
    settings = switch (arg) {
      '--types-only' => settings.copyWithSettings(typesOnly: true),
      '--no-final' => settings.copyWithSettings(finalFields: false),
      '--no-copywith' => settings.copyWithSettings(copyWith: false),
      '--no-equatable' => settings.copyWithSettings(equatable: false),
      '--raw-json' => settings.copyWithSettings(rawJsonHelpers: true),
      '--map-names' => settings.copyWithSettings(useMapMethodNames: true),
      '--no-detect-dates' => settings.copyWithSettings(detectDates: false),
      '--no-detect-maps' => settings.copyWithSettings(detectMaps: false),
      '--no-merge' => settings.copyWithSettings(mergeSimilarClasses: false),
      '--hive' => settings.copyWithSettings(hiveAnnotations: true),
      _ => throw ArgumentError('Bilinmeyen seçenek: $arg'),
    };
  }
  return settings;
}
