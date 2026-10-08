# Android Widget Turu — Sabit Satır, Ana Ekran Widget'ı ve iOS Widget Yenilemesi

Tarih: 2026-10-08 · Baz: `dev` (Android turu 1 sonrası, `9e601f3`) · Platform: Android (Dart + Kotlin) ve iOS WidgetKit (SwiftUI)

Görsel taslaklar: `.superpowers/brainstorm/8967-1791456924/content/` (`sabit-satir-son-v2.html`, `widget-kucuk-son.html`, `widget-v1.html` orta boy B, `widget-orta-kerahat.html` A). Klasör yerel, repoya girmez.

## Amaç

Android'de uygulamayı açmadan sıradaki vakti ve kalan süreyi göstermek: bildirim çubuğunda (kilit ekranında da görünen) sabit bir satır ve ana ekran widget'ı. iOS widget'ları da aynı yeni tasarıma geçer. Android yol haritasının 3. parçasıdır.

## Kullanıcı kararları

| # | Konu | Karar |
|---|---|---|
| K1 | Kapsam | Android sabit satır + Android widget (küçük, orta) + iOS küçük ve orta widget yeni tasarıma. iOS kilit ekranı widget'ı değişmez |
| K2 | Sabit satır, kapalı | Solda vakit adı küçük (13) ve saati büyük (19) aynı satırda, sağda büyük canlı sayaç (30). Başlıkta "Ezan Vakti · konum" |
| K3 | Sabit satır, kerahat (kapalı) | Başlık satırı "Kerahate" + başlangıca sayaç (turuncu) / "Kerahat" + bitişe sayaç (bordo); simge ve başlık rengi döner, konum o sırada başlıktan kalkar. Android 12+ kapalı bildirimde başlık satırı çizilmediği için vakit satırının altında kerahat çipi ("Kerahate 04:12" turuncu / "Kerahat 05:51" bordo, orta widget'taki çiple aynı) görünür; kerahatte satırdaki vakit adı ve sayaç da bordoya döner (widget'la aynı kural, K6). Android 11 ve öncesinde başlık görünür, çip gösterilmez |
| K4 | Sabit satır, açık | Kerahat penceresinde simgesiz kerahat kartı (kelime, aralığın saatleri, sayaç); ana ekran cetvelinin aynısı (gündüz vurgu, gece gri, kerahat bordo, çentikler, şu an noktası ve canlı saat); altı vakit yan yana, sıradaki vurgulu, geçenler soluk |
| K5 | Sabit satır davranışı | Bildirim izni varsa açık gelir; Ayarlar'daki anahtarla kapanır. Kaydırılamaz: Android 13 ve öncesinde sabit, 14+'ta kaydırılınca hemen yeniden gösterilir |
| K6 | Küçük widget | Her kenarda 14 boşluk. Üstte "konum · tarih", ortada vakit adı (11) + saat (16) ve büyük sayaç (34), altta sabit yuva: normalde gün adı + hicri tarih (iki satır), kerahat penceresinde kerahat kartı. Kerahatte vakit adı ve sayaç bordo tona döner |
| K7 | Hizalama | Küçük widget için sola / ortaya / sağa; varsayılan ortalı. Orta boyun düzeni sabit |
| K8 | Orta widget | Üstte konum (sol) ve "gün, tarih · hicri gün ay" (sağ); vakit satırı (11/18) ve sayaç (28); cetvel; altı vakit yan yana. Kerahat penceresinde sağ üstte tarih yerine çip ("Kerahate 04:12" / "Kerahat 05:51") |
| K9 | Kerahat kuralı | Her yüzeyde uygulamayla aynı: başlangıca 30 dk kala "yaklaşıyor", aralıkta "kerahatte"; sayaç önce başlangıca, sonra bitişe. Görünüm yüzeye özgü |
| K10 | Hesap yeri | Uygulama (Dart) 7 günün değişim anlarını hesaplar; Android yalnız çizer |
| K11 | iOS | Küçük ve orta aynı yeni tasarıma geçer; alttaki kerahat şeridi kalkar (küçükte kart, ortada çip); kerahatte zemin bordoya kaymaz |

## Tasarım kararları

| # | Konu | Karar | Gerekçe |
|---|---|---|---|
| D1 | Payload | Mevcut snapshot (şema 4) **eklemeli** genişler: günlere `weekday`, `dateLabel`, `hijriShort`, `epochs` (6 vaktin epoch ms'i), `ruler` (`segments`, `marks`); köke `timeline`. `schemaVersion` 4 kalır | Eski widget eklenen alanları yok sayar; iOS sürüm kapısı değişmez (kerahatSoon emsali) |
| D2 | Zaman çizelgesi | `WidgetTimelineBuilder` (saf Dart): anlar = şimdi ∪ vakitler ∪ her kerahat için (başlangıç−30 dk, başlangıç, bitiş) ∪ gece yarıları. Her an için `next` (gün, vakit), `tomorrow`, `kerahat` (`KerahatWarning.resolve` ile; durum, başlangıç, bitiş), `phase` (`resolveDayPhase`) | ADR 0004 "widget hesap yapmaz"; kural tek yerde, testi tek yerde |
| D3 | Cetvel hesabı | `buildRulerSegments`, `dayProgress` ve tipleri sunum katmanından `lib/features/prayer_times/domain/day_ruler_math.dart`'a taşınır; ana ekran cetveli davranış değiştirmeden oradan alır | Widget kurucusu domain katmanında; sunum katmanına bağımlı olmamalı |
| D4 | Tarih metinleri | `weekday` ("Perşembe"), `dateLabel` ("8 Ekim"), `hijriShort` ("27 Rebiülahir") uygulamanın dilinde Dart'ta biçimlenir | iOS'ta tarih bugün `tr_TR`'ye zorlanıyor; uygulama dili İngilizce/Arapçayken widget Türkçe konuşuyordu |
| D5 | Saat biçimi | Saatler native tarafta epoch'tan, mevcut `ezanvakti_time_format` tercihine göre biçimlenir (iOS ile aynı anahtar) | Tercih değişince snapshot'ı yeniden yazmaya gerek kalmaz |
| D6 | Android veri kaynağı | `home_widget`'ın SharedPreferences deposu; anahtarlar iOS ile aynı (`ezanvakti_snapshot`, `ezanvakti_appearance`, `ezanvakti_time_format`) + `ezanvakti_next_prayer_notification` | Mevcut köprü; Dart yayıncı kodu iki platformda ortak |
| D7 | Yayıncı | Android'de de `HomeWidgetPublisher` kullanılır (`NoopWidgetPublisher` yalnız masaüstü/test). Yayından sonra yeni `device` kanalı yöntemi `refreshSurfaces` widget'ları ve sabit satırı tazeler | Bildirim, widget'ı olmayan kullanıcıda da güncellenmeli |
| D8 | Çizim | Klasik `RemoteViews` + XML. Sayaçlar `Chronometer` (geri sayım), cetvel üstündeki saat `TextClock`; zemin gradyanı ve cetvel native `Bitmap` olarak çizilir | Saniyesi akan sayaç ve canlı saat yalnız bu altyapıda var (Glance'te yok); dakikalık güncelleme gerekmez |
| D9 | Palet | Kotlin `WidgetPalette` = iOS `Palette.swift` değerleri (4 dilim × açık/koyu, kerahat renkleri, gradyan geometrisi). Görünüm çözümü `WidgetAppearance.swift` kurallarıyla aynı; sistem koyu modu `Configuration.uiMode`'dan | Widget'a özel açık tema durakları (iOS D33) iki platformda aynı |
| D10 | Boyut | API 31+: boyuta göre `RemoteViews` eşlemesi (genişlik < 250 dp küçük, aksi orta). API < 31: `onAppWidgetOptionsChanged` en küçük genişliğine göre | Android widget'ları kullanıcı tarafından yeniden boyutlanır |
| D11 | Hizalama ayarı | Native ayar ekranı (`WidgetConfigActivity`: üç seçenek, varsayılan ortalı), `widgetFeatures="reconfigurable|configuration_optional"`; widget başına değer SharedPreferences'ta | Android 12+ yerleştirmede ayar zorunlu değil, sonradan "Widget ayarları"yla değişir |
| D12 | Güncelleme ritmi | `SurfaceRefresher.refreshAll` tüm widget'ları ve sabit satırı birlikte çizer. Sonraki çizelge sınırına `RTC_WAKEUP` kesin alarm (izin yoksa kesin olmayan); cetvel noktası için 15 dk'da bir **uyandırmayan** (`RTC`) tekrar. Tetikleyiciler: yayın, boot/güncelleme, saat dilimi/saat değişimi (mevcut boot alıcısı), widget ekleme/boyut, sabit satırın kaydırılması | Geçişler tam zamanında; nokta yalnız ekran açıkken ilerler, pil harcamaz |
| D13 | Sabit satır | Kanal `ezan_vakti_next_prayer` (IMPORTANCE_LOW, sessiz, kilit ekranında görünür). `DecoratedCustomViewStyle` + kapalı/açık özel görünüm; başlıkta `subText` (konum ya da kerahat kelimesi), kerahat penceresinde `setUsesChronometer` + geri sayım, `setColor` turuncu/bordo. `setOngoing`, `onlyAlertOnce`; `deleteIntent` ayar açıksa yeniden gösterir; dokununca uygulama | Kapalı gövde bazı sürümlerde 48 dp; kerahat sayacı başlık satırına yerleşir |
| D14 | Ayar | `GeneralSettings.nextPrayerNotification` (bool, varsayılan true, anahtar `general_next_prayer_notification`), Android'de "Bildirim ve ses" kartında satır; değişince widget deposuna yazılır ve yüzeyler tazelenir | Mevcut ayar kalıbı (çalma süresi satırı) |
| D15 | Veri yok / eski | Snapshot yoksa widget "Vakitler için uygulamayı aç", sabit satır gösterilmez. Çizelge bittiyse widget son haliyle soluk ("Güncel değil"), sabit satır kaldırılır | iOS'taki durumlarla aynı |
| D16 | iOS | `SmallView`/`MediumView` K6/K8'e göre yeniden; `KerahatRibbon` yerine küçükte `KerahatCard`, ortada `KerahatChip`; orta boya payload `ruler`'ından çizilen `RulerView`; tarih payload'daki `weekday`/`dateLabel`/`hijriShort`'tan (yoksa mevcut `DayLabel`). Dakikalık çizelge, Always-On sayaç kuralı ve kilit ekranı aynen | Görsel tasarım iki platformda aynı; iOS çizelge mantığı (D21–D22, 2026-08-29) bozulmaz |

## Mimari

### Dart
| Birim | Yer | Sorumluluk |
|---|---|---|
| `day_ruler_math.dart` | `lib/features/prayer_times/domain/` | `RulerSegmentKind`, `RulerSegment`, `RulerRange`, `buildRulerSegments`, `dayProgress` (taşındı) |
| `WidgetTimelineBuilder` | `lib/features/home_widget/domain/widget_timeline_builder.dart` | D2; saf |
| `WidgetSnapshot*` | `widget_snapshot.dart` | Yeni alanlar (D1), `WidgetTimelineEntry`, `WidgetRuler` |
| `WidgetSnapshotBuilder` | `widget_snapshot_builder.dart` | Günlere D1/D4 alanları, köke çizelge |
| `HijriFormatter.formatHijriShort` | `lib/core/utils/hijri_formatter.dart` | "27 Rebiülahir" |
| `HomeWidgetPublisher` | `data/home_widget_publisher.dart` | Android sağlayıcı adı + `refreshSurfaces`; `publishNextPrayerNotification(bool)` |
| `WidgetPublisher` | arayüz | `publishNextPrayerNotification` eklenir |
| `DeviceSettingsService.refreshSurfaces` | `lib/core/services/` | Native yüzeyleri tazele |
| DI | `service_locator.dart` | iOS ve Android'de `HomeWidgetPublisher` |
| `GeneralSettings.nextPrayerNotification` + ayar satırı | model, `notification_prefs_section.dart`, `sqlite_storage.dart` anahtar listesi | D14 |

### Kotlin (`android/app/src/main/kotlin/com/ekrembulbul/ezanvakti/widget/`)
| Birim | Sorumluluk |
|---|---|
| `WidgetSnapshotModel.kt` | JSON → model (günler, epoch'lar, cetvel, çizelge, etiketler); bozuk alan güvenli düşer |
| `WidgetTimeline.kt` (saf) | Şimdiki giriş, sonraki sınır, bayatlık |
| `WidgetPalette.kt` (saf veri) | iOS paleti; görünüm çözümü |
| `WidgetTimeFormat.kt` | Saat biçimi tercihi |
| `RulerBitmap.kt` | Cetvel bitmap'i (parçalar, boşluklar, çentikler, nokta) |
| `BackgroundBitmap.kt` | Radyal gradyan zemin (iOS geometrisi) |
| `WidgetRenderer.kt` | Küçük/orta `RemoteViews` |
| `EzanWidgetProvider.kt` | `AppWidgetProvider`; boyut, güncelleme, silme |
| `WidgetConfigActivity.kt` | Hizalama ayarı |
| `NextPrayerNotification.kt` | Sabit satır kurma/kaldırma |
| `NextPrayerDismissReceiver.kt` | Kaydırınca yeniden göster |
| `SurfaceRefresher.kt` + `SurfaceRefreshReceiver.kt` | Hepsini çiz, sonraki sınırı ve 15 dk tekrarını kur |
| `widget_store` | `HomeWidgetPreferences` okuma, hizalama değerleri |

Kaynaklar: `res/layout/widget_small.xml`, `widget_medium.xml`, `notification_next_prayer.xml`, `notification_next_prayer_expanded.xml`, `widget_config.xml`; `res/xml/ezan_widget_info.xml`; metinler `values{,-tr,-ar}/strings.xml`. Manifest: sağlayıcı, ayar ekranı, iki alıcı. `AlarmBootReceiver` ve `DeviceChannel` yüzey tazelemeyi çağırır.

### iOS (`ios/EzanVaktiWidget/`, `ios/WidgetCore/`)
`SmallView.swift`, `MediumView.swift` yeniden; `Views/KerahatCard.swift`, `Views/KerahatChip.swift`, `Views/RulerView.swift` yeni; `KerahatRibbon.swift` silinir; `WidgetSnapshot.swift` yeni opsiyonel alanlar; `DayLabel` payload metnini tercih eder. Xcode klasör eşlemeli gruplar kullandığı için yeni dosyalar projeye kendiliğinden girer.

## Hata yönetimi
- Dart yayın hataları mevcut kuralla loglanır, kullanıcı akışını kesmez; `refreshSurfaces` hatası da öyle.
- Kotlin: bozuk ya da eksik payload widget'ı "uygulamayı aç" durumuna düşürür, çökme olmaz; tek bozuk gün/vakit yalnız kendini düşürür. Bitmap ya da bildirim hataları loglanır, diğer yüzey etkilenmez.
- Bildirim izni yoksa sabit satır gösterilmez; izin gelince sonraki tazelemede çıkar.
- Kesin alarm izni yoksa sınır alarmı kesin olmayan kurulur (geçişte birkaç dakika gecikme olabilir).

## Test
- Dart: zaman çizelgesi (vakit ve kerahat anları, yaklaşma/aktif, `tomorrow`, gece yarısı, gösterilen gün, sıralı ve tekil anlar, 7 gün sınırı); snapshot JSON (yeni alanlar, şema 4); cetvel taşıması (mevcut testler yeni yerden); `formatHijriShort`; ayar varsayılanı ve kaydı; yayıncı (Android sağlayıcı adı, bildirim anahtarı).
- Kotlin JUnit: model ayrıştırma (bozuk alanlar), şimdiki giriş/sonraki sınır/bayatlık, palet çözümü, saat biçimi, sabit satır içeriği (başlık metni, sayaç hedefi, kart görünürlüğü) saf bir sunum modelinde.
- Swift (RunnerTests): yeni payload alanlarının çözümü, `RulerView` parça geometrisi, kerahat kartı/çip metinleri.
- Emülatör (API 36): widget'ı ana ekrana ekleme, küçük/orta, hizalama ayarı, sabit satır (kapalı/açık, kerahat penceresi, kaydırınca geri gelme). iOS simülatör derlemesi ve mümkünse simülatörde widget görünümü.

## Sınırlar
- Bazı marka telefonlarda widget güncellemesi gecikebilir; iOS widget yenileme bütçesi ve Always-On davranışı gerçek cihazda doğrulanır (4. parça).
- Sabit satır Android 14+'ta tamamen kaydırılamaz yapılamıyor; kaydırınca anında geri gelmesi bu sınırın karşılığı.
- Cetvel noktası ekran kapalıyken ilerlemez; ekran açıldığında en geç 15 dk içinde (çoğunlukla hemen) güncellenir.

## Kapsam dışı
iOS kilit ekranı widget'ı; Android kilit ekranı/tablet widget'ları; widget başına konum seçimi; Android 16 "Live Updates" durum çubuğu çipi; widget'tan uygulama içi derin bağlantı (dokununca ana ekran açılır).

## Etkilenen ADR
- 0004: "Widget hesap yapmaz" Android'de zaman çizelgesiyle tam uygulanır; iOS'un kendi sıradaki vakit hesabı şimdilik sürer (not düşülür).
