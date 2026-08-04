# Navigasyon Kabuğu — Tasarım Spec'i

Beş ekranın (Ana ekran, Takvim, Bildirimler, Alarmlar, Ayarlar) tek ve tutarlı
bir gezinme kabuğunda toplanması.

## 1. Sorun

Bugün gezinme iki ayrı mekanizmaya bölünmüş durumda:

| Hedef | Yol | Maliyet |
|---|---|---|
| Ana ekran | alt segment, sekme 0 | 0 tap |
| Alarmlar | alt segment, sekme 1 | 1 tap |
| Bildirimler | hamburger → alt menü → push | 2 tap |
| Takvim | hamburger → alt menü → push | 2 tap |
| Ayarlar | hamburger → alt menü → push | 2 tap |

Bundan dört sorun doğuyor:

1. **Asimetri.** Bildirimler ve Alarmlar kullanıcı için tek bir şeyin iki
   yüzü — "vaktinde bana haber ver". Ayrımları teknik (sessiz banner vs sesli,
   ayrı izin gerektiren alarm). Biri sekmede, diğeri menünün içinde.
2. **İki öğelik alt bar.** 52pt'lik kalıcı bir kontrol iki hedef için
   harcanıyor. Üstelik hiyerarşi uyumsuz: "Vakitler" bir ana ekran, "Alarmlar"
   bir yönetim listesi; alt bar ikisini eşit gösteriyor.
3. **Hamburger beş hedefin üçünü saklıyor.** Keşfedilebilirlik yok, "neredeyim"
   göstergesi yok, durum (izin kapalı, kaç hatırlatma açık) gösterilemiyor.
4. **İki farklı durum davranışı.** Sekmedeki ekranlar `IndexedStack` sayesinde
   durumunu koruyor, push edilenler kaybediyor.

## 2. Kapsam

**Bu turda:**
- Üç sekmelik gezinme kabuğu ve yeni alt bar bileşeni.
- Bildirimler + Alarmlar ekranlarının tek "Hatırlatıcılar" ekranında
  birleştirilmesi.
- Takvim'in push'tan sekmeye taşınması.
- Hamburger menünün kaldırılması, Ayarlar'ın doğrudan girişe bağlanması.
- §7'deki iki bayatlık hatasının düzeltilmesi ve yeniden planlamanın tek
  yerde toplanması.

**Kapsam dışı:**
- Bildirim ve alarm ekleme/düzenleme akışlarının kendisi
  (`AddNotificationBottomSheet`, `AlarmEditScreen`) — olduğu gibi kalır.
- Ayarlar, Konum ve Hesaplama ekranlarının içerikleri.
- Ana ekranın içeriği (sayaç, cetvel, vakit ızgarası, SIRADAKİ kartı).
- Sekmeler arası kaydırma (swipe) hareketi.

## 3. Alınan kararlar

| # | Konu | Karar | Gerekçe |
|---|---|---|---|
| D1 | Kabuk biçimi | **Üç sekme:** Vakitler · Takvim · Hatırlatıcılar. Ayarlar sekme değil. | Gezinme ağırlığı kullanım sıklığıyla hizalanır: ana ekran her açılışta, takvim ara sıra, hatırlatıcılar kurulumdan sonra seyrek → sekme. Ayarlar yılda birkaç kez → derinlikte. Üç öğe, alt bar için hedef genişliğinin de en rahat olduğu sayı. |
| D2 | Bildirimler + Alarmlar | **Tek ekranda birleşir**, üstte segment ile ayrılır. | İkisi tek zihinsel kategori. Segment, hamburger'dan farklı olarak görünür ve tek dokunuşluk. |
| D3 | Segment mi iki bölüm mü | **Segment.** Aynı anda yalnızca biri görünür. | Bilinçli takas: veri şekilleri (dakika-öncesi vs hafta günü) ve izin hikâyeleri farklı; yan yana koymak iki ayrı boş durumu, iki ayrı izin uyarısını ve iki sayacı aynı scroll'a yığardı. |
| D4 | Alt bar görseli | **Yeni bileşen.** İkon üstte, etiket altta, seçili `accent` + kayan 2px alt çizgi. Yatak/pill yok. | `SlidingSegment` artık yalnızca ekran içi filtre. Aksi halde Hatırlatıcılar sekmesinde iki özdeş pill üst üste gelir ve kullanıcı hangisinin "neredeyim" hangisinin "ne gösteriyorum" olduğunu ayırt edemez. |
| D5 | Ayarlar girişi | **Yalnızca Vakitler sekmesinin üst çubuğunda** gear. | Takvim ve Hatırlatıcılar başlıkları temiz kalır. Takvim'den Ayarlar 2 tap eder; Ayarlar seyrek kullanıldığı için kabul edilen maliyet. |
| D6 | Android geri tuşu | Sekme ≠ 0 → sekme 0'a döner. Sekme 0 → uygulamadan çıkar. | Yaygın davranış; sekme geçmişi biriktirmek geri tuşunu öngörülemez kılar. |
| D7 | Liste durumu | Bildirim ve alarm listeleri **yalnızca `AppState`'te** tutulur. | §7'deki iki bayatlık hatası bundan doğuyor. Sekme dünyasında listeler ana ekranla kardeş olacağı için bayatlık anında görünür hale gelirdi. |
| D8 | Yeniden planlama | Tek fonksiyonda toplanır (`rescheduleAll`). | Bugün beş yere dağılmış durumda; her biri `skips` geçirmeyi ayrı ayrı hatırlamak zorunda (bkz. §6.3 değişmez kuralı). |

## 4. Kabuk davranışı

### 4.1 Sekmeler

| # | Etiket | İkon | Widget |
|---|---|---|---|
| 0 | Vakitler | `schedule_rounded` | `HomeScreen` |
| 1 | Takvim | `calendar_month_rounded` | `CalendarScreen` |
| 2 | Hatırlatıcılar | `notifications_rounded` | `RemindersScreen` *(yeni)* |

Üçü `IndexedStack` içinde; sekme değişimi durum kaybettirmez.

### 4.2 `AppNavBar` ölçüleri

Toplam yükseklik **58** + `SafeArea` alt boşluğu. Üstte 1px `divider` saç
çizgisi.

| Katman | Ölçü |
|---|---|
| üst dolgu | 8 |
| ikon | 22 |
| boşluk | 5 |
| etiket (`tabLabel`, `height: 1.0`) | 12 |
| boşluk | 3 |
| gösterge | 2 |
| alt dolgu | 6 |

- Öğe genişliği: ekran genişliğinin 1/3'ü. Dokunma alanı `HitTestBehavior.opaque`
  ile tüm dilime yayılır.
- Seçili öğe `accent`, pasif `textTertiary`.
- Etiket ağırlığı seçilide `w700`, pasifte `w600` — `SlidingSegment` ile aynı.
- **Gösterge:** 18×2, `r1`, `accent`. Dilimler arasında `AnimatedPositioned`
  ile kayar: **220 ms `Curves.easeOutCubic`** — `SlidingSegment` ile aynı
  hareket sabiti. Biçim farklı, hareket dili ortak.
- Yatak rengi yok; alt bar `AppSurface` gradyanının üstünde durur.

### 4.3 Geri tuşu

`PopScope(canPop: _tabIndex == 0)`. Engellendiğinde `_tabIndex = 0`.

### 4.4 Üst çubuk

| Sekme | Üst çubuk |
|---|---|
| Vakitler | `HomeTopBar`: konum ▾ · sağda **gear** |
| Takvim | `_CalendarAppBar`: `Vakit Takvimi` / `Kadıköy · 30 gün` — geri oku **kalkar** |
| Hatırlatıcılar | `SimpleAppBar('Hatırlatıcılar', showBack: false, actions: [+])` |

`HomeTopBar`'daki `Icons.menu_rounded` → `Icons.settings_rounded`, `onMenuTap`
→ `onSettingsTap`. `home_menu_sheet.dart` silinir.

## 5. Hatırlatıcılar ekranı

### 5.1 Yerleşim

```
┌────────────────────────────┐
│      Hatırlatıcılar     +  │  SimpleAppBar
│ ┌──────────┬─────────────┐ │
│ │Bildirimler│  Alarmlar   │ │  SlidingSegment (52 / r26 / padding 4)
│ └──────────┴─────────────┘ │
│                            │
│ [izin uyarısı — varsa]     │
│                            │
│ 3 hatırlatma               │  SectionLabel
│ ┌────────────────────────┐ │
│ │ 🔔 Öğle                │ │
│ │    Tam vaktinde    [◉] │ │  GroupedList + SwipeToDelete
│ └────────────────────────┘ │
└────────────────────────────┘
```

Segment ölçüleri ana spec §4.4'ün "Alarm türü" satırıyla aynı (varsayılanlar).
Gövde `IndexedStack` — segment geçişi scroll konumunu kaybettirmez.

### 5.2 Ekleme düğmesi

App bar'daki `+` **seçili segmentin** tipini ekler:

| Segment | Eylem |
|---|---|
| Bildirimler | `AddNotificationBottomSheet` açılır |
| Alarmlar | `AlarmEditScreen` push edilir |

Tip sormaz; segment zaten bağlamı veriyor.

### 5.3 İzin uyarıları

Her uyarı kendi bölümünün içinde, listenin üstünde kalır:

| Segment | Uyarı | Koşul |
|---|---|---|
| Bildirimler | `PermissionWarningCard` | bildirim izni yok |
| Bildirimler | `InfoBanner` — "Tam zamanlı alarm kapalı" | izin var ama exact alarm kapalı |
| Alarmlar | `InfoBanner` — "desteklenmiyor" | iOS < 26 |
| Alarmlar | `InfoBanner` — "izin gerekiyor" | destekleniyor ama izin yok |

### 5.4 Boş durumlar

Her segmentin kendi boş durumu bugünküyle aynı kalır
(`notifications_none_rounded` / `alarm_off_rounded`).

## 6. Mimari

### 6.1 Dosya haritası

**Yeni:**
```
lib/presentation/widgets/common/app_nav_bar.dart        AppNavBar
lib/presentation/screens/reminders_screen.dart          kabuk + mutasyonlar
lib/presentation/widgets/reminders/notifications_section.dart
lib/presentation/widgets/reminders/alarms_section.dart
lib/presentation/services/reminder_rescheduler.dart     rescheduleAll
lib/presentation/utils/alarm_labels.dart                etiket yardımcıları
```

**Silinen:**
```
lib/presentation/widgets/home/home_menu_sheet.dart
lib/presentation/screens/alarms_screen.dart             → alarms_section.dart
lib/presentation/screens/notification_settings_screen.dart
                                                        → notifications_section.dart
```

**Etiket yardımcıları ayrı dosyaya çıkar.** `alarms_screen.dart`'taki
`alarmTimeLabel`, `alarmSubtitle` ve `weekdaysLabel` bugün ekranın içinde
duruyor ve dışarıdan iki yer bunları import ediyor:

```dart
// upcoming_card.dart:11 — widget, helper için bir ekranı import ediyor
import '../../screens/alarms_screen.dart' show alarmTimeLabel;
```

Bunlar `alarms_section.dart`'a değil, `prayer_name_helper.dart`'ın yanına —
`lib/presentation/utils/alarm_labels.dart`'a taşınır. Aksi halde smell yer
değiştirmiş olur: `UpcomingCard` bu kez bir section'ı import eder. Güncellenecek
import'lar: `upcoming_card.dart`, `alarms_section.dart`,
`test/widgets/screens/alarms_screen_test.dart` (dosya
`test/presentation/alarm_labels_test.dart`'a taşınır).

**Değişen:** `home_page.dart`, `home_top_bar.dart`, `calendar_screen.dart`,
`app_state.dart`.

### 6.2 Tek doğruluk kaynağı

Section'lar veri tutmaz. `AppState.notificationSettings` ve `AppState.alarms`'ı
okur, kullanıcı eylemini callback ile dışarı bildirir:

```dart
class NotificationsSection extends StatelessWidget {
  final List<NotificationSetting> settings;
  final bool hasPermission;
  final bool exactAlarmAllowed;
  final void Function(NotificationSetting) onToggle;
  final void Function(NotificationSetting) onEdit;
  final void Function(NotificationSetting) onDelete;
  // ...
}
```

Mutasyon mantığı `RemindersScreen` state'inde toplanır. Her mutasyon aynı üç
adımı yapar:

```
manager'a yaz  →  AppState'i tazele  →  rescheduleAll()
```

Bu, "+" düğmesinin kabukta ama listenin section'da olması sorununu da çözüyor:
kabuk zaten mutasyonların sahibi, section yalnızca çizim yapıyor.

İzin durumu (`hasPermission`, `exactAlarmAllowed`, alarm desteği) ekran
ömrüne bağlı olduğu için `RemindersScreen` state'inde kalır; `AppState`'e
taşınmaz. `WidgetsBindingObserver` ile `resumed`'da tazelenir — bugünkü
davranışın aynısı.

### 6.3 `rescheduleAll`

```dart
/// Bildirim ve alarm planlamasını tek yerden yeniden kurar.
Future<void> rescheduleAll({
  required Location location,
  required List<PrayerTime> prayerTimes,
  required Set<SkippedOccurrence> skips,
});
```

Bugün bu iş beş yere dağılmış: `HomePage._loadPrayerData`,
`HomePage._toggleSkip`, `HomePage._rescheduleOnResume`,
`NotificationSettingsScreen._rescheduleNotifications`, `AlarmsScreen._reschedule`.
Son ikisi `skips` parametresini hiç bilmiyor.

> **Değişmez kural — atlama dirilmez.** Her yeniden planlama güncel
> `AppState.skips` kümesini geçirmek zorundadır. Geçirilmezse, kullanıcının
> "yalnızca bu sefer" atladığı örnek, Hatırlatıcılar ekranındaki ilgisiz bir
> değişiklikten sonra sessizce geri planlanır ve çalar. Tek giriş noktası
> `skips`'i zorunlu parametre yaparak bunu derleme zamanında garantiler.

`prayerTimes` boşsa: bugünkü davranış korunur — planlama yapılamaz, bunun
yerine `cancelAllNotifications()` çağrılır ki silinen/kapatılan bildirimlerin
eski OS kopyaları tetiklenmesin.

### 6.4 Veri akışı

```
HomePage
  ├─ IndexedStack
  │   ├─ HomeScreen        (AppState'ten okur)
  │   ├─ CalendarScreen    (AppState'ten okur)
  │   └─ RemindersScreen   (AppState'ten okur, mutasyonu sahiplenir)
  └─ AppNavBar

RemindersScreen._addNotification / _toggleAlarm / _deleteAlarm / ...
  ├─ NotificationSettingsManager | AlarmsManager  → yaz
  ├─ AppState.setNotificationSettings | setAlarms → tazele
  └─ rescheduleAll(skips: appState.skips)
```

## 7. Düzeltilen hatalar

**H1 — `AppState.notificationSettings` bayatlıyor.**
`home_page.dart:361` şu koşula bağlı:

```dart
if (result == true) {
  await _reloadNotificationSettings();
}
```

`NotificationSettingsScreen` hiçbir yerde `pop(true)` yapmıyor; `SimpleAppBar`
geri oku değersiz pop ediyor. Yani `_reloadNotificationSettings()` **hiç
çalışmıyor**. Bildirim eklenip ana ekrana dönüldüğünde SIRADAKİ kartı eski
listeyi kullanıyor.

**H2 — `AppState.alarms` bayatlıyor.**
`setAlarms` yalnızca `_loadPrayerData` içinde çağrılıyor (`home_page.dart:255`).
`AlarmsScreen` alarm ekleyince/silince/kapatınca `AppState`'e hiç yazmıyor.

İkisi de D7 ile kapanıyor: liste tek yerde tutulunca bayatlayacak ikinci kopya
kalmıyor. `_reloadNotificationSettings` ve ölü `if (result == true)` dalı
`home_page.dart`'tan kalkar.

## 8. Hata ve kenar durumlar

| Durum | Davranış |
|---|---|
| `Hatırlatıcılar` etiketi dar cihazda sığmıyor | `AppNavBar` etiketi `maxLines: 1` + `ellipsis`; §10/V1 ile ölçülecek |
| Sekme 2'de geri tuşu | Sekme 0'a döner, uygulama kapanmaz (D6) |
| Vakit verisi yokken bildirim eklenirse | `rescheduleAll` planlama yapamaz, `cancelAllNotifications()` çağırır; bir sonraki veri yüklemesinde planlanır |
| Alarm izni reddedilirse | Alarm kaydedilir, uyarı banner'ı görünür — bugünkü davranış |
| Konum değişince | `HomePage` `ValueKey(location.id)` ile yeniden kurulur; sekme 0'a döner (bugünkü davranış, kasıtlı) |
| Segment değiştirilince | Scroll konumu korunur (`IndexedStack`) |
| Ana ekrandaki "Tümünü gör" | Push değil, sekme 2'ye geçiş |

## 9. Test stratejisi

**`AppNavBar` (`test/widgets/common/app_nav_bar_test.dart`):**
- Üç öğe çizilir, etiketleri doğrudur.
- Seçili öğe `accent`, diğerleri `textTertiary`.
- Dokunma `onChanged`'i doğru indeksle çağırır.
- Gösterge seçili dilimin altındadır.

**Kabuk (`test/presentation/home_page_nav_test.dart`):**
- Sekme değişimi doğru gövdeyi gösterir.
- Sekme 2'deyken geri → sekme 0; sekme 0'da geri → `canPop` true.

**`RemindersScreen`:**
- Segment geçişi doğru bölümü gösterir.
- `+` Bildirimler segmentindeyken bildirim sheet'ini, Alarmlar segmentindeyken
  `AlarmEditScreen`'i açar.
- İzin uyarısı yalnızca ilgili segmentte görünür.

**Regresyon — §7'nin testleri:**
- Bildirim eklenince `AppState.notificationSettings` tazelenir (bugün kırık).
- Alarm eklenince/silinince `AppState.alarms` tazelenir (bugün kırık).

**Değişmez kural (§6.3):**
- Hatırlatıcılar ekranında bir alarm kapatıldığında yapılan yeniden
  planlamanın, atlanmış bir bildirimi **geri planlamadığı** doğrulanır.

**Mevcut testler:** 520'sinin de geçmesi beklenir. Tek dokunulacak dosya
`test/widgets/screens/alarms_screen_test.dart` — silinen ekranı etiket
yardımcıları için import ediyor; §6.1'deki taşımayla birlikte
`test/presentation/alarm_labels_test.dart`'a taşınır, assertion'ları
değişmez. Hiçbir test bu ekranları widget olarak kurmadığı için regresyon
yüzeyi dar.

## 10. Uygulamadan önce doğrulanacaklar

| # | Varsayım | Doğrulama |
|---|---|---|
| V1 | `Hatırlatıcılar` etiketi 1/3 dilimde sığıyor | En dar desteklenen genişlikte (320pt → 106pt dilim) `tabLabel` w600 ile ölçülecek; sığmazsa etiket `Hatırlatma`'ya kısalır |
| V2 | Testlerin silinen ekranlara bağımlılığı | **Doğrulandı:** hiçbir test bu ekranları *widget olarak* kurmuyor, ama `test/widgets/screens/alarms_screen_test.dart` dosyayı etiket yardımcıları için import ediyor (16 assertion). §6.1'deki taşımayla birlikte güncellenecek — başka bağımlılık yok |
| V3 | `NotificationSettingsScreen` gerçekten `pop(true)` yapmıyor | **Doğrulandı:** `grep -rn "Navigator.pop"` yalnızca `add_notification_bottom_sheet.dart:77`'de sheet'in kendini kapatmasını buluyor |
| V4 | `setAlarms` tek çağırana sahip | **Doğrulandı:** yalnızca `home_page.dart:255` |
| V5 | Etiket yardımcılarının dış kullanıcıları | **Doğrulandı:** `upcoming_card.dart:11` (`show alarmTimeLabel`) ve `alarms_screen_test.dart`. `AlarmEditScreen` bunları kullanmıyor — yalnızca `sliding_segment.dart`'ı import ediyor |
| V6 | `CalendarScreen` sekme olarak barındırıldığında `extendBodyBehindAppBar` düzeni bozulmuyor | Simülatörde bakılacak; alt bar `Scaffold.bottomNavigationBar` olarak kaldığı için gövde yüksekliği değişiyor |

## 11. Ana spec'te geçersizleşen bölümler

`2026-08-01-redesign-0.3.0-design.md` içinde:

- **§4.4** — "Kayan segment (üç yerde aynı bileşen)" tablosundaki **"Alt
  gezinme"** satırı geçersiz. `SlidingSegment` artık iki yerde kullanılır
  (alarm türü, tema) + yeni bir üçüncü yer (Hatırlatıcılar filtresi). Alt
  gezinme `AppNavBar`'a taşındı (D4).
- **§6.1/1** — Üst çubuğun sağındaki `menu` ikonu `settings` oldu (D5).
- **§6.2 / §6.4** — "Alarmlar" ve "Bildirimler" ayrı ekran gereksinimleri
  artık tek "Hatırlatıcılar" ekranını tanımlar (D2).
