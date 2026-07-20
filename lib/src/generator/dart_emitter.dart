import 'generator_settings.dart';
import 'json_shape.dart';
import 'name_utils.dart';

/// Emit sırasında kullanılan, Dart adı çözülmüş alan.
class _EmitField {
  _EmitField({
    required this.jsonKey,
    required this.dartName,
    required this.type,
    required this.nullable,
  });

  final String jsonKey;
  final String dartName;
  final JsonType type;

  /// Ayarlardaki null modu uygulandıktan sonraki durum.
  final bool nullable;

  bool get isDynamic => type.kind == JsonKind.dynamicType;

  /// Constructor'da `required` olmalı mı?
  bool get isRequired => !nullable && !isDynamic;
}

/// Çıkarılmış şekillerden Dart kaynak kodu üretir.
class DartEmitter {
  DartEmitter(this.settings);

  final GeneratorSettings settings;

  String emit(ShapeResult result) {
    final sb = StringBuffer();

    _writeImports(sb, result);
    _writeRootListHelpers(sb, result);

    if (result.orderedShapes.isEmpty) {
      sb.writeln(
        '// JSON kökünde bir nesne bulunamadı; '
        'üretilecek sınıf yok.',
      );
      sb.writeln('// Çıkarılan kök tipi: ${_typeName(result.rootType, false)}');
      return sb.toString();
    }

    var hiveTypeId = 0;
    for (final shape in result.orderedShapes) {
      switch (settings.effectiveStyle) {
        case SerializerStyle.freezed:
          _writeFreezedClass(sb, shape);
        case SerializerStyle.manual:
        case SerializerStyle.jsonSerializable:
          _writeClass(sb, shape, hiveTypeId);
      }
      hiveTypeId++;
      sb.writeln();
    }
    return sb.toString();
  }

  // ---------------------------------------------------------------- imports

  String get _partFileName {
    // part yönergesi, modelin yapıştırılacağı dosyayla aynı ada sahip olmalı;
    // bu yüzden hedef yolun temel adını kullanırız (partName açık geçersiz kılar).
    // Hedef yol varsayılanda kalmış ama kök sınıf özelleştirilmişse (ör. CLI
    // kullanımı) kök addan türetiriz.
    var name = settings.partName.trim();
    if (name.isEmpty) {
      final base = settings.targetBaseName;
      name = (base == 'model' && settings.rootClassName.trim().isNotEmpty)
          ? toSnakeCase(settings.rootClassName)
          : base;
    }
    name = name
        .replaceAll(RegExp(r'\.freezed\.dart$'), '')
        .replaceAll(RegExp(r'\.g\.dart$'), '')
        .replaceAll(RegExp(r'\.dart$'), '');
    return name;
  }

  void _writeImports(StringBuffer sb, ShapeResult result) {
    final hasClasses = result.orderedShapes.isNotEmpty;
    final imports = <String>[];
    final parts = <String>[];

    if (hasClasses) {
      // Tarza göre değişmeyen ortak import'lar (freezed hariç).
      if (settings.effectiveStyle != SerializerStyle.freezed) {
        if (settings.effectiveRawJson) imports.add("import 'dart:convert';");
        if (settings.effectiveEquatable) {
          imports.add("import 'package:equatable/equatable.dart';");
        }
        if (settings.effectiveHive) {
          imports.add("import 'package:hive/hive.dart';");
        }
      }
      // Tarza özgü import/part farkları.
      switch (settings.effectiveStyle) {
        case SerializerStyle.manual:
          if (settings.effectiveHive) {
            parts.add("part '$_partFileName.g.dart';");
          }
        case SerializerStyle.jsonSerializable:
          imports.add("import 'package:json_annotation/json_annotation.dart';");
          parts.add("part '$_partFileName.g.dart';");
        case SerializerStyle.freezed:
          imports.add(
            "import 'package:freezed_annotation/freezed_annotation.dart';",
          );
          parts.add("part '$_partFileName.freezed.dart';");
          parts.add("part '$_partFileName.g.dart';");
      }
    }

    if (imports.isNotEmpty) {
      imports.forEach(sb.writeln);
      sb.writeln();
    }
    if (parts.isNotEmpty) {
      parts.forEach(sb.writeln);
      sb.writeln();
    }

    // freezed'de iç içe nesneler için explicitToJson yalnızca build.yaml
    // üzerinden ayarlanabilir (sınıfa @JsonSerializable eklenemez).
    // İç içe nesne varsa kullanıcıyı bilgilendir.
    if (settings.isFreezed &&
        result.orderedShapes.any(
          (s) => s.fields.values.any((f) => _hasNestedObject(f.type)),
        )) {
      sb.writeln(
        '// NOT: toJson() çıktısının iç içe nesnelerde de saf Map '
        'olması için',
      );
      sb.writeln('// build.yaml dosyanıza şunu ekleyin:');
      sb.writeln('//   targets:');
      sb.writeln('//     \$default:');
      sb.writeln('//       builders:');
      sb.writeln('//         json_serializable:');
      sb.writeln('//           options:');
      sb.writeln('//             explicit_to_json: true');
      sb.writeln();
    }
  }

  void _writeRootListHelpers(StringBuffer sb, ShapeResult result) {
    final root = result.rootType;
    if (root.kind != JsonKind.listType) return;
    final element = root.element!;
    if (element.kind != JsonKind.objectType) return;

    final className = element.shape!.canon.name;
    final varName = toCamelCase(className);

    if (settings.effectiveRawJson &&
        settings.effectiveStyle != SerializerStyle.freezed) {
      sb.writeln('List<$className> ${varName}ListFromRawJson(String str) =>');
      sb.writeln('    (json.decode(str) as List<dynamic>)');
      sb.writeln(
        '        .map((e) => $className.${settings.fromMethodName}('
        'e as Map<String, dynamic>))',
      );
      sb.writeln('        .toList();');
      sb.writeln();
      sb.writeln('String ${varName}ListToRawJson(List<$className> data) =>');
      sb.writeln(
        '    json.encode(data.map((e) => '
        'e.${settings.toMethodName}()).toList());',
      );
      sb.writeln();
    } else {
      sb.writeln('// Kök JSON bir liste. Örnek kullanım:');
      sb.writeln('//   final items = (jsonDecode(source) as List<dynamic>)');
      sb.writeln(
        '//       .map((e) => $className.${settings.fromMethodName}('
        'e as Map<String, dynamic>))',
      );
      sb.writeln('//       .toList();');
      sb.writeln();
    }
  }

  // ------------------------------------------------------------ tip adları

  bool _fieldNullable(JsonType t) {
    if (t.kind == JsonKind.dynamicType) return false;
    return switch (settings.nullability) {
      // Değerde null görülen VEYA bazı örneklerde eksik olan alanlar nullable.
      NullabilityMode.smart => t.nullable,
      NullabilityMode.allNullable => true,
      // Yalnızca veride gerçekten null görülen alanlar nullable kalır; aksi
      // halde `json['x'] as String` çalışma anında null'da patlar. Sırf bazı
      // örneklerde EKSİK olan (ama null görülmeyen) alanlar required non-null
      // yapılır — modun smart'tan farkı budur.
      NullabilityMode.nonNullable => t.sawNull,
    };
  }

  /// Liste elemanı / map değeri null durumu her zaman veriden gelir.
  bool _elementNullable(JsonType t) =>
      t.kind != JsonKind.dynamicType && t.nullable;

  String _typeName(JsonType t, bool nullable) {
    final base = switch (t.kind) {
      JsonKind.intType => 'int',
      JsonKind.doubleType => 'double',
      JsonKind.boolType => 'bool',
      JsonKind.stringType => 'String',
      JsonKind.dateTimeType => 'DateTime',
      JsonKind.dynamicType => 'dynamic',
      JsonKind.listType =>
        'List<${_typeName(t.element!, _elementNullable(t.element!))}>',
      JsonKind.mapType =>
        'Map<String, ${_typeName(t.element!, _elementNullable(t.element!))}>',
      JsonKind.objectType => t.shape!.canon.name,
    };
    return nullable && t.kind != JsonKind.dynamicType ? '$base?' : base;
  }

  List<_EmitField> _resolveFields(ClassShape shape) {
    final used = <String>{};
    final fields = <_EmitField>[];
    for (final f in shape.fields.values) {
      var name = toCamelCase(f.jsonKey);
      if (!used.add(name)) {
        var i = 2;
        while (!used.add('$name$i')) {
          i++;
        }
        name = '$name$i';
      }
      fields.add(
        _EmitField(
          jsonKey: f.jsonKey,
          dartName: name,
          type: f.type,
          nullable: _fieldNullable(f.type),
        ),
      );
    }
    return fields;
  }

  String _escape(String s) => s
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r')
      .replaceAll('\t', r'\t');

  // ------------------------------------------------------- fromJson ifadesi

  String _fromExpr(JsonType t, String src, bool nullable, int depth) {
    final q = nullable ? '?' : '';
    switch (t.kind) {
      case JsonKind.dynamicType:
        return src;
      case JsonKind.intType:
        return '($src as num$q)$q.toInt()';
      case JsonKind.doubleType:
        return '($src as num$q)$q.toDouble()';
      case JsonKind.boolType:
        return '$src as bool$q';
      case JsonKind.stringType:
        return '$src as String$q';
      case JsonKind.dateTimeType:
        final parse = 'DateTime.parse($src as String)';
        return nullable ? '$src == null ? null : $parse' : parse;
      case JsonKind.objectType:
        final name = t.shape!.canon.name;
        final call =
            '$name.${settings.fromMethodName}($src as Map<String, dynamic>)';
        return nullable ? '$src == null ? null : $call' : call;
      case JsonKind.listType:
        final elem = t.element!;
        if (elem.kind == JsonKind.dynamicType) {
          return '$src as List<dynamic>$q';
        }
        final v = 'e$depth';
        final inner = _fromExpr(elem, v, _elementNullable(elem), depth + 1);
        return '($src as List<dynamic>$q)$q'
            '.map(($v) => $inner).toList()';
      case JsonKind.mapType:
        final val = t.element!;
        if (val.kind == JsonKind.dynamicType) {
          return '$src as Map<String, dynamic>$q';
        }
        final k = 'k$depth';
        final v = 'v$depth';
        final inner = _fromExpr(val, v, _elementNullable(val), depth + 1);
        return '($src as Map<String, dynamic>$q)$q'
            '.map(($k, $v) => MapEntry($k, $inner))';
    }
  }

  // --------------------------------------------------------- toJson ifadesi

  bool _needsToConversion(JsonType t) => switch (t.kind) {
    JsonKind.dateTimeType || JsonKind.objectType => true,
    JsonKind.listType || JsonKind.mapType => _needsToConversion(t.element!),
    _ => false,
  };

  String _toExpr(JsonType t, String src, bool nullable, int depth) {
    final q = nullable ? '?' : '';
    switch (t.kind) {
      case JsonKind.dateTimeType:
        return '$src$q.toIso8601String()';
      case JsonKind.objectType:
        return '$src$q.${settings.toMethodName}()';
      case JsonKind.listType:
        final elem = t.element!;
        if (!_needsToConversion(elem)) return src;
        final v = 'e$depth';
        final inner = _toExpr(elem, v, _elementNullable(elem), depth + 1);
        return '$src$q.map(($v) => $inner).toList()';
      case JsonKind.mapType:
        final val = t.element!;
        if (!_needsToConversion(val)) return src;
        final k = 'k$depth';
        final v = 'v$depth';
        final inner = _toExpr(val, v, _elementNullable(val), depth + 1);
        return '$src$q.map(($k, $v) => MapEntry($k, $inner))';
      default:
        return src;
    }
  }

  // -------------------------------------------- ortak alan yardımcıları

  /// json_serializable/freezed'de alan adı JSON anahtarından farklıysa @JsonKey.
  String _jsonKeyAnnotation(_EmitField f) =>
      f.dartName != f.jsonKey ? "@JsonKey(name: '${_escape(f.jsonKey)}')" : '';

  /// Alan/parametre tipi (dynamic alanlar '?' almaz).
  String _paramType(_EmitField f) =>
      f.isDynamic ? 'dynamic' : _typeName(f.type, f.nullable);

  // -------------------------------------------- saf Dart / json_serializable

  void _writeClass(StringBuffer sb, ClassShape shape, int hiveTypeId) {
    final fields = _resolveFields(shape);
    final name = shape.name;
    final isJs = settings.isJsonSerializable;

    if (isJs) sb.writeln('@JsonSerializable(explicitToJson: true)');
    if (settings.effectiveHive) sb.writeln('@HiveType(typeId: $hiveTypeId)');
    final extendsClause = settings.effectiveEquatable
        ? ' extends Equatable'
        : '';
    sb.writeln('class $name$extendsClause {');

    _writeConstructor(sb, name, fields);
    sb.writeln();
    if (!settings.typesOnly) _writeFromJson(sb, name, fields, isJs);
    _writeFields(sb, fields, isJs);
    if (!settings.typesOnly) _writeToJson(sb, name, fields, isJs);
    if (settings.effectiveCopyWith && fields.isNotEmpty) {
      _writeCopyWith(sb, name, fields);
    }
    if (settings.effectiveEquatable) _writeProps(sb, fields);

    sb.writeln('}');
  }

  void _writeConstructor(
    StringBuffer sb,
    String name,
    List<_EmitField> fields,
  ) {
    final constKw = settings.finalFields ? 'const ' : '';
    if (fields.isEmpty) {
      sb.writeln('  $constKw$name();');
      return;
    }
    sb.writeln('  $constKw$name({');
    for (final f in fields) {
      sb.writeln('    ${f.isRequired ? 'required ' : ''}this.${f.dartName},');
    }
    sb.writeln('  });');
  }

  void _writeFromJson(
    StringBuffer sb,
    String name,
    List<_EmitField> fields,
    bool isJs,
  ) {
    if (isJs) {
      sb.writeln('  factory $name.fromJson(Map<String, dynamic> json) =>');
      sb.writeln('      _\$${name}FromJson(json);');
    } else {
      sb.writeln(
        '  factory $name.${settings.fromMethodName}'
        '(Map<String, dynamic> json) => $name(',
      );
      for (final f in fields) {
        final src = "json['${_escape(f.jsonKey)}']";
        sb.writeln(
          '    ${f.dartName}: ${_fromExpr(f.type, src, f.nullable, 0)},',
        );
      }
      sb.writeln('  );');
    }
    sb.writeln();
    if (settings.effectiveRawJson) {
      sb.writeln('  factory $name.fromRawJson(String str) =>');
      sb.writeln(
        '      $name.${settings.fromMethodName}('
        'json.decode(str) as Map<String, dynamic>);',
      );
      sb.writeln();
    }
  }

  void _writeFields(StringBuffer sb, List<_EmitField> fields, bool isJs) {
    var hiveFieldIndex = 0;
    for (final f in fields) {
      if (isJs) {
        final annotation = _jsonKeyAnnotation(f);
        if (annotation.isNotEmpty) sb.writeln('  $annotation');
      }
      if (settings.effectiveHive) sb.writeln('  @HiveField($hiveFieldIndex)');
      hiveFieldIndex++;
      final finalKw = settings.finalFields ? 'final ' : '';
      sb.writeln('  $finalKw${_paramType(f)} ${f.dartName};');
    }
    if (fields.isNotEmpty) sb.writeln();
  }

  void _writeToJson(
    StringBuffer sb,
    String name,
    List<_EmitField> fields,
    bool isJs,
  ) {
    if (isJs) {
      sb.writeln('  Map<String, dynamic> toJson() => _\$${name}ToJson(this);');
    } else {
      sb.writeln(
        '  Map<String, dynamic> ${settings.toMethodName}() => '
        '<String, dynamic>{',
      );
      for (final f in fields) {
        sb.writeln(
          "    '${_escape(f.jsonKey)}': "
          '${_toExpr(f.type, f.dartName, f.nullable, 0)},',
        );
      }
      sb.writeln('  };');
    }
    sb.writeln();
    if (settings.effectiveRawJson) {
      sb.writeln(
        '  String toRawJson() => '
        'json.encode(${settings.toMethodName}());',
      );
      sb.writeln();
    }
  }

  void _writeCopyWith(StringBuffer sb, String name, List<_EmitField> fields) {
    sb.writeln('  $name copyWith({');
    for (final f in fields) {
      // copyWith parametreleri her zaman opsiyonel/nullable.
      final paramType = f.isDynamic ? 'dynamic' : _typeName(f.type, true);
      sb.writeln('    $paramType ${f.dartName},');
    }
    sb.writeln('  }) => $name(');
    for (final f in fields) {
      sb.writeln('    ${f.dartName}: ${f.dartName} ?? this.${f.dartName},');
    }
    sb.writeln('  );');
    sb.writeln();
  }

  void _writeProps(StringBuffer sb, List<_EmitField> fields) {
    sb.writeln('  @override');
    if (fields.isEmpty) {
      sb.writeln('  List<Object?> get props => const <Object?>[];');
      return;
    }
    sb.writeln('  List<Object?> get props => <Object?>[');
    for (final f in fields) {
      sb.writeln('    ${f.dartName},');
    }
    sb.writeln('  ];');
  }

  // ----------------------------------------------------------------- freezed

  /// Bir tipin altında (iç içe) başka bir üretilmiş sınıf var mı?
  bool _hasNestedObject(JsonType t) => switch (t.kind) {
    JsonKind.objectType => true,
    JsonKind.listType || JsonKind.mapType => _hasNestedObject(t.element!),
    _ => false,
  };

  void _writeFreezedClass(StringBuffer sb, ClassShape shape) {
    final fields = _resolveFields(shape);
    final name = shape.name;

    sb.writeln('@freezed');
    sb.writeln('abstract class $name with _\$$name {');
    if (fields.isEmpty) {
      sb.writeln('  const factory $name() = _$name;');
    } else {
      sb.writeln('  const factory $name({');
      for (final f in fields) {
        final annotation = _jsonKeyAnnotation(f);
        final annPrefix = annotation.isEmpty ? '' : '$annotation ';
        sb.writeln(
          '    $annPrefix'
          '${f.isRequired ? 'required ' : ''}${_paramType(f)} ${f.dartName},',
        );
      }
      sb.writeln('  }) = _$name;');
    }
    sb.writeln();
    sb.writeln('  factory $name.fromJson(Map<String, dynamic> json) =>');
    sb.writeln('      _\$${name}FromJson(json);');
    sb.writeln('}');
  }
}
