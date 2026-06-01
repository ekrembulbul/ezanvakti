# Geliştirme Rehberi

## Gereksinimler

- [Flutter SDK](https://docs.flutter.dev/get-started/install) — stable kanal, Dart `^3.10.4`
- Android: Android Studio + Android SDK (min SDK 21)
- iOS (yalnızca macOS): Xcode + CocoaPods (`pod`)

`flutter doctor` ile ortamı doğrula.

## Kurulum

```bash
flutter pub get
```

iOS'ta ilk kurulumda veya bir plugin eklenip çıkarıldığında pod'ları senkronize et:

```bash
pod install --project-directory=ios
```

## Çalıştırma

Geliştirme için **terminalden `flutter run`** önerilir (hot reload, doğru ön-derleme adımları). Xcode/Android Studio'yu yalnızca imzalama, capability, asset ve native debug için aç.

```bash
flutter devices                 # bağlı cihaz/simulatör listesi
flutter run -d "iPhone 17"      # belirli cihaza çalıştır
flutter run --release           # release modu (hot reload yok)
```

iOS simulatörü açmak için:

```bash
flutter emulators --launch apple_ios_simulator
# veya
xcrun simctl list devices available | grep iPhone
xcrun simctl boot "iPhone 17 Pro" && open -a Simulator
```

> **Önemli:** iOS'ta Xcode ile açacaksan `ios/Runner.xcworkspace`'i aç, `Runner.xcodeproj`'i değil — aksi halde pod modülleri bulunamaz (`Module '...' not found`).

### iOS pod sorunları

`Module 'flutter_local_notifications' not found` gibi hatalar genelde eksik/bozuk pod kurulumudur:

```bash
flutter clean
flutter pub get
pod install --project-directory=ios
```

## Test

```bash
flutter test                                   # tüm suite
flutter test test/notifications                # bir klasör
flutter test test/notifications/notifications_test.dart   # tek dosya
flutter analyze                                # statik analiz / lint
```

Testler `test/` altında kaynak yapısını yansıtır (`prayer_times/`, `notifications/`, `location/`, `offline/`, `timezone/`, `error_handling/`, `setup/`). Dış sistemler (API, SQLite, bildirim servisi) saf Dart mock'larıyla taklit edilir — `setup_test.dart` referans mock'ları içerir.

## Kod konvansiyonları

- **Dil:** Tüm kod (dosya/değişken/sınıf/fonksiyon adları) **İngilizce**. Yalnızca kullanıcıya görünen metinler ve dokümanlar Türkçe.
- **Mimari:** Yeni iş kuralı bir feature'ın `domain/` katmanına; API/DB/platform erişimi `data/` katmanına girer. UI iş kuralı içermez.
- **Soyutlama:** Dış bağımlılıklar `core/interfaces/` arkasına alınır; üst katmanlar somut sınıfa değil arayüze bağlanır.
- **Loglama:** `print` yerine `AppLogger` kullan. Seviye doğru seçilir (rutin akış `debug`, önemli olay `info`, kurtarılabilir durum `warning`, hata `error`). Hassas veri (GPS koordinatı, kişisel veri) loglanmaz.
- **Hata yönetimi:** Hatayı sessizce yutma — logla, fırlat veya açıkça ele al.

## Bilinen yapılandırma notları

- **Uygulama kimliği tutarsızlığı:** Android `applicationId` `com.example.ezanvakti` (varsayılan), iOS bundle id `com.ekrembulbul.ezanvakti`. Yayın öncesi Android tarafı gerçek bir kimlikle hizalanmalı.
- **Sürüm:** `pubspec.yaml` → `version: 0.0.1+1`.

## Faydalı komutlar

```bash
flutter pub outdated            # eski bağımlılıkları gör
flutter pub upgrade --major-versions
dart format .                   # kod formatla
flutter build apk --release     # Android release derleme
flutter build ios --release     # iOS release derleme (imzalama Xcode'da)
```
