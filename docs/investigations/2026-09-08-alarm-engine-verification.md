# Alarm motoru — düzeltme ve doğrulama

## Kapsam

[Cihaz bulguları](2026-09-08-device-alarm-audit.md) üzerinden [tasarım](../superpowers/specs/2026-09-08-alarm-engine-design.md) uygulandı. Çalışma inline yürütüldü. Sürüm numarası değiştirilmedi; fiziksel iPhone'a build kurulmadı.

- Kilitli telefonda foreground açılışı reddedildiği için çalışmayan Stop intent'i arka plan aksiyonuna dönüştürüldü. Ayrı “Görevi aç” / “Alarmı aç” aksiyonu uygulamayı açar.
- Süresi geçmiş snooze, begin sırasında temizlenir; Flutter native deadline ve sayaçları okur.
- Yeni nöbetçi kabul edilmeden eski yardımcılar kaldırılmaz. Cleanup başarısızsa kabul edilen timer ve hak sayısı korunur; tekrar deneme aynı işlemi tamamlar.
- Toplu iptal yerine istenen plan uzlaştırılır. Yakın ana alarmlar, ileri gün ve +5/+10/+15 yedeklerden önce planlanır. Ana alarmın saati kaydırılmaz. Cache kısmi geldiğinde eksik günlerin mevcut gelecek alarmları korunur; bilinen günler güncellenir.
- Silme/pasifleştirme native kökü önce kapatır; aktif yardımcılar da temizlenir. Geç kalan callback veya sıradaki eski refresh silinen alarmı diriltemez.
- Görev ekranı native olay kuyruğunu tüketmez. İki ertelenen alarm kendi etiketi, çalma zamanı ve sayaçlarını korur. Eski ekran yeni günün çalışını tamamlayamaz.
- Tek seferlik atlama asıl çalış kimliğini korur. Sabit alarmların sonraki haftalarda devam etmesi native template ile sürdürülür.
- Release logger ve yedi gün/2.048 kayıt sınırındaki native journal hata geçmişini korur. Journal etiket, QR verisi veya özel ses dosyası yolu içermez.

## Otomatik doğrulama — 8 Eylül 2026

| Kontrol | Sonuç |
|---|---|
| `flutter test --no-pub` | 1.156 geçti; Berlin saat dilimi isteyen mevcut bir test normal çalışmada atlandı |
| `TZ=Europe/Berlin flutter test --no-pub test/widgets/home/day_ruler_test.dart` | 22 geçti; atlanan DST senaryosu da çalıştı |
| `flutter analyze --no-pub` | Temiz; hata/uyarı yok |
| Değişen Dart dosyalarında `dart format --output=none --set-exit-if-changed` | Değişiklik gerektirmedi |
| `flutter gen-l10n` | TR/EN/AR üretimi tamamlandı |
| iOS `xcodebuild test`, `RunnerTests` | iPhone 17 Pro simulator, iOS 26.5: 98 geçti, 0 atlandı |
| Foundation motorunu izole çalıştıran Swift testleri | 39 geçti |
| Android `:app:testDebugUnitTest` | 25 geçti |
| `flutter build ios --simulator --debug --no-pub` | Başarılı |
| `flutter build apk --debug --no-pub` | Başarılı |

Önemli regresyon testleri: süresi geçmiş snooze; fallback kimliğinin cold start'ta korunması; yanlış/eski çalış komutu; başarısız replacement sırasında eski alarmın korunması; silme kuyruğunun ardından gelen refresh; aktif zincirin silinmesi; yeni nöbetçi/cleanup hata sırası ve idempotent retry; native snapshot'ın SQLite görev cache'inden bağımsızlığı; arka planda görev ekranı açılmaması; iki ertelemenin Türkçe/Arapça, 320 px ve 2× metin ölçeğinde ayrı gösterilmesi.

Geliştirme sırasında hata enjekte edilen RED testleri beklenen şekilde başarısız oldu ve düzeltmeden sonra geçti. İlk geniş Gradle test çağrısı bağımlı eklentinin test manifestindeki minSdk uyuşmazlığında durdu; proje testleri `:app:testDebugUnitTest` ile ayrılarak doğrulandı. Bağımlılık sürümleri değiştirilmedi.

## Doğrulamanın sınırı

Simulator'da native XCTest çalıştı. Sistem alarm düğmelerini görsel olarak kullanma denemesinde CUA zaman aşımı, `simctl io screenshot` işleminde `Timeout waiting for screen surfaces` alındı. Bu etkileşim kontrolü tamamlanmış sayılmadı.

Testler fiziksel ses başlangıcını veya kilitli gerçek iPhone'daki AppIntent yürütmesini kanıtlamaz. 0.17.0 cihaz logları teşhisin dayanağıdır; yeni motorun fiziksel kabul testi değildir. Kullanıcının telefonundaki 0.17.0 bu çalışma ile güncellenmedi.

## Yeni build ile fiziksel kabul

1. 0.17.0 kayıtlarından geçişte aktif alarm tanımları ile native ana/yardımcı kayıtların köklerini karşılaştır; silinen kopyanın native kaydı kalmamalı.
2. Yakın zamana QR görevli, ertelemesi kapalı alarm kur. Uygulama arka planda ve telefon kilitliyken ana kaydın beklenen anda çaldığını doğrula. “Durdur” görevi tamamlamamalı; “Görevi aç” kilit açıldıktan sonra doğru görevi göstermeli.
3. Ertelemesi açık iki farklı alarmı ayrı ayrı ertele. Hak ve sonraki çalma zamanı birbirine taşınmamalı. Görev bitince yalnız o çalışın yardımcıları kalkmalı; diğer alarmın ana kaydı kalmalı.
4. Ertelenmiş alarmı sil. Snooze, kısa nöbetçi ve beş dakikalık yedekler tekrar çalmamalı. Uygulamayı yeniden açıp planı yenilemek alarmı geri getirmemeli.
5. Erteleme süresi geçtikten sonra uygulamayı aç. Yeni görev deadline'ı gelecekte olmalı; geçmişe planlama hatası oluşmamalı.
6. Uygulama kapatılmışken ve birden fazla sabah boyunca zamanlama/etiket/görev akışını journal ile karşılaştır. Android'de ayrıca reboot sonrası aktif görev ve sonraki haftalık alarmı doğrula.

Bu fiziksel adımlar tamamlanana kadar gerçek cihaz güvenilirliği kesinleşmiş kabul edilmez.
