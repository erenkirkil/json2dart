import 'dart:convert';

import 'package:dart_style/dart_style.dart';

import '../common/json_error.dart';
import 'dart_emitter.dart';
import 'generator_settings.dart';
import 'json_shape.dart';

export 'generator_settings.dart';

/// Üretim sonucu: ya kod ya da kullanıcıya gösterilecek hata.
class GenerationResult {
  const GenerationResult.success(this.code, {required this.classCount})
    : error = null;

  const GenerationResult.failure(this.error) : code = '', classCount = 0;

  final String code;
  final String? error;
  final int classCount;

  bool get isSuccess => error == null;
}

/// JSON kaynağından Dart model kodu üretir.
class JsonToDartGenerator {
  const JsonToDartGenerator();

  GenerationResult generate(String jsonSource, GeneratorSettings settings) {
    final source = jsonSource.trim();
    if (source.isEmpty) {
      return const GenerationResult.failure(
        'Sol paneldeki alana bir JSON yapıştırın.',
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      return GenerationResult.failure(describeJsonError(e, source));
    }

    try {
      final shapes = ShapeBuilder(settings).build(decoded);
      final rawCode = DartEmitter(settings).emit(shapes);
      return GenerationResult.success(
        _format(rawCode),
        classCount: shapes.orderedShapes.length,
      );
    } catch (e) {
      return GenerationResult.failure('Kod üretilirken hata oluştu: $e');
    }
  }

  String _format(String code) {
    try {
      final formatter = DartFormatter(
        languageVersion: DartFormatter.latestLanguageVersion,
      );
      return formatter.format(code);
    } catch (_) {
      // Biçimlendirici hata verirse ham çıktı yine de kullanılabilir olsun.
      return code;
    }
  }
}
