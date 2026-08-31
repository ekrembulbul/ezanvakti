# Tur 2 — Ses ve Sessizlik (0.7.0)

Tarih: 2026-08-31 · Baz: Tur 1 (`feat/tur1-alarm`, DB v9) · Platform kapsamı: yalnızca iOS

Tam tasarım artifact'ta ("Ezan Vakti 0.6+ Tasarımı", rev. 3, Tur 2 bölümü); bu dosya repo içi sözleşmedir.

## Amaç

Kullanıcının verdiği örnek — "Cuma vaktinde sessize alma" — ve etrafındaki ses/sessizlik ayarları. Tur sonunda Ayarlar gerçek bir ekran olur.

## Kapsam

### SES.1 — Sessiz pencereler (Cuma dahil)
Kullanıcı pencere tanımlar; pencereye düşen bildirimler sessiz gösterilir ya da hiç planlanmaz. Cuma hazır şablon: öğle vaktinden 15 dk önce → 60 dk sonra.

- Model: `QuietWindow { id, trigger: fridayDhuhr | prayer, prayerType?, minutesBefore, minutesAfter, mode: silent | skip, isActive }`.
- Saklama: `settings` anahtarı `quiet_windows` = JSON listesi. Migration gerekmez.
- Planlayıcı: adayın **tetiklenme anı** aktif bir pencerenin içindeyse `mode`'a göre sessiz işaretlenir ya da atlanır. Tetiklenme anına bakmak doğru: "45 dk önce" hatırlatması pencere dışındaysa sesli kalır.
- **iOS'ta telefonu sessize almaz** — yalnızca uygulamanın kendi bildirimlerini susturur; arayüz bunu açıkça yazar. Alarmlara (AlarmKit) dokunulmaz.

### SES.2 — Bildirim başına ses
`system` (varsayılan) · `beep` · `silent`. Gömülü kısa ezan **bu turda yok** (telifli/özgün kayıt gerekiyor — açık iş).

- iOS bildirim sesi ≤30 sn; `beep.caf` bundle'a girer, `DarwinNotificationDetails(sound:)` ile verilir. `silent` → `presentSound: false`.
- Android'de ses başına ayrı kanal gerekir (kanal sesi sonradan değişmez) — Android turuna.

### SES.3 — Odak modunda göster
Tek global anahtar (varsayılan açık): vakit bildirimleri `InterruptionLevel.timeSensitive` ile gönderilir. Sessiz anahtarını **delmez**; arayüz bunu dürüstçe yazar. Entitlement: `com.apple.developer.usernotifications.time-sensitive`.

### SES.4 — Bildirimlere gün filtresi + Cuma hatırlatıcısı
Bildirim satırına haftanın günleri (Alarm ile aynı CSV kodlaması, boş = her gün) ve isteğe bağlı etiket. "Cuma namazı" bunun hazır şablonu: öğle · 45 dk önce · yalnızca Cuma · etiket "Cuma namazı".

### SES.5 — Vakit ince ayarı
Vakit başına −15…+15 dk düzeltme. **Yerelde** uygulanır (`PrayerTimeTuner`), Aladhan `tune` parametresiyle değil: önbellek ham veriyi tutar, düzeltme okurken uygulanır — cache invalidation yok, çevrimdışı çalışır, ayar değişince yeniden fetch gerekmez.

### SES.6 — 12/24 saat + otomatik konum anahtarı
`time_format: system | h24 | h12`; merkezi `TimeFormatter`. Otomatik konum izleme için Ayarlar'da görünür anahtar. iOS widget bu turda 24 saat kalır (Swift formatlaması Tur 4).

## Kimlik ve şema kararları

- **DB v10:** `notification_settings` tablosuna `sound_id TEXT`, `weekdays TEXT NOT NULL DEFAULT ''`, `label TEXT`; `UNIQUE(prayer_type, minutes_before)` → `UNIQUE(prayer_type, minutes_before, weekdays)` (SQLite'ta tablo yeniden oluşturma, v5 kalıbı).
- **Kimlik:** `NotificationSetting`in kimliği artık `(prayerType, minutesBefore, weekdays)` üçlüsü. `notificationKey` buna göre genişler → **mevcut "yalnızca bu sefer" atlama kayıtları geçersizleşir** (kısa ömürlü; changelog'a yazılır).
- **Bildirim ID şeması korunur** (`dayOrdinal·10000 + vakit·1000 + offset`). Aynı (gün, vakit, offset) iki satırdan gelebilir ("her gün" + "yalnızca Cuma"); planlayıcı adayları **spesifik satır (weekdays dolu) önce** sıralar, mevcut `seenIds` tekilleştirmesi gerisini halleder — Cuma günü spesifik satır, diğer günlerde genel satır çalar.
- Ses dosyası: `ios/Runner/Sounds/beep.caf` — özgün üretim (sinüs tonu), telif riski yok.

## Kapsam dışı
- Gömülü kısa/tam ezan kaydı (kaynak bulunana kadar), ses önizleme (yeni bağımlılık).
- Android native işler: gerçek DND sessize alma, ses başına kanal.
- Lokalizasyon altyapısı — ayrı iş olarak duruyor (tasarımdaki karar 6 hâlâ açık).
- Widget'ta 12/24 saat (Swift tarafı, Tur 4).

## Doğrulama
`flutter analyze` + `flutter test` temiz; yeni davranışlar birim testli (tuner, formatter, pencere kararı, gün filtresi eşleşmesi, migration). Cihaz testi Ekrem'de; tur sonunda TestFlight.
