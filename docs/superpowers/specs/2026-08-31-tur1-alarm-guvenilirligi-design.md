# Tur 1 — Alarm Güvenilirliği ve Alarm Özellikleri (0.6.0)

Tarih: 2026-08-31 · Baz: 0.5.5 (DB v8) · Platform kapsamı: yalnızca iOS (Android native işleri sonraki tura)

Tam tasarım artifact'ta ("Ezan Vakti 0.6+ Tasarımı", rev. 3); bu dosya repo içi özet ve sözleşmedir.

## Arka plan: 31 Ağustos olayı

Kullanıcının kurduğu alarmlar sabah çalmadı; uygulama açılınca görev ekranı geldi ama alarm çalmıyordu. Kod teşhisi üç kusur buldu:

- **K1 — Yarınki çalış kurulmuyor.** Her alarm AlarmKit'e yalnızca tek sonraki çalış olarak yazılıyor (`.fixed`, `ios/Runner/AppDelegate.swift:264`). Ertesi günün kurulumu "Tamam"/görev tamamlamaya (`rearmAlarms`) ya da uygulamanın öne gelmesine bağlı. Alarm kendiliğinden susarsa ya da durdurulup uygulamaya girilmezse ertesi sabah alarm kurulu değil.
- **K2 — Görevli oturumda bayatlık sınırı yok.** `StopGate` görevsizde 45 sn sonra ekran açmıyor; görevli yolda süre kontrolü yok (`lib/features/alarms/domain/stop_gate.dart:42-53`). Dünden kalan oturum bugün görev ekranını açıyor.
- **K3 — Zincir tavanı Dart'a haber vermiyor.** 60 dk / 40 tekrar tavanında native `pending=false` yapıyor ama SQLite'taki oturum açık kalıyor (`AppDelegate.swift:95-100`).

## Kapsam

### ALM.1 — Güvenilirlik düzeltmeleri
- **F1a:** Tekrarlı **sabit saatli** alarmlar AlarmKit `.relative(time:, repeats: .weekly([...]))` ile native tekrara geçer; uygulama açılmasa da her hafta çalar. O çalış için "yalnızca bu sefer atla" varsa o alarm geçici olarak eski tek-seferlik yönteme düşer (atlanan gün geçince relative'e döner).
- **F1b:** **Vakte çıpalı** alarmlar (saat her gün kayar, relative olamaz) önümüzdeki 7 günün çalışları ayrı `.fixed` kayıtlar olarak önden dizilir: `<id>#d0..#d6`. Görev zinciri (session + ladder) yalnızca en yakın çalışa (`#d0`) kurulur; sonraki günler her yeniden planlamada birincilleşir. Degrade: uygulama günlerce hiç açılmazsa 2.–7. gün alarmları çalar ama durdurulduklarında görev ekranı açılmaz (stopIntent uygulamayı açar, açılış genel yeniden planlamayı koşturur) — kabul edilen davranış.
- **F2:** StopGate görevli yolda da bayatlık uygular: `stoppedAt + chainDeadlineMinutes (60 dk)` geçtiyse `closeAndRearm`.
- **F3:** Native `stopChain` kuyruğa `chainStopped: true` işaretli olay yazar; Dart tarafı bu olayı görünce oturumu kapatır (`complete`) ve alarmları yeniden kurar; ekran açılmaz.
- **F4:** `scheduleAlarm` hatası görünür olur: başarısız alarmlar `settings` anahtarına yazılır, alarm satırının alt metninde "Kurulamadı — düzenleyip kaydederek yeniden dene" gösterilir; başarılı planlama kaydı temizler.

### ALM.2 — Alarm kopyalama
Alarm satırına uzun basınca alt sayfa: **Kopyala** (ve Sil). Kopya yeni id ile, etiket sonuna " (kopya)" eklenerek düzenleme ekranında açılır; kaydedilmeden çıkılırsa kalıcı olmaz.

### ALM.3 — QR kod kütüphanesi
- **DB v9:** `qr_codes(id TEXT PRIMARY KEY, label TEXT NOT NULL, payload TEXT NOT NULL, created_at TEXT NOT NULL)`.
- Alarm düzenlemedeki QR bölümü: **kayıtlı kodlardan seçim** + **yeni kod okutup adlandırarak kütüphaneye kaydetme**. `Alarm.qrPayload` ve görev akışı değişmez. Kütüphanede yeniden adlandırma/silme; bir alarmın kullandığı payload silinirken uyarı.

### ALM.4 — "Özel ses" etiketi düzeltmesi
Yeni alarmın `soundId` varsayılanı `'adhan'` (kaldırılmış ses) olduğu için seçici "Özel ses" gösteriyordu; native tarafta sistem varsayılanına düşüyor. Düzeltme: varsayılan `'default'`; **DB v9** migration'da `UPDATE alarms SET sound_id='default' WHERE sound_id='adhan'`; tanınmayan her değer arayüzde "Varsayılan" gösterilir.

### ALM.5 — Alarm ses seviyesi (bilgi, özellik değil)
AlarmKit sesi "Zil Sesi ve Uyarılar" seviyesiyle çalar; üçüncü taraflara seviye API'si yok. Alarm başına seviye ve "çalarken kısılamasın" iOS'ta yapılamaz; Android turunda (foreground service) yapılacak. iOS'ta alarm düzenleme ekranındaki ses satırının altına tek satır bilgi eklenir.

## Kapsam dışı (bilinçli)
- Görevli alarmda "Sınırsız" erteleme — kullanıcı kararıyla reddedildi (görevi işlevsiz kılar; mevcut engel doğru).
- Bildirim sesleri, sessiz pencereler, gün filtresi → Tur 2.
- Android native işler (DND, kanal sesleri, widget) → Android turu.

## Sözleşmeler / sabitler
- Bayatlık eşiği görevli yolda: `MissionTuning.chainDeadlineMinutes` (60) yeniden kullanılır; yeni sabit eklenmez.
- Çıpalı ön dizim: 7 gün; kimlik eki `#d<N>`; `MissionChainKeys.select` bu ekleri de alarmın zinciri saymalı.
- Olay şeması: `{alarmId, stoppedAt, chainStopped?: bool}` — `chainStopped` yoksa `false`.
- Hata kaydı anahtarı: `alarm_schedule_failures` = JSON `{ "<alarmId>": {"at": iso8601, "message": string} }`.
- Dart hafta günü 1=Pazartesi..7=Pazar ↔ Swift `Locale.Weekday` eşlemesi: 1→.monday … 7→.sunday.

## Doğrulama
- `flutter analyze` + `flutter test` temiz; yeni davranışlar birim testli (StopGate bayatlık, computeNextFires dizisi, chainStopped tüketimi, migration v9, QR CRUD).
- Swift saf mantık (weekday eşlemesi, MissionChainKeys `#d` seçimi) RunnerTests'e eklenir.
- Cihaz testi Ekrem'de; tur sonunda TestFlight.
