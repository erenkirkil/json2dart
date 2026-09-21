import 'package:flutter_test/flutter_test.dart';
import 'package:json2dart_studio/src/viewer/json_search.dart';

RegExp _pattern(String query) =>
    RegExp(RegExp.escape(query), caseSensitive: false);

void main() {
  group('normalizeTreeQuery', () {
    test('baştaki ve sondaki boşlukları atar', () {
      expect(normalizeTreeQuery('  name '), 'name');
      expect(normalizeTreeQuery('name'), 'name');
      expect(normalizeTreeQuery('   '), isEmpty);
    });

    test('sorgu içindeki boşluğu korur', () {
      expect(normalizeTreeQuery(' first name '), 'first name');
    });
  });

  group('replaceAllInJson', () {
    test('anahtar adlarını değiştirir ve sayar', () {
      final (result, changed) = replaceAllInJson(
        {'name': 'Eren', 'age': 3},
        _pattern('name'),
        'ad',
      );
      expect(result, {'ad': 'Eren', 'age': 3});
      expect(changed, 1);
    });

    test('String değerleri de değiştirir', () {
      final (result, changed) = replaceAllInJson(
        {'city': 'Istanbul', 'note': 'istanbul again'},
        _pattern('istanbul'),
        'Ankara',
      );
      expect(result, {'city': 'Ankara', 'note': 'Ankara again'});
      expect(changed, 2);
    });

    test('iç içe Map/List içinde özyinelemeli çalışır', () {
      final (result, changed) = replaceAllInJson(
        {
          'items': [
            {'title': 'apple'},
            {'title': 'banana'},
          ],
        },
        _pattern('title'),
        'ad',
      );
      expect(result, {
        'items': [
          {'ad': 'apple'},
          {'ad': 'banana'},
        ],
      });
      expect(changed, 2);
    });

    test('eşleşme yoksa sayaç 0 ve içerik birebir aynı', () {
      const input = {'name': 'Eren'};
      final (result, changed) = replaceAllInJson(input, _pattern('yok'), 'x');
      expect(changed, 0);
      expect(result, input);
    });

    test('sorgu ile hedef aynıysa değişen sayılmaz', () {
      // Bu, "Değiştirme sonucu içerik değişmedi." yolunun tetikleyicisi:
      // eşleşme var ama sonuç birebir aynı.
      final (result, changed) = replaceAllInJson(
        {'name': 'Eren'},
        _pattern('name'),
        'name',
      );
      expect(changed, 0);
      expect(result, {'name': 'Eren'});
    });

    test('sayı/bool/null değerler değiştirilmez ve sayılmaz', () {
      // Ağaç araması bunları eşleşme sayıyor; JSON tipini korumak için
      // kasıtlı olarak dokunmuyoruz, bu yüzden "değişen" de saymıyoruz.
      final (result, changed) = replaceAllInJson(
        {'a': 1, 'b': true, 'c': null},
        _pattern('1'),
        '2',
      );
      expect(changed, 0);
      expect(result, {'a': 1, 'b': true, 'c': null});
    });

    test('büyük/küçük harf duyarsız eşleşir', () {
      final (result, changed) = replaceAllInJson(
        {'Name': 'x'},
        _pattern('name'),
        'ad',
      );
      expect(result, {'ad': 'x'});
      expect(changed, 1);
    });

    test('kök seviyesindeki liste ve skaler de desteklenir', () {
      final (list, listChanged) = replaceAllInJson(
        ['aa', 'bb'],
        _pattern('a'),
        'z',
      );
      expect(list, ['zz', 'bb']);
      expect(listChanged, 1);

      final (scalar, scalarChanged) = replaceAllInJson(
        'aa',
        _pattern('a'),
        'z',
      );
      expect(scalar, 'zz');
      expect(scalarChanged, 1);
    });
  });
}
