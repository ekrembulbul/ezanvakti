# Tur 7 — Alarm düzenleme hatası, matematik görevi, bildirim sayfası, kerahat uyarısı

Tarih: 2026-09-10 · Baz: `dev` = `main` = 0.20.1 · Platform: Flutter (iOS öncelikli; Android yalnız Dart katmanından etkilenir)

Kullanıcı yedi maddeyi tek turda istedi; tasarım, plan ve implementasyon inline yürütülür. Dayanak: `build/alarm-device-audit-20260910/alarmkit-timeline.txt` (yerel, ignore edilen cihaz log arşivi).

## 1. Alarm düzenleme kaydı reddediliyor ("Kurulamadı")

### Bulgu

Cihaz arşivi (`mobiletimerd`, `com.apple.AlarmKitCore`, 2026-09-10):

```
20:11:12  Scheduling alarm 323DDD1E… → Scheduled            (alarm kuruldu)
20:25:27  323DDD1E…: Not scheduling an alarm with a duplicate ID
20:25:27  Failed to schedule alarm: AlarmServiceError.Code.invalidInput   ← "Kurulamadı"
20:25:47  kayıtlar Cancelling  (kullanıcı kapattı)
20:25:49  yeni id'lerle Scheduled  (kullanıcı açtı) · 20:26:00 Firing event
```

AlarmKit `schedule(id:)` var olan id'yi **güncellemez**; aynı id ile ikinci çağrı `invalidInput` ile reddedilir. `AlarmPlanEngine.upsert` tam tersini varsayıyor: kayıt OS'ta duruyor ve konfigürasyon değiştiyse aynı UUID ile `schedule` çağırıyor. Sonuç: scheduleId değişmeyen her düzenleme (sabit haftalık alarmda her düzenleme; çıpalıda saat dışı her alan; tema vurgusu `tintHex`; sürüm yükseltmede `presentationVersion`) reddediliyor, satırda "Kurulamadı" çıkıyor ve OS'ta **eski konfigürasyon** çalmaya devam ediyor. Kapat/aç çalışıyor çünkü kapatma eski kaydı ve UUID eşlemesini siliyor, açma taze UUID üretiyor.

`maximumLimitReached` arşivde hiç yok; 8 Eylül denetimindeki limit şüphesi bu olay için doğrulanmadı.

### Karar

- `upsert`: OS'ta farklı konfigürasyonla duran kayıt için **önce yeni UUID ile** `schedule`, başarılıysa eşlemeyi yeni UUID'ye çevir, sonra eski UUID'yi `cancel`. Her anda OS'ta en az bir kayıt bulunur. Yeni kurulum patlarsa eski çalışan alarm ve eşlemesi korunur (mevcut "çalışan alarmı bozma" garantisi). Eski iptal patlarsa yeni durum korunur, journal'a `retire_replaced` / `failed` yazılır; eski UUID eşlemede kalmadığı için `reconcile` sonundaki `retire_orphan` geçişi temizliği yeniden dener.
- Test çiftinde `FakeAlarmPlatform.schedule` AlarmKit gibi davranır: OS'ta duran bir id ile ikinci `schedule` `Failure.duplicateId` fırlatır. Böylece aynı varsayımı yapan başka bir yol kalırsa suite yakalar.
- ADR 0003'e "AlarmKit id'yi yerinde güncellemez" notu eklenir.

### Kapsam dışı

Native hata kodunu satırda göstermek; limit hatasına özel yeniden deneme; 7 günlük ön dizimi kısmak.

## 2. Matematik görevi ekranı: tuş takımı

### Davranış

- `TextField` ve sistem klavyesi kalkar. Cevap, ekrandaki tuş takımından girilir.
- Tuşlar 3×4: `1 2 3 / 4 5 6 / 7 8 9 / ⌫ 0 ✓`. `⌫` son rakamı siler, uzun basınca hepsini; `✓` gönderir (son soruda "Bitir", diğerlerinde "Onayla" etiketi tuşun içinde küçük yazıyla).
- Cevap alanı en fazla 6 hane alır; boş cevap gönderilemez. Yanlış cevapta alan vurgulanır, "Yanlış, tekrar dene." çıkar, girdi temizlenir.
- Tek görünüm: scroll yok. Sıra: ilerleme noktaları · soru kartı · cevap satırı · uyarı · tuş takımı. Tuş takımı `Expanded` ile kalan alanın tamamını doldurur; satırlar ve tuşlar `Expanded` olduğundan hiçbir ekran yüksekliğinde taşmaz, büyük ekranda büyür.
- Tuş punto 26 (`kMissionKeyFontSize`), tuş arası 10, köşe `kMissionButtonRadius`. `✓` tuşu accent dolgu; rakam tuşları `surface` + `divider` çerçeve.

### Test anahtarları

`kMathKey(digit)` → `Key('math_key_$digit')`, `kMathBackspaceKey`, `kMathSubmitKey` (mevcut), `kMathAnswerKey` (cevap alanı; `kMathFieldKey` kalkar).

## 3. Matematik zorluğu: dört seviye

| Seviye | Ad | Soru | Üretim |
|---|---|---|---|
| 1 | Kolay | 1 | iki haneli ± tek haneli (`10..99` ± `2..9`); çıkarmada sonuç ≥ 1 |
| 2 | Orta | 2 | iki haneli ± iki haneli (bugünkü seviye 1) |
| 3 | Zor | 3 | iki haneli × tek haneli (bugünkü seviye 2) |
| 4 | Ekstrem | 3 | iki haneli × iki haneli (bugünkü seviye 3) |

- `MathChallenge` seviyeyi `1..4`'e kırpar. Görev süresi tipe göre sabit kalır (90 sn).
- Alarm düzenlemede görev **Matematik** iken "Zorluk" `OptionRow` (etiket + açıklama: "1 soru · toplama, çıkarma" gibi). Mevcut alarmlar seviye 1 = Kolay olarak kalır (eskiden 2 soruydu; kullanıcı Orta'yı seçebilir).
- `missionLevel` yalnız matematik için anlamlıdır: kaydederken görev Matematik değilse `missionLevel = 1` yazılır. Sallama görevi bugünkü gibi 15 sallama (seviye 1) kalır.
- Ara ekrandaki özet (`alarm_stop_screen.dart`) çıplak sayı yerine seviye adını gösterir; `missionLevelLabel(level, l10n)` yardımcı fonksiyonu `presentation/utils/alarm_labels.dart`'a eklenir.

## 4. Hatırlatıcı satırı: etiket büyük, zaman bilgisi altta

`ReminderRow` sırası: gün etiketi (küçük, accent) · ana zaman + görev ikonu (20) · **etiket** (`rowTitle` 16, `w600`, `textPrimary`, tek satır) · `detail · remaining` (`rowSubtitle` 13, `textSecondary`, tek satır). Etiket yoksa üçüncü satır çizilmez. Bildirim satırı (`notification_tile.dart`) aynı bileşeni kullandığı için kendiliğinden uyar. Dar ekran + 1.8 metin ölçeği testi (tr/ar) geçmeye devam eder.

## 5. Bildirim ekleme/düzenleme: tam sayfa ve anlaşılır "Ne zaman?"

### Neden

Alt sayfa büyüdükçe kapanmaz oldu; "Türetilmiş vakitler" çipleri seçilince üstteki vakit kendiliğinden değişiyor ve kullanıcı bunun ne olduğunu anlamıyor (çıpa vakti gizli bağ).

### Sayfa

`NotificationEditScreen` (`lib/presentation/screens/notification_edit_screen.dart`), `AlarmEditScreen` kalıbı: `Scaffold` + `SimpleAppBar` (başlık "Yeni bildirim" / "Bildirimi düzenle", sağda "Kaydet") + `AppSurface` + `ListView`. Geri tuşu vazgeçer. Sonuç `Navigator.pop(NotificationDraft)`; `RemindersScreen` sonucu `_addNotification` / `_updateNotification`'a verir. `AddNotificationBottomSheet` silinir.

`NotificationDraft` (`lib/core/models/notification_draft.dart`): `prayerType`, `derivedKind?`, `minutesBefore`, `weekdays` (boş = her gün), `label?`. `ReminderPoint` (`lib/core/models/reminder_point.dart`): `anchor: PrayerType`, `derived: DerivedTimeKind?`; eşitlik değer bazlı; `ReminderPoint.all` = 6 vakit + 5 hesaplanan nokta.

### Bölümler

1. **Ne zaman?** — `OptionRow<ReminderPoint>`; alt sayfada iki grup başlığı: "Namaz vakitleri" ve "Hesaplanan vakitler". Her seçenek: ad · bugünkü saat · kısa açıklama (`derivedHint`; vakitlerde yok). `OptionItem`'a isteğe bağlı `group` alanı eklenir; `_OptionSheet` grup değişince `SectionLabel` çizer.
2. **Açıklama kartı** — hesaplanan nokta seçiliyse: formül cümlesi ("Akşam ezanından 45 dk önce") + `derivedHint` + "Bugün 18:47". Vakit seçiliyse yalnız "Bugün 19:32". Bugünün verisi yoksa saat satırı gizlenir.
3. **Bildirim zamanı** — "Tam vaktinde" / "Öncesinde" çipleri, dakika tekerleği (mevcut bileşen, aynı sınırlar: hesaplanan nokta çıpasının `maxMinutesBefore`'u).
4. **Sıradaki bildirim** — canlı önizleme satırı: "Sıradaki: yarın 04:12" (8 gün içinde ilk uygun gün; `NotificationTimeRules.pointTime` − `minutesBefore`; tekrar günlerine uyar; bulunamazsa satır gizli).
5. **Günler** — 7 çip (mevcut).
6. **Etiket** — metin alanı (mevcut).

Doğrulama mesajları (en az 1 dk, en fazla X) aynı kalır. Tekerlek seçim bandı saydamlığı korunur.

### Metinler (tr/en/ar)

`remindersNew`, `remindersEdit`, `remindersWhen`, `remindersPrayerGroup`, `remindersDerivedGroup`, `remindersDerivedExplain` (genel açıklama: "Bu saatler ezan vakti değildir; güneş, öğle ve akşam vakitlerinden hesaplanır."), `remindersFormula*` (5 nokta için formül cümlesi), `remindersTodayAt` ("Bugün {time}"), `remindersNextPreview` ("Sıradaki: {day} {time}"). Eski `remindersDerivedSection/Hint/PrayerSection/WhichPrayer/AddTitle/AddButton/UpdateTitle` anahtarları kullanılmıyorsa ARB'den kaldırılır.

## 6. Türetilmiş vakitler (cevap)

Madde 5 ile çözülür; ayrı iş yok.

## 7. Kerahat yaklaşıyor uyarısı (ana ekran + iOS widget)

### Kural

`KerahatStatus.resolve(intervals, now)` (`features/prayer_times/domain/kerahat_status.dart`, saf):
- `active(interval)`: `interval.contains(now)`.
- `approaching(interval)`: `now < start` ve `start − now ≤ 30 dk` (`kerahatWarning = Duration(minutes: 30)`, `MissionTuning` gibi tek yerde sabit: `KerahatStatus.warning`).
- Aksi hâlde `null`. Üç aralık için de aynı kural; aralıklar çakışmaz.

Eşik 30 dk: akşam öncesi kerahat ikindinin gerçek sınırıdır; yarım saat, namazı kılmaya yetecek ama gün boyu uyarı basmayacak kadar dar.

### Ana ekran

`CountdownHero`: `approaching` durumunda alt yazının altında kerahat renginde (`kerahatText`, `kerahatSurface` zemin, `kerahatLine` çerçeve) tek satır: `wb_twilight_rounded` ikonu + "Kerahat 18:47 · 28 dk" (`kerahatSoonLine(time, remaining)`; kalan `formatCompactDuration`). Saniyelik tik zaten var; satır canlı. `active` durumu bugünkü kart olarak kalır. Ramazan sayacı ile bağımsız.

### iOS widget (small + medium)

- Snapshot v4: `days[].kerahat: [{start:"HH:mm", end:"HH:mm"}]` — Dart hesaplar (`KerahatTimes.forDay`), Swift hesaplamaz (tek kaynak). Swift `supportedSchemaVersions = [1,2,3,4]`; alan yoksa boş liste.
- Etiketler v4: `kerahat` ("Kerahat"), `kerahatActive` ("Kerahat vakti"), `kerahatUntil` ("bitiş {time}").
- `PrayerEntry.kerahat: KerahatStatus?` (`approaching(start,end)` / `active(end)`); `PrayerTimeline` kare anlarına ufuk içindeki `start − 30 dk`, `start`, `end` eklenir; `maxEntries` 14 → 24 (48 saatte 6 vakit + 9 kerahat anı × 2 gün sığsın).
- Small: sayacın altına tek satır, `palette.kerahat` renginde: yaklaşırken "Kerahat · " + `Text(timerInterval:)` (mm:ss, canlı); aktifken "Kerahat vakti · bitiş 19:32". Medium: sol sütunda aynı satır, yaklaşırken saat de yazılır: "Kerahat 18:47 · 28:13".
- `Palette.kerahat`: koyu `0xFF9292`, açık `0x8D243B` (`palettes.dart` ile birebir).
- Kilit ekranı accessory aileleri değişmez (yer yok).

### Kapsam dışı

Android widget (yok); kerahat bildirimi (zaten "Hesaplanan vakitler" ile kurulabiliyor).

## Doğrulama

- Dart: `dart format`, `flutter gen-l10n`, `flutter analyze`, `flutter test` (exit code ayrı yakalanır).
- iOS: `xcodebuild test … -only-testing:RunnerTests` (AlarmPlanEngine, PrayerTimeline, WidgetSnapshot), `flutter build ios --simulator --debug`.
- Android: native değişmedi; `flutter build apk --debug` çalıştırılmaz.
- Cihaz kabulü Ekrem'de: alarmı düzenleyip kaydet → "Kurulamadı" çıkmamalı ve yeni saatte çalmalı; matematik görevi; bildirim sayfası; widget'ta kerahat satırı.
