import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json2dart_studio/src/documents/workspace_cubit.dart';
import 'package:json2dart_studio/src/settings_storage.dart';
import 'package:json2dart_studio/src/viewer/viewer_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// _init asenkron olduğundan yüklenmeyi bekler. testWidgets'in FakeAsync
/// bölgesinde `Future.delayed` hiç tamamlanmadığı için gerçek zamanı
/// kullanmak üzere runAsync içinde beklenir.
Future<WorkspaceCubit> _ready(WidgetTester tester) async {
  final cubit = WorkspaceCubit(SettingsStorage());
  await tester.runAsync(() async {
    for (var i = 0; i < 50 && !cubit.state.loaded; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  });
  return cubit;
}

/// hintText'e göre alan bulur (widget sırasına bağlı kalmamak için).
Finder _fieldWithHint(String hint) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == hint,
);

/// Arama kutusu odaklandıktan sonra yanıp sönen imleç kare talebini hiç
/// bitirmediği için pumpAndSettle kullanılamaz; sınırlı pump ile ilerlenir.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<WorkspaceCubit> pumpViewer(WidgetTester tester, String content) async {
    final cubit = await _ready(tester);
    cubit.setActiveContent(content, immediate: true);
    await tester.pumpWidget(
      BlocProvider<WorkspaceCubit>.value(
        value: cubit,
        child: MaterialApp(home: Scaffold(body: ViewerPage(onConvert: () {}))),
      ),
    );
    await _settle(tester);
    return cubit;
  }

  /// Arama çubuğunu Ctrl+F ile açar ve sorguyu yazar (debounce dahil beklenir).
  Future<void> search(WidgetTester tester, String query) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _settle(tester);
    await tester.enterText(_fieldWithHint('Ara...'), query);
    await _settle(tester);
  }

  Future<void> replaceAll(WidgetTester tester, String target) async {
    await tester.enterText(_fieldWithHint('Değiştir...'), target);
    await _settle(tester);
    await tester.tap(find.byTooltip('Tümünü Değiştir'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Değiştir'));
    await _settle(tester);
  }

  testWidgets('ağaç modunda sondaki boşluklu sorgu da gerçekten değiştirilir', (
    tester,
  ) async {
    // Regresyon: ağaç araması sorguyu trim'lerken değiştirme ham sorguyu
    // kullanıyordu; sayaç >0 olduğu hâlde hiçbir şey değişmiyor, yine de
    // "uygulandı" deniyor ve geçmişe boş bir adım yazılıyordu.
    final cubit = await pumpViewer(tester, '{"name": "Eren", "age": 3}');
    await search(tester, 'name ');
    await replaceAll(tester, 'ad');

    expect(cubit.state.activeContent, contains('"ad"'));
    expect(cubit.state.activeContent, isNot(contains('"name"')));
    await cubit.close();
  });

  testWidgets('değişen bir şey yoksa içerik ve geçmiş korunur', (tester) async {
    final cubit = await pumpViewer(tester, '{"name": "Eren"}');
    final before = cubit.state.activeContent;
    final canUndoBefore = cubit.state.canUndo;

    // Sorgu ile hedef aynı: eşleşme var ama sonuç birebir aynı olacak.
    await search(tester, 'name');
    await replaceAll(tester, 'name');

    expect(cubit.state.activeContent, before);
    expect(cubit.state.canUndo, canUndoBefore);
    expect(find.text('Değiştirme sonucu içerik değişmedi.'), findsOneWidget);
    await cubit.close();
  });

  testWidgets('metin modunda değiştirme davranışı korunur', (tester) async {
    final cubit = await pumpViewer(tester, '{"name": "Eren"}');
    await tester.tap(find.text('Metin'));
    await _settle(tester);

    await search(tester, 'name');
    await replaceAll(tester, 'ad');

    expect(cubit.state.activeContent, contains('"ad"'));
    await cubit.close();
  });
}
