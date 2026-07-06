import 'package:flutter_test/flutter_test.dart';
import 'package:json2dart_studio/src/documents/workspace_cubit.dart';
import 'package:json2dart_studio/src/generator/json_to_dart_generator.dart';
import 'package:json2dart_studio/src/settings_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkspaceState _state(WorkspaceCubit c) => c.state;

/// _init asenkron olduğundan yüklenmeyi bekler.
Future<WorkspaceCubit> _ready() async {
  final cubit = WorkspaceCubit(SettingsStorage());
  // loaded true olana kadar bekle
  for (var i = 0; i < 50 && !cubit.state.loaded; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  return cubit;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'ilk açılışta bir belge oluşturulur ve varsayılan tarz jsonSerializable',
    () async {
      final cubit = await _ready();
      expect(cubit.state.loaded, isTrue);
      expect(cubit.state.documents.length, 1);
      expect(cubit.state.openIds.length, 1);
      expect(cubit.state.activeId, isNotNull);
      expect(cubit.state.settings.style, SerializerStyle.jsonSerializable);
      await cubit.close();
    },
  );

  test('içerik ayarlanınca Dart kodu ve ağaç türetilir', () async {
    final cubit = await _ready();
    cubit.setActiveContent('{"user_name": "e", "age": 3}', immediate: true);
    final s = _state(cubit);
    expect(s.classCount, 1);
    expect(s.dartCode, contains('@JsonSerializable(explicitToJson: true)'));
    expect(s.genError, isNull);
    expect(s.parsed, isA<Map>());
    expect(s.jsonError, isNull);
    await cubit.close();
  });

  test('geçersiz JSON hata satırını verir, ağaç korunur', () async {
    final cubit = await _ready();
    cubit.setActiveContent('{"a": 1}', immediate: true);
    final good = cubit.state.parsed;
    cubit.setActiveContent('{"a": 1,\n  "b": }', immediate: true);
    final s = cubit.state;
    expect(s.jsonError, isNotNull);
    expect(s.jsonErrorLine, 2);
    // eski ağaç korunur
    expect(s.parsed, good);
    await cubit.close();
  });

  test('boş içerik hata göstermez', () async {
    final cubit = await _ready();
    cubit.setActiveContent('{"a": 1}', immediate: true);
    cubit.setActiveContent('   ', immediate: true);
    final s = cubit.state;
    expect(s.genError, isNull);
    expect(s.jsonError, isNull);
    expect(s.dartCode, isEmpty);
    expect(s.classCount, 0);
    await cubit.close();
  });

  test('yeni belge / sekme kapatma / silme', () async {
    final cubit = await _ready();
    final first = cubit.state.activeId!;
    cubit.newDocument(content: '{"x": 1}');
    expect(cubit.state.documents.length, 2);
    final second = cubit.state.activeId!;
    expect(second, isNot(first));

    // sekmeyi kapat: belge kalır, aktif değişir
    cubit.closeTab(second);
    expect(cubit.state.openIds.contains(second), isFalse);
    expect(cubit.state.documents.length, 2);
    expect(cubit.state.activeId, first);

    // kayıttan tekrar aç
    cubit.openDocument(second);
    expect(cubit.state.activeId, second);
    expect(cubit.state.openIds.contains(second), isTrue);

    // sil: belge tamamen gider
    cubit.deleteDocument(second);
    expect(cubit.state.documents.any((d) => d.id == second), isFalse);
    expect(cubit.state.activeId, first);
    await cubit.close();
  });

  test('ayar değişikliği kodu yeniden üretir', () async {
    final cubit = await _ready();
    cubit.setActiveContent('{"user_name": "e"}', immediate: true);
    cubit.updateSettings(
      cubit.state.settings.copyWithSettings(style: SerializerStyle.manual),
    );
    final s = cubit.state;
    expect(s.dartCode, contains('extends Equatable'));
    expect(s.dartCode, isNot(contains('@JsonSerializable')));
    await cubit.close();
  });

  test('belgeler ve ayarlar diske yazılır ve geri yüklenir', () async {
    final cubit = await _ready();
    cubit.setActiveContent('{"kept": true}', immediate: true);
    cubit.renameDocument(cubit.state.activeId!, 'Kalıcı');
    // persist debounce'unu bekle
    await Future<void>.delayed(const Duration(milliseconds: 700));
    await cubit.close();

    // Yeni cubit aynı prefs'ten yüklemeli
    final cubit2 = await _ready();
    expect(cubit2.state.documents.any((d) => d.title == 'Kalıcı'), isTrue);
    expect(
      cubit2.state.documents.any((d) => d.content == '{"kept": true}'),
      isTrue,
    );
    await cubit2.close();
  });
}
