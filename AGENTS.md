# Ezan Vakti — Ortak Agent Talimatları

## Kapsam ve bakım

Bu dosya, bu repository üzerinde çalışan Codex ve Claude Code için ortak proje talimatıdır. Ortak kuralları yalnızca burada güncelle. [CLAUDE.md](CLAUDE.md), bu dosyayı `@AGENTS.md` ile import eder; kuralların ikinci bir kopyasını tutma. Claude Code'a özel bir talimat gerekirse import satırının altına ekle.

Makineye özel tercihleri ve kişisel dosya yollarını repository'ye taşıma. Kullanıcının görev için verdiği açık talimatlar bu dosyadaki varsayılanlardan önceliklidir.

## Proje bağlamı

- Flutter/Dart ile geliştirilmiş Android ve iOS uygulaması. SDK, dependency ve sürüm bilgileri için [pubspec.yaml](pubspec.yaml) ve ilgili native proje yapılandırmasını esas al.
- `lib/core/`: ortak modeller, arayüzler, tema ve altyapı.
- `lib/features/`: iş kuralları `domain/`, API/SQLite/platform erişimi `data/` altında bulunur.
- `lib/presentation/`: ekranlar, widget'lar ve UI koordinasyonu. Mevcut `ServiceLocator` ve `AppState` / `ChangeNotifier` düzenini takip et.
- `android/` ve `ios/`: native alarm, widget ve platform entegrasyonları.
- `test/` ve `integration_test/`: davranış doğrulaması; mevcut test yardımcılarından yararlan.

Ayrıntılar için [mimari](docs/ARCHITECTURE.md) ve [geliştirme rehberini](docs/DEVELOPMENT.md) incele. Belgelerle implementasyon çelişirse ilgili kodu ve yapılandırmayı doğrula; eski sürüm veya platform notlarını varsayım olarak kullanma.

## Çalışma biçimi

- Önce ilgili kodu, çağıranları ve testleri oku; yalnızca istenen kapsamı değiştir. Çok adımlı işlerde kısa bir plan çıkar.
- Türkçe ve kısa iletişim kur; teknik terimleri koru. Kod ve identifier'lar İngilizce olsun.
- Sade, tip güvenli ve mevcut mimariyle uyumlu çözümler kullan. Gereksiz dependency, soyutlama veya alakasız refactoring ekleme.
- Dış girdileri doğrula. Hataları sessizce yutma; mevcut `AppLogger` üzerinden logla, ele al veya çağırana aktar. Secret ve hassas veri loglama.
- SQLite sorgularında parametre kullan; kalıcı veri değişikliklerinde mevcut migration ve transaction kalıplarını takip et.

## UI ve lokalizasyon

- Renk ve tipografi için `lib/core/theme/` altındaki token'ları ve `AppTypography` stillerini kullan.
- Kullanıcıya görünen metinleri Dart içine sabit yazma. Kaynak çeviri dosyası `lib/l10n/app_tr.arb`; İngilizce ve Arapça karşılıkları `app_en.arb` ve `app_ar.arb` içinde güncelle.
- ARB değişikliğinden sonra `flutter gen-l10n` çalıştır. Üretilen `app_localizations*.dart` dosyalarını elle düzenleme.
- Dar ekran, uzun metin, metin ölçeği ve RTL davranışını ilgili UI değişikliğinde kontrol et.

## Alarm ve vakit doğruluğu

- Ekranda gösterilen zaman ile planlanan zaman aynı hesaplama kurallarını kullanmalı. Offset, tekrar günü, gece yarısı geçişi ve türetilmiş vakitler için UI'da ayrı hesap uydurma.
- Tek seferlik atlamalarda planlayıcının örnek kimliğini ve kaynak vakit gününü koru.
- Bildirim planlamasındaki hata alarm planlamasını engellememeli. Liste sırası gibi sunum tercihleri OS planlamasını değiştirmemeli.
- Geçici veri yükleme hatalarında geçerli cache ve mevcut kayıtları koru; konum veya hesaplama ayarı değişikliklerinde ilgili yenileme akışını takip et.
- Unit/widget testleri native alarmın gerçek cihazda zamanında çaldığını kanıtlamaz. Bu sınırı teslimde açıkça belirt.

## Doğrulama ve teslim

- Dart değişikliklerini `dart format` ile biçimlendir; `flutter analyze` ve değişiklikle ilgili testleri çalıştır. Ortak davranış değiştiğinde `flutter test` ile tüm suite'i doğrula.
- Platform entegrasyonu değiştiğinde ilgili build'i çalıştır: Android için `flutter build apk --debug`, iOS simulator için `flutter build ios --simulator --debug`.
- Yalnızca dokümantasyon değişikliklerinde içerik, dosya referansları ve `git diff --check` kontrolü yeterlidir.
- Ne değiştiğini, nedenini, doğrulama sonucunu ve test edilmeyen davranışları kısa raporla. Başarısız veya atlanan kontrolü gizleme.

## Git

- Başlangıçta `git status` kontrol et; kullanıcıya ait değişiklikleri koru.
- Kullanıcı farklı bir branch belirtmedikçe doğrulanmış işi `dev` üzerinde yerel commit'le. `dev` yoksa kullanıcıya sor; kendiliğinden oluşturma. Kullanıcı açıkça commit atılmamasını istediyse commit atma.
- Türkçe Conventional Commit mesajları kullan; farklı amaçları atomik commit'lere ayır.
- Kullanıcı açıkça istemedikçe `push`, `merge`, branch silme veya yayınlama yapma.
- Secret, yerel izin dosyası, build çıktısı ve geçici dosyaları commit'e alma.
