# JSON2Dart Studio

Tamamen **yerel** çalışan JSON → Dart model üretici ve JSON görüntüleyici/biçimlendirici.
Verileriniz asla internete gönderilmez. Windows ve macOS masaüstünde (ayrıca web ve
mobilde) çalışır.

## Özellikler

### Çalışma alanı
- **Çok belgeli sekmeler**: birden fazla JSON'la aynı anda çalış. Her sekme ayrı belge.
- **Yerel kayıt**: tüm belgeler otomatik olarak diske (shared_preferences) yazılır;
  uygulamayı kapatıp açınca aynı yerden devam edersin — internet yok.
- Soldaki **Kayıtlar** paneli: tüm belgelere erişim, yeniden adlandırma, silme.
- **Temalar**: Sistem · Açık · Koyu · Okyanus (mavi) · Gece Mavisi.

### Dönüştür (JSON → Dart)
- JSON'dan tip çıkarımı: int/double/bool/String/DateTime, listeler, `Map<String, T>`,
  iç içe nesneler.
- **Üretim tarzları**: `json_serializable` (varsayılan) · `freezed` · Saf Dart.
- **Null durumu**: Akıllı (JSON'dan çıkarır, non-null alanları `required` yapar) ·
  Hepsi nullable/opsiyonel · Hepsi non-null/required. **Null safety her zaman açıktır.**
- Aç/kapa ayarlar: `final` alanlar, `copyWith`, **Equatable** (cubit/bloc state için
  ideal), `fromRawJson/toRawJson`, `fromMap/toMap` isimlendirmesi, Hive anotasyonları,
  tarih algılama, `Map` algılama, benzer sınıfları birleştirme, sadece tipler.
- **build_runner komutu**: hedef dosya yolunu gir, tek tıkla yalnızca bu modeli üreten
  (`--build-filter`), diğer `.g.dart` dosyalarını silmeyen/yeniden üretmeyen komutu
  kopyala (aşağıya bak).
- Satır numaralı editör: geçersiz JSON'da hatalı satır kırmızı vurgulanır.
- Sözdizimi renklendirmeli çıktı + tek tıkla kopyalama.

### Görüntüle (JSON Viewer & Format)
- Genişletilebilir/daraltılabilir ağaç görünümü, seçili düğüm detay paneli.
- Satır numaralı metin modu; geçersiz JSON'da hata satırı hem metinde hem panelde.
- Biçimlendir (girintile) · Boşlukları sil (minify) · Yapıştır · Temizle.
- Metin ve Ağaç modları arası geçiş. Ağaçtan → dönüştürücüye tek tıkla aktarım.

## Sürüm yönetimi (FVM)

Bu proje **FVM** ile belirli bir Flutter sürümüne sabitlenmiştir — `.fvmrc`:
**Flutter 3.44.4 / Dart 3.12.2**. Böylece makinendeki global Flutter'a ve diğer
projelerine dokunmadan bu projede en güncel sürüm kullanılır. Komutları `flutter`
yerine **`fvm flutter`** ile çalıştır.

```bash
# FVM kurulu değilse: dart pub global activate fvm
fvm install            # .fvmrc'deki sürümü (3.44.4) indirir
fvm flutter pub get
```

> IDE'de: VS Code otomatik ayarlanır (`.vscode/settings.json` → `.fvm/versions/3.44.4`).
> Android Studio'da Settings → Languages & Frameworks → Flutter → Flutter SDK path'i
> proje kökündeki `.fvm/versions/3.44.4` (mutlak yol) olarak ayarla.

## Çalıştırma

```bash
# Masaüstü
fvm flutter run -d windows      # Windows
fvm flutter run -d macos        # macOS

# Web (isteğe bağlı)
fvm flutter run -d chrome
```

## Dağıtılabilir sürüm (release)

```bash
fvm flutter build windows   # build/windows/x64/runner/Release/json2dart_studio.exe
fvm flutter build macos     # build/macos/Build/Products/Release/json2dart_studio.app
```

> macOS'ta ilk derleme için Xcode ve CocoaPods gerekir. Windows için Visual Studio
> (C++ masaüstü iş yükü) yeterlidir.

## Komut satırı aracı (isteğe bağlı)

UI olmadan, boru hattı içinde de üretebilirsiniz:

```bash
fvm dart run tool/generate.dart tool/samples/transit.json --root=RoutePlan --style=freezed
```

Bayraklar: `--root=` `--style=manual|jsonSerializable|freezed`
`--nullability=smart|allNullable|nonNullable` `--types-only` `--no-final`
`--no-copywith` `--no-equatable` `--raw-json` `--map-names` `--no-detect-dates`
`--no-detect-maps` `--no-merge` `--hive` `--part=`

## Kod üretimi akışı (json_serializable / freezed)

1. Ayarlar panelinde **"Modelin yapıştırılacağı dosya yolu"**nu gir
   (ör. `lib/data/models/user_model.dart`). `part` yönergesi bu ada göre üretilir.
2. Üretilen Dart kodunu kopyalayıp o dosyaya yapıştır.
3. Ayarlardaki **"Komutu kopyala"** ile build_runner komutunu al ve çalıştır:
   ```bash
   dart run build_runner build --build-filter="lib/data/models/user_model.g.dart"
   ```
   `--build-filter` yalnızca **bu** dosyanın çıktısını üretir; diğer klasörlerdeki
   önceden üretilmiş `.g.dart`/`.freezed.dart` dosyaları **ne silinir ne de yeniden
   üretilir** (`--delete-conflicting-outputs` kullanılmaz). freezed'de iki filtre
   üretilir (`.freezed.dart` + `.g.dart`).

## `@JsonSerializable(explicitToJson: true)`

`explicitToJson`, iç içe model alanlarının `toJson()` içinde `instance.x.toJson()`
olarak (saf `Map`) üretilmesini sağlar; `false` olsaydı ham nesne gömülürdü ve
`toJson()` çıktısını doğrudan `Map` bekleyen yerlere (Firestore vb.) verince çalışma
zamanında hata alırdın. json_serializable tarzında her sınıfa varsayılan eklenir.
**freezed**'de sınıfa eklenemez (build_runner'ı kırar) — orada `build.yaml`'dan verilir;
üretilen freezed kodunun başındaki yorum bunu hatırlatır:
```yaml
targets:
  $default:
    builders:
      json_serializable:
        options:
          explicit_to_json: true
```

## Mimari

- `lib/src/generator/` — UI'dan bağımsız saf Dart üretim motoru
  (`json_shape.dart` şekil çıkarımı, `dart_emitter.dart` kod üretimi,
  `name_utils.dart` ad dönüşümü). `test/generator_test.dart`.
- `lib/src/documents/` — `WorkspaceCubit` (çok belgeli sekmeler + yerel kayıt),
  belge paneli ve sekme şeridi. `test/workspace_cubit_test.dart`.
- `lib/src/converter/` ve `lib/src/viewer/` — dönüştürücü ve görüntüleyici ekranları
  (tek paylaşılan **WorkspaceCubit**, flutter_bloc).
- `lib/src/common/` — satır numaralı editör, tema paletleri, kod/JSON renklendirme.
- `lib/src/settings_storage.dart` — ayar/belge/tema kalıcılığı (shared_preferences).
