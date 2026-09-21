import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json2dart_studio/app.dart';
import 'package:json2dart_studio/src/common/app_themes.dart';
import 'package:json2dart_studio/src/common/text_offset.dart';
import 'package:json2dart_studio/src/documents/workspace_cubit.dart';
import 'package:json2dart_studio/src/settings_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// FakeAsync bölgesinde `Future.delayed` tamamlanmadığı için gerçek zaman.
Future<WorkspaceCubit> _ready(WidgetTester tester) async {
  final cubit = WorkspaceCubit(SettingsStorage());
  await tester.runAsync(() async {
    for (var i = 0; i < 50 && !cubit.state.loaded; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  });
  return cubit;
}

Finder _fieldWithHint(String hint) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == hint,
);

/// Odaklı TextField'ın yanıp sönen imleci pumpAndSettle'ı bitirmediği için
/// sınırlı pump.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await _settle(tester);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<WorkspaceCubit> pumpShell(WidgetTester tester) async {
    // Masaüstü kabuğu varsayılan 800x600 test yüzeyine sığmıyor.
    tester.view.physicalSize = const Size(2400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final cubit = await _ready(tester);
    await tester.pumpWidget(
      BlocProvider<WorkspaceCubit>.value(
        value: cubit,
        child: MaterialApp(
          home: AppShell(theme: AppTheme.system, onThemeChanged: (_) {}),
        ),
      ),
    );
    await _settle(tester);
    return cubit;
  }

  testWidgets('Görüntüle sekmesinde Ctrl+F, tıklamadan arama çubuğunu açar', (
    tester,
  ) async {
    // AppShell'e eklenen FocusScope(autofocus:true) odağı kabuk düğümüne
    // park edip ViewerPage'in kendi Shortcuts'ını dağıtım zincirinin dışında
    // bırakabilir; bu testin amacı tam olarak onu dışlamak.
    final cubit = await pumpShell(tester);
    await tester.tap(find.text('Görüntüle'));
    await _settle(tester);

    expect(_fieldWithHint('Ara...'), findsNothing);
    await _press(tester, LogicalKeyboardKey.keyF);
    expect(_fieldWithHint('Ara...'), findsOneWidget);
    await cubit.close();
  });

  testWidgets('editörde Ctrl+Z belge geçmişini geri alır', (tester) async {
    final cubit = await pumpShell(tester);
    final field = _fieldWithHint('JSON\'u buraya yapıştırın...');
    await tester.tap(field);
    await _settle(tester);
    await tester.enterText(field, '{"a": 1}');
    await _settle(tester);
    expect(cubit.state.activeContent, '{"a": 1}');

    await _press(tester, LogicalKeyboardKey.keyZ);
    expect(cubit.state.activeContent, isNot('{"a": 1}'));
    await cubit.close();
  });

  testWidgets('arama kutusunda Ctrl+Z belgeye dokunmaz', (tester) async {
    final cubit = await pumpShell(tester);
    await tester.tap(find.text('Görüntüle'));
    await _settle(tester);

    final editor = _fieldWithHint('JSON\'u buraya yapıştırın...');
    await tester.tap(find.text('Metin'));
    await _settle(tester);
    await tester.enterText(editor, '{"a": 1}');
    await _settle(tester);
    final content = cubit.state.activeContent;

    // Arama çubuğunu aç ve odağı oraya taşı.
    await _press(tester, LogicalKeyboardKey.keyF);
    await tester.enterText(_fieldWithHint('Ara...'), 'a');
    await _settle(tester);

    await _press(tester, LogicalKeyboardKey.keyZ);
    // Belge geçmişi tetiklenmemeli: içerik aynı kalmalı.
    expect(cubit.state.activeContent, content);
    await cubit.close();
  });

  group('codePointBoundary', () {
    test('vekil çiftinin ortasındaki offset geri hizalanır', () {
      const text = '{"a":"🎉"}'; // 🎉 = 6 (yüksek) ve 7 (düşük) kod birimi
      expect(codePointBoundary(text, 7), 6);
    });

    test('geçerli sınırlar olduğu gibi kalır', () {
      const text = '{"a":"🎉"}';
      expect(codePointBoundary(text, 6), 6);
      expect(codePointBoundary(text, 8), 8);
      expect(codePointBoundary(text, 0), 0);
      expect(codePointBoundary(text, text.length), text.length);
    });

    test('vekil içermeyen metin değişmez', () {
      expect(codePointBoundary('merhaba', 3), 3);
    });
  });
}
