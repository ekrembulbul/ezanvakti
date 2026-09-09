# 0005. Bildirim planlaması: atlama kimliği, sessiz pencere ve alarmdan yalıtım

- **Durum:** Kabul edildi
- **Tarih:** 2026-09-09
- **Etkilenen alan:** Vakit bildirimleri, tek seferlik atlama, sessiz pencereler

## Bağlam ve problem

Bildirim planlayıcısı projenin en sık düzeltilen bileşenlerinden biri (`notification_scheduler.dart`, 13 değişiklik). Sebebi, birbirine yakın duran ama bağımsız üç problemi aynı anda çözmek zorunda olması:

1. **Atlama tutarlılığı.** Kullanıcı "yarınki ikindiyi atla" dediğinde, kartta gördüğü anahtar ile planlayıcının atladığı örnek aynı olmalı. Bu ikisi ayrışırsa anahtar kapalı görünürken bildirim çalar (commit `ae0bf27`).
2. **Sessiz pencere.** Kullanıcı belirli aralıklarda bildirim istemez. Ancak bu isteğin gerçekten karşılanabilirliği platforma bağlı.
3. **Sistem kotaları.** iOS uygulama başına yaklaşık 64 bekleyen yerel bildirim tutar ve fazlasını sessizce atar.

Ayrıca üstteki bir kırılganlık vardı: bildirim planlamasında oluşan bir hata, aynı akış içindeki alarm planlamasını da düşürüyordu (commit `2375162`). Bildirim bir kolaylık, alarm ise uygulamanın var oluş sebebidir; ikisinin kaderi bağlı olamaz.

## Karar

**Atlama kimliği tek bir sorgudan geçer.** Kart ve planlayıcı `isSkipped()` fonksiyonunu, kimliği aynı vakit verisinden türeterek çağırır (`kind` + `reference` + `fireAt`). Aynı kaynaktan türedikleri için ayrışamazlar (`skip_rules.dart:3-8`). Tetiklenme anı geçmiş atlamalar `withoutExpired()` ile kendiliğinden ölür; kullanıcının "geri aç" demesi gerekmez.

**Sessiz pencere kararı tetiklenme anına göre verilir**, vaktin kendisine göre değil. "45 dakika önce" hatırlatması pencere dışına düşüyorsa sesli kalır (`quiet_window_rules.dart:6-8`). Çakışan pencerelerde daha güçlü olan kazanır: `skip`, `silent`'tan daha kapsayıcı bir istektir.

**Sessiz pencere yalnızca Android'de etkindir** (`quietWindowsEnabled` bayrağı). iOS'ta bir uygulama telefonu sessize alamaz; ayar yalnızca kendi bildirimlerimizi susturuyor ve kullanıcının beklediği işi yapmıyordu. Yarım çalışan bir ayar sunmak yerine platformda hiç sunulmuyor. Bkz. [0003](0003-platform-alarm-models.md).

**Kota kontrollü kapatılır.** 7 günlük pencere planlanır (`scheduleDaysAhead`), ancak en yakın olanlardan sistem limiti kadarı kurulur. Öngörülemez OS elemesi yerine bilinçli bir kesme tercih edilir.

**Bildirim planlaması alarm planlamasından yalıtılır.** Bildirim tarafındaki bir hata alarm kurulumunu engellemez; hata loglanır ve akış devam eder.

## Sonuçlar

### Olumlu

- Kart ile planlayıcının ayrışması yapısal olarak engellenir; tek sorgu iki tüketiciyi de besler.
- Geçmiş atlamaların kendiliğinden ölmesi, kullanıcıdan ek bir işlem beklemez.
- Bildirim tarafındaki bir regresyon alarm güvenilirliğini düşürmez.

### Bedeller

- Sessiz pencere iki platformda farklı davranır; kullanıcı iOS'ta ayarı hiç görmez. Bu bir ürün tutarsızlığıdır, bilinçli kabul edilmiştir.
- Kota nedeniyle uzaktaki bazı bildirimler kurulmaz; uygulama düzenli açılmazsa 7 günün tamamı kapsanmayabilir.
- Atlama kimliği vakit verisinden türediği için, vakit verisi değişirse (konum değişikliği, düzeltme ayarı) mevcut atlama kayıtları eşleşmeyi kaybedebilir.

## Değerlendirilen alternatifler

**Atlamayı indeks ya da sıra numarasıyla tutmak.** Basit ve küçük. Reddedildi: vakit listesi değiştiğinde indeks kayar ve yanlış örnek atlanır.

**Sessiz pencereyi iOS'ta da göstermek, yalnızca kendi bildirimlerimizi susturmak.** Platformlar arası tutarlı arayüz. Reddedildi: kullanıcı "sessiz pencere" ifadesinden telefonun susmasını anlıyor; yalnızca kendi bildirimlerimizi susturan bir ayar sözünü tutmuyor.

**Tüm 7 günü kurup OS'un elemesine bırakmak.** Kod basitleşir. Reddedildi: iOS hangi bildirimleri atacağını bildirmez; en yakın bildirimler bile kaybolabilir.

## Referanslar

- `lib/features/notifications/domain/skip_rules.dart` — atlama kimliği ve süresi geçmiş kayıtların elenmesi
- `lib/features/notifications/domain/quiet_window_rules.dart` — pencere çözümü ve çakışma önceliği
- `lib/features/notifications/domain/notification_scheduler.dart:26-45` — platform bayrağı, kota ve gün penceresi
- `lib/features/notifications/domain/notification_time_rules.dart` — planlayıcı ile ekranın ortak vakit kuralı
- Commit `ae0bf27` — bildirim zamanı ve atlama kimliğinin eşitlenmesi
- Commit `2375162` — alarm planlamasının bildirim hatasından ayrılması
- Commit `2cfc4b8` — sessiz pencerelerin yalnızca Android'de sunulması
