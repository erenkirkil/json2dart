import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json2dart_studio/src/viewer/json_tree_view.dart';

void main() {
  final root = <String, dynamic>{
    'user': {'name': 'Eren', 'city': 'Istanbul'},
    'items': [
      {'title': 'apple', 'qty': 1},
      {'title': 'banana', 'qty': 2},
    ],
    'note': 'nothing matches here',
  };

  Future<GlobalKey<JsonTreeViewState>> pump(
    WidgetTester tester,
    String query,
  ) async {
    final key = GlobalKey<JsonTreeViewState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JsonTreeView(
            key: key,
            root: root,
            revision: 1,
            searchQuery: query,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return key;
  }

  testWidgets('arama, eşleşen düğümlerin atalarını otomatik açar', (
    tester,
  ) async {
    // "name" alanı başlangıçta kapalı bir dalın (user) içinde.
    final key = await pump(tester, 'eren');
    expect(find.textContaining('name'), findsOneWidget);
    expect(find.textContaining('Eren'), findsOneWidget);
    expect(key.currentState, isNotNull);
  });

  testWidgets('değer içindeki eşleşmeler de bulunur (anahtar değil)', (
    tester,
  ) async {
    await pump(tester, 'banana');
    expect(find.textContaining('banana'), findsOneWidget);
  });

  testWidgets('eşleşme yoksa hiçbir dal zorla açılmaz', (tester) async {
    await pump(tester, 'zzz-yok');
    // "user" kapalı kaldığı için içindeki "name" görünmemeli.
    expect(find.textContaining('name'), findsNothing);
  });

  testWidgets('nextMatch/previousMatch eşleşmeler arasında döner', (
    tester,
  ) async {
    int? lastTotal;
    int? lastCurrent;
    final key = GlobalKey<JsonTreeViewState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JsonTreeView(
            key: key,
            root: root,
            revision: 1,
            searchQuery: 'qty',
            onSearchResult: (total, current) {
              lastTotal = total;
              lastCurrent = current;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(lastTotal, 2);
    expect(lastCurrent, 0);

    key.currentState!.nextMatch();
    await tester.pumpAndSettle();
    expect(lastCurrent, 1);

    // Sondan sonra başa sarmalı.
    key.currentState!.nextMatch();
    await tester.pumpAndSettle();
    expect(lastCurrent, 0);

    key.currentState!.previousMatch();
    await tester.pumpAndSettle();
    expect(lastCurrent, 1);
  });
}
