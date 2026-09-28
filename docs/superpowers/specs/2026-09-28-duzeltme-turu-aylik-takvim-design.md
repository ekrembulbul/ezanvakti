# Düzeltme Turu ve Aylık Vakit Takvimi — Tasarım Spec'i

28 Eylül 2026 turunda altı madde geldi. Bir madde yalnız kontrol istiyordu,
dört madde hata düzeltmesi ya da kaldırma, bir madde yeni davranış. Takvim ve
silme ekranlarının mockup'ları gösterildi ve onaylandı (takvimde seçenek A,
silmede "ikisi de"). Mockup üreteci scratchpad'de kaldı: `tur_mock/gen.py`.

## 1. Kapsam ve kullanıcı kararları

| # | Madde | Karar |
|---|---|---|
| K1 | Kilit ekranı hizası varsayılan ortalı olmalı | Kontrol edildi, zaten ortalı; **değişiklik yok** |
| K2 | Widget'taki kerahat ikonu siyah, koyu zeminde görünmüyor | Düzelt: ikon tasarımdaki rengini alacak |
| K3 | Ana sayfadaki bildirim/alarm gösterimi | "Sıradaki" kartı **tamamen** kalkar; yeri boş kalır (kullanıcı ileride başka içerik koyacak) |
| K4 | Kaydırarak silme | Dört listeden de kalkar; silme hem düzenleme ekranındaki düğmeyle hem basılı tutma menüsüyle yapılır |
| K5 | "Yalnızca bu sefer" sonrası alarm en üste çıkıyor | Düzelt: sıralama bir sonraki gerçek çalışa göre yapılır |
| K6 | Diyanet verisiyle vakit ekranında daha fazla gün | Vakit Takvimi **ay ay** gezilir (seçenek A) |

K6'da ilk soru "ek vakitler" diye anlaşıldı. Kullanıcı düzeltti: istenen şey daha
fazla *gün*. Kıble saati ve astronomik doğuş/batış bu turun kapsamında değil (§6).

## 2. Bugünkü durum ve kod referansları

| # | Bulgu | Kaynak |
|---|---|---|
| B1 | Widget hizası varsayılanı `.center` (intent ve entry). Değişiklik 15 Eylül'de yapıldı, 0.22.0'dan beri yayında. iOS hizayı her widget örneği için ayrı sakladığından, daha önce eklenmiş widget eski değerini korur | `ios/WidgetCore/WidgetAlignment.swift:14`, `EzanVaktiWidgetIntent.swift:20`, commit `2663039` |
| B2 | Kerahat şeridinde ikon, kelime ve canlı sayaç tek bir `Text` birleşiminde. Birleşim sonrası `.foregroundStyle` view seviyesinde uygulanıyor. 19 Eylül öncesinde ikon ayrı bir `Image` olarak kendi `.foregroundStyle`'ıyla çiziliyordu | `ios/EzanVaktiWidget/Views/KerahatRibbon.swift:24-48`, commit `05e3381` |
| B3 | Ana ekranın en altında `UpcomingCard` var (sıradaki bildirim + alarm, atlama anahtarı, erteleme rozeti, "Tümü"). Veriyi `resolveNextNotification` / `resolveNextAlarm` üretiyor | `lib/presentation/screens/home_screen.dart:229-252`, `upcoming_card.dart`, `upcoming_resolver.dart:29-48,134-174` |
| B4 | `HomePage` karta ait özellikleri ve `_toggleSkip`'i yalnız bu kart için taşıyor | `lib/presentation/pages/home_page.dart:497,670-693` |
| B5 | `SwipeToDelete` (`Dismissible`) dört yerde kullanılıyor: alarmlar, bildirimler, konumlar (aktif olmayanlar), sessiz aralıklar | `swipe_to_delete.dart`; `alarms_section.dart:269-275`, `notifications_section.dart:208-214`, `location_list_screen.dart:259-263`, `quiet_windows_screen.dart:215-218` |
| B6 | Alarm satırında basılı tutma menüsü (Kopyala / Sil) zaten var; diğer satırlarda menü yok. `GroupedRow`'da `onLongPress` yok | `alarms_section.dart:237,280-305`, `grouped_list.dart:65` |
| B7 | Silme onay sormaz, "Geri al" ile geri alınır (alarm, bildirim, konum). Sessiz aralık silmesinde geri alma yok | `reminders_screen.dart:544-568,745-775`, `location_list_screen.dart:107-135`, `quiet_windows_screen.dart:97-99` |
| B8 | "Sıradaki çalışa göre" sıralamada alarmın anahtarı `alarm.isActive ? nextAlarmTimes[id] : null`. `_nextFireByAlarm` atlamayı **uygulamadan** hesaplar. Kapatılan alarm sona iner; "Yalnızca bu sefer" onu yeniden açar ve atlanacak çalış anına göre en üste koyar | `reminders_screen.dart:656-684,922-932` |
| B9 | Bildirimlerde de aynı durum: sıralama anahtarı `resolveNextOccurrencePerNotification` ile hesaplanıyor, bu fonksiyon atlamayı uygulamıyor ve kapalı ayarı dışarıda bırakıyor | `reminders_screen.dart:942-948`, `upcoming_resolver.dart:70-106` |
| B10 | `computeNextFire` atlama kümesi alabiliyor (planlayıcı onu kullanıyor) | `alarm_scheduler.dart:310-376` |
| B11 | Vakit Takvimi, `AppState.prayerTimes` penceresini (bugünden 30 gün) gösteriyor. Başlıkta "İstanbul · 30 gün" yazıyor | `calendar_screen.dart:156-170,233-242`, `prayer_times_repository.dart:35` |
| B12 | Diyanet sağlayıcısı yılın tamamını indiriyor, depo hepsini önbelleğe yazıp pencereyi kesiyor. Düzeltme (tune) okuma anında uygulanıyor | `prayer_times_repository.dart:40-104` |
| B13 | Takvim paylaşımı yalnız ekranda görünen satırları yakalıyor. İmsakiye paylaşımı ise tüm satırları ekran dışında çiziyor | `calendar_share_service.dart:107-141`, `imsakiye_share_table.dart`, `widget_image_renderer.dart` |
| B14 | İmsakiye için yükleyici + controller kalıbı hazır (nesil sayacı, eski yanıtı yok sayma) | `imsakiye_repository.dart`, `imsakiye_controller.dart` |

## 3. Tasarım

### 3.1 Widget kerahat ikonu (K2)

**Kök neden (güçlü şüphe):** 19 Eylül'de şeridi ortalamak için ikon, kelime ve
canlı sayaç tek bir `Text` birleşimine alındı. Widget, canlı sayaç içeren bu
metindeki SF Symbol'ü yazı rengine boyamıyor ve ikon varsayılan siyahla çiziliyor.
Kelime ve sayaç doğru renkte. Tek fark, ikonun metin içinde olması. Bundan önce
ikon ayrı bir görünümdü ve rengi doğruydu. Widget çizimi otomatik testle
doğrulanamadığı için neden cihazda teyit edilecek.

**Düzeltme** (`KerahatRibbon`):
- İkon yeniden ayrı bir `Image(systemName: "sun.horizon")` olur ve rengi
  açıkça verilir: yaklaşırken `palette.kerahatSoonText`, kerahatteyken beyaz.
- Kelime ayrı bir `Text` olur. Üç parça `HStack(spacing: 4)` içinde yan yana durur.
- Ortalama sorununu yaratan, sistem sayacının sunulan genişliği doldurmasıydı.
  Bu yüzden sayaç, görünmez bir `"00:00"` kalıbının genişliğine sabitlenir:
  kalıp `hidden()`, sayaç onun `overlay`'inde ve `.multilineTextAlignment(.center)`.
  Sayaç her zaman dk:sn (pencere 30 dk, aralıklar 45 dk altı), bu yüzden kalıp
  en geniş hâli karşılar.
- Yükseklik (32), yazı boyu (15), zemin, üst çizgi ve metinler aynen kalır.
  `minimumScaleFactor(0.7)` metin parçalarında kalır.

Kerahatin görünüşü değişmez. İkon, onaylı tasarımdaki rengine döner.

### 3.2 Ana sayfa "Sıradaki" kartı (K3)

- `UpcomingCard` ve dosyası silinir. Ana ekran vakit ızgarasından sonra 20 pt
  alt boşlukla biter.
- `HomeScreen` özelliklerinden şunlar kalkar: `missionSessions`, `prayerTimes`,
  `notificationSettings`, `alarms`, `alarmsSupported`, `skips`,
  `onSkipChanged`, `onSnoozedTap`, `onSeeReminders`. `HomePage` bunları
  geçirmeyi bırakır. Yalnız bu kartın kullandığı `_toggleSkip` ve kullanılmayan
  import'lar silinir.
- `upcoming_resolver.dart` içinden yalnız kartın kullandığı parçalar
  kalkar: `resolveNextNotification`, `resolveNextAlarm`, `UpcomingAlarm` ve yalnız
  testte kullanılan `resolveNextFirePerNotification`.
  Hatırlatıcılar ekranının kullandıkları kalır: `resolveNextOccurrencePerNotification`,
  `notificationKey`, `notificationOccurrence`, `UpcomingNotification`.
- Tek seferlik atlama, erteleme rozeti ve ara ekran Hatırlatıcılar ekranında
  aynen sürer. Ana ekrandaki 10 sn'lik yenileme kalır (cetvel ve ızgara onu kullanıyor).
- ARB'den yalnız kartın kullandığı anahtarlar kalkar: `upcomingTitle`, `upcomingAll`, `upcomingEmpty`.
- 2026-09-22 ertelenmiş alarm spec'inin "Sıradaki kartında rozet" kısmı
  bu turla geçersizleşir. ADR 0003'teki "ana ekranın Sıradaki kartı alarm
  listelemez" cümlesi güncellenir (§8).

### 3.3 Silme (K4)

**Kaydırma kalkar.** `SwipeToDelete` dosyası ve dört kullanımı silinir.
Listelerde yatay hareket artık yalnız sekme geçişine ait.

**Basılı tutma menüsü.** Ortak bir alt sayfa kullanılır:
`showRowActionsSheet(context, {String? title, VoidCallback? onDuplicate, required VoidCallback onDelete})`
(`lib/presentation/widgets/common/row_actions_sheet.dart`).
- Başlık satırı kaydı tanıtır. Bölüm etiketi stilindedir ve Türkçe kurala göre
  büyük harfe çevrilir. Alarmda satırın saat etiketi (ve varsa adı), bildirimde
  "Öğle · Tam vaktinde" gibi ad ve zamanlama, konumda görünen ad, sessiz aralıkta
  vakit adı ve süre özeti yazar. "Kopyala" yalnız `onDuplicate` verilince görünür.
  "Sil" hata renginde (`colorScheme.error`) ve çöp kutusu ikonuyla çizilir.
- Alarmlar: mevcut `_showRowMenu` bu sayfaya taşınır; Kopyala ve Sil aynen kalır.
- Bildirimler: `NotificationTile` basılı tutmayı `ReminderRow.onLongPress`'e
  bağlar ve menüde yalnız Sil bulunur. Tile'daki kullanılmayan `onDelete` alanı
  bu işe bağlanır.
- Konumlar: `GroupedRow`'a `onLongPress` eklenir. Menü yalnız aktif olmayan
  satırda açılır; aktif konumda basılı tutma bir şey yapmaz.
- Sessiz aralıklar: özel aralık satırlarında menü açılır. Cuma kartında menü yoktur.
- Sıralama kipindeyken (reorder) basılı tutma kapalıdır. Bugünkü alarm davranışı böyle ve diğerleri de buna uyar.

**Düzenleme ekranındaki düğme.** Ortak bir `DeleteActionButton(label, onPressed, {bool framed = true})`
kullanılır: hata renginde, ortalı yazı ve çöp kutusu ikonu, 52 pt. Formlarda
ayrı bir yüzey kartında durur (`framed`). Konum ekranında "Kaydet"in altında
kartsız çizilir (mockup'taki gibi).
- `AlarmEditScreen`, `NotificationEditScreen` ve `LocationEditScreen` isteğe
  bağlı `VoidCallback? onDelete` alır. Düğme yalnız `onDelete` verilince çizilir,
  yani yeni kayıtta görünmez.
- Alarm ve bildirim: düğme formun en altında, 28 pt boşluktan sonra.
  Konum: "Kaydet"in hemen altında. Aktif konumda liste `onDelete` vermez, bu
  yüzden düğme görünmez.
- Sessiz aralık: düzenleme panelinin (bottom sheet) en altında "Aralığı sil".
- Düğmeye basınca önce ekran/panel kapanır (`Navigator.pop`), sonra `onDelete`
  çağrılır. Böylece "… silindi · Geri al" çubuğu listenin üstünde çıkar. Düzenleme
  ekranlarının dönüş türü değişmez: kaydetme yine sonucu döndürür, silmede
  sonuç `null` olur ve çağıranın mevcut "sonuç yoksa çık" dalı buna uyar.
- Çağıranlar mevcut silme fonksiyonlarını geçirir: `_deleteAlarm`,
  `_deleteNotification`, `_deleteLocation` ve sessiz aralık için yeni `_delete`.

**Onay ve geri alma.** Onay sorulmaz; proje standardı geri almadır. Sessiz
aralık silmesine de "Sessiz aralık silindi · Geri al" eklenir ve geri alma
kaydı eski sırasına geri koyar.

**İpucu metinleri.** Listelerin altındaki kaydırma ipuçları "basılı tut" diye
değişir. Anahtar adları da değişir (§4).

### 3.4 "Sıradaki çalışa göre" sıralama (K5)

Sıralamanın anahtarı ile satırın gösterdiği örnek ayrılır:
- **Satır ve atlama arayüzü:** değişmez. Atlama uygulanmamış sıradaki örnek
  kullanılmaya devam eder ("Yalnızca bu sefer atlanacak" ve geri alma o örneğe
  uygulanıyor).
- **Sıralama anahtarı (alarm):** yeni saf fonksiyon
  `resolveEffectiveNextFirePerAlarm({alarms, prayerTimes, missionSessions, skips, now})`
  (`upcoming_resolver.dart`). Alarm ertelenmişse erteleme bitişini, değilse
  `computeNextFire(..., skips: skips)` sonucunu kullanır. Kapalı alarmın
  anahtarı yoktur (`null`, liste sonu).
- **Sıralama anahtarı (bildirim):** `resolveNextOccurrencePerNotification`
  isteğe bağlı bir `skips` parametresi alır. Parametre verilince atlanmış
  örnekler (planlayıcıyla aynı kimlikle, `notificationOccurrence`) geçilir.
  Varsayılan boş küme olduğundan mevcut çağrılar değişmez.
- Özel sıra ve ada göre sıralama etkilenmez. Liste sırası yine yalnız sunum
  tercihidir, OS planlamasına dokunmaz.

Sonuç: kapatılan alarm önce sona iner. "Yalnızca bu sefer"e basılınca alarm,
atlanan örnekten sonraki gerçek çalışının sırasına yerleşir. Günlük bir alarm
için bu, yarının çalışları arasındaki yeridir.

### 3.5 Aylık Vakit Takvimi (K6)

**Görünüm** (mockup A):
- Başlık "Vakit Takvimi". Alt satırda konum ve ay: "İstanbul · Eylül 2026".
  Ay adı `DateFormat.yMMMM(locale)` ile yazılır.
- Segment (Vakit Takvimi / İmsakiye) aynen kalır. Takvimde segmentin altında ay
  çubuğu bulunur: solda önceki ay oku, ortada "Eylül 2026", sağda sonraki ay oku.
  Oklar yüzey kutusunda durur. RTL'de yönleri çevrilir (`directional_icons`).
  Erişilebilirlik etiketleri "Önceki ay" / "Sonraki ay".
- Tablo ayın bütün günlerini gösterir. Satır düzeni, bugün vurgusu ve "BUGÜN"
  rozeti aynen kalır. Bugünden önceki günler, hangi ay açık olursa olsun, 0.5
  opaklıkla soluk görünür.
- Açılışta içinde bulunulan ay gelir ve liste bugünü gösterecek konumda açılır:
  bugünün bir üst satırı görünür. Başlangıç konumu kaydırma animasyonu olmadan
  verilir ve içerik sonuna göre kısıtlanır, böylece açılışta kayma görünmez.
  Başka aya geçince liste en üstten başlar.
- **Aralık:** geri doğru bu yılın Ocak ayına, ileri doğru gelecek yılın Aralık
  ayına kadar gidilir. Sınırda ilgili ok pasif olur.

**Veri:**
- Yeni yükleyici `CalendarMonthLoader`, `ImsakiyeLoader` kalıbındadır:
  `Future<List<PrayerTime>> Function({required Location location, required DateTime month, bool forceRefresh})`.
  `CalendarMonthRepository(prayerTimesRepository).load` bunu uygular:
  `getPrayerTimes(start: ayın 1'i, end: ayın son günü)`. Böylece önbellek,
  gerektiğinde yıllık indirme ve kullanıcı düzeltmesi, uygulamanın geri kalanıyla aynı kapıdan geçer.
  Bu ADR 0004'e uygundur: takvim ayrı hesap yapmaz, ham veriyi düzeltmeyi atlayarak okumaz.
- `CalendarMonthController` (`ChangeNotifier`), `ImsakiyeController`'ın
  kalıbını izler. Seçili ayı, günleri, yükleniyor/hata durumunu ve nesil sayacını
  tutar. Hızlı ok basışlarında yalnız son ayın yanıtı uygulanır.
  `updateSource(location, revision)` konum ya da düzeltme değişince ayı yeniden yükler.
- Ay değişirken önceki ayın tablosu ekranda kalır ve üstte ince bir ilerleme
  çizgisi görünür. İlk açılışta yükleniyor durumu gösterilir (SQLite okuması, pratikte anlık).
- Boş sonuç (sunucu o yılı henüz yayımlamamış, 404): tablo yerine "Bu ayın
  vakitleri henüz yayımlanmadı." yazılır. Hata (ağ yok, önbellek yok): mevcut
  `ErrorState` ve "Tekrar dene" gösterilir.
- Bildirim/alarm planlaması, widget snapshot'ı ve `AppState.prayerTimes`
  penceresi (30 gün) **değişmez**. Takvim yalnız okur.
- `HomePage._openCalendar` artık `prayerTimes`/`isLoading`/`errorMessage` yerine
  yükleyiciyi ve `calculationRevision`'ı geçirir. Araçlar sekmesi aynı fonksiyonu kullanır.

**Paylaş:** Görünen ayın **bütün** günleri paylaşılır. `CalendarMonthShareTable`
imsakiye paylaşım tablosunun kalıbındadır: başlık, konum, ay ve tüm satırlar
ekran dışında (`WidgetImageRenderer`) çizilir ve
`CalendarShareService.sharePng` ile paylaşılır. Açıklama `captionFor(location, ayın 1'i)`
("İstanbul · 2026/09 namaz vakitleri"). Yüklenirken ya da ay boşken paylaş düğmesi gizlenir.

## 4. Lokalizasyon

Kaynak `app_tr.arb`. İngilizce ve Arapça karşılıklar aynı turda yazılır,
ardından `flutter gen-l10n` çalıştırılır.

| Anahtar | TR | Durum |
|---|---|---|
| `alarmDeleteAction` | Alarmı sil | yeni |
| `notificationDeleteAction` | Bildirimi sil | yeni |
| `locationDeleteAction` | Konumu sil | yeni |
| `quietWindowDeleteAction` | Aralığı sil | yeni |
| `quietWindowDeleted` | Sessiz aralık silindi | yeni |
| `calendarPreviousMonth` | Önceki ay | yeni |
| `calendarNextMonth` | Sonraki ay | yeni |
| `calendarMonthUnavailable` | Bu ayın vakitleri henüz yayımlanmadı. | yeni |
| `remindersLongPressHint` | Silmek için satıra basılı tut. | `remindersSwipeToDelete` yerine |
| `alarmsLongPressHint` | Kopyalamak ya da silmek için satıra basılı tut. Silinen alarmı "Geri al" ile geri getirebilirsin. | `alarmsSwipeHint` yerine |
| `locationsLongPressHint` | Aktif olmayan konumu silmek için satıra basılı tut. | `locationsSwipeHint` yerine |
| `upcomingTitle`, `upcomingAll`, `upcomingEmpty` | — | silinir |

## 5. Dar ekran, metin ölçeği, RTL

- Ay çubuğu: ay adı ortada `FittedBox` ile küçülür, oklar sabit 34 pt kalır.
- Silme düğmesi ve menü satırları büyük metinde satır yüksekliğini büyütür, kırpmaz.
- Takvim tablosunun mevcut yatay kaydırma ve ölçek davranışı aynen kalır.
- RTL'de ay okları ve menü ikonları yön değiştirir.

## 6. Kapsam dışı

- Kilit ekranı hizası (K1): değişiklik yok. Eski eklenmiş widget elle düzenlenir.
- Ek vakitler (kıble saati, astronomik doğuş/batış, işrak, isfirar, gece
  yarısı, teheccüd): sunucu kıble ve astronomik saatleri zaten veriyor, ama
  kullanıcı bu turda gün sayısını istedi.
- Ana sayfada kartın yerine gelecek içerik (kullanıcı sonra belirleyecek).
- Android widget'ında kerahat şeridi yok; K2 yalnız iOS.
- Takvimde ek sütun, hafta görünümü ya da tarih seçici.

## 7. Riskler

- **K2 kök nedeni cihazda doğrulanmadı.** Düzeltme, ikonun doğru renkte
  göründüğü eski çizim biçimine döner. Sayaç 10 dakikanın altındayken "9:59"
  kalıptan dar kalır ve ortalamada birkaç pt kayma olabilir; bu kabul edildi.
- **Geçmiş aylar:** önbellek 90 günden eski günleri temizliyor. Bu yılın eski
  bir ayına bakınca yıl yeniden iner (tek istek, Cloudflare önbelleğinden).
  Çevrimdışıysa hata durumu görünür.
- **Silme düğmesinden sonra çağrı sırası:** önce `pop`, sonra silme. Liste
  ekranının `context`'i canlı kaldığı için "Geri al" çubuğu doğru yerde çıkar.
  Bu sıra testle korunur.
- **Sıralama:** davranış yalnız "Sıradaki çalışa göre" kipinde değişir;
  diğer kipler için mevcut testler korunur.

## 8. Test ve doğrulama

**Dart (önce başarısız test yazılır):**
- `upcoming_resolver_test`: `resolveEffectiveNextFirePerAlarm` için atlanan
  örnek geçilir, ertelenmiş alarm erteleme bitişini alır, kapalı alarmın anahtarı
  yoktur. `resolveNextOccurrencePerNotification(skips:)` atlanan örneği geçer ve
  parametresiz çağrı eskisi gibi döner. Silinen fonksiyonların testleri kalkar.
- Hatırlatıcılar ekranı widget testi: "Sıradaki çalışa göre" kipinde
  "Yalnızca bu sefer" sonrasında alarm en üstte değildir (hatanın yeniden üretimi).
- Silme: dört listede `Dismissible` yoktur. Basılı tutma menüsü açılır ve Sil
  kaydı siler, "Geri al" geri getirir (sessiz aralık dahil). Düzenleme
  ekranlarında düğme yalnız `onDelete` ile görünür; basınca ekran kapanır ve
  `onDelete` çağrılır. Aktif konumda menü de düğme de yoktur.
- Ana ekran: `UpcomingCard` ağaçta yoktur; kaydırma testi güncellenir.
- Takvim: `CalendarMonthRepository` ayın 1'i–son günü aralığını ister.
  `CalendarMonthController` hızlı geçişte eski yanıtı yok sayar, boş sonuçta
  "yayımlanmadı" durumuna geçer, hatada "Tekrar dene"ye döner. Takvim ekranında
  oklar ayı değiştirir, sınırda ok pasif olur, alt başlıkta ay yazar.
  `CalendarTable`'da geçmiş günler soluktur ve başlangıç konumu bugünü gösterir.
  `CalendarMonthShareTable` ayın bütün günlerini çizer.
- Mevcut `home_page_nav_test` içindeki "satır swipe siler" testi kaldırılır.
  Sekme kaydırmasının satır üstünde çalıştığını doğrulayan test eklenir.

**Swift:** `RunnerTests` mevcut haliyle koşar (şerit metni ve sayaç hedefi
testleri). Widget çizimi XCTest ile doğrulanamaz.

**Komutlar:** değişen Dart dosyalarına `dart format`, `flutter analyze`,
`flutter test` (ortak davranış değiştiği için tüm suite), `flutter build apk
--debug`, `FLUTTER_XCODE_ARCHS=arm64 flutter build ios --simulator --debug`,
`xcodebuild test … -only-testing:RunnerTests`.

**Cihazda (Ekrem):** widget kerahat şeridinde ikonun rengi, açık ve koyu
zeminde yaklaşırken ve kerahatteyken. Takvimde ay geçişi, açılış konumu ve ay
paylaşımı. Dört listede basılı tutma ve düzenleme ekranından silme ile "Geri al".
"Sıradaki çalışa göre" sıralamada "Yalnızca bu sefer" sonrası alarmın yeri.

## 9. Doküman

- ADR 0003 (`docs/adr/0003-platform-alarm-models.md:52`): "ana ekranın Sıradaki
  kartı alarm listelemez" ifadesi kaldırılır; ana ekranda artık alarm gösterilmiyor.
- `docs/ROADMAP.md:9`: "30 günlük takvim" yerine "aylık vakit takvimi (bu yıl ve gelecek yıl)".
- CHANGELOG sürüm çıkarken ayrı `docs: X.Y.Z sürüm notları` commit'iyle yazılır.
