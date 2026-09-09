# 0004. Vakit hesabında tek kaynak: ekran, planlayıcı ve widget aynı kuralı kullanır

- **Durum:** Kabul edildi
- **Tarih:** 2026-09-09
- **Etkilenen alan:** Vakit hesaplama, bildirim/alarm planlama, ana ekran, home widget

## Bağlam ve problem

Bir vakit üç ayrı yerde görünür ya da kullanılır:

1. Uygulama ekranlarında (sıradaki vakit, sayaç, takvim)
2. Bildirim ve alarm planlamasında
3. Home widget ve kilit ekranı sayacında — üstelik **uygulama çalışmıyorken**

Bu üç yol farklı hesaplarla beslenirse ortaya en kötü hata sınıfı çıkar: ekranda bir saat görünürken alarmın başka bir saatte çalması. Kullanıcı için sessiz, güveni doğrudan yıkan bir hata.

Hesabı zorlaştıran unsurlar: kullanıcının vakit başına verdiği ± dakika düzeltmesi, türetilmiş vakitler (işrak, istiva, gece yarısı, son üçte bir), gece vakitlerinin **ertesi günün imsakını** gerektirmesi ve widget'ın uygulama açılmadan günler boyu doğru kalma zorunluluğu.

## Karar

Vakit hesabı **saf domain fonksiyonlarında** tek kez yazılır; ekran, planlayıcı ve widget aynı fonksiyonları çağırır. Sunum katmanında ayrı hesap yapılmaz.

**Düzeltme yerelde uygulanır.** Kullanıcının ± dakika ayarı `PrayerTimeTuner` ile okuma anında uygulanır, veri sağlayıcının `tune` parametresiyle değil. Önbellek **ham veriyi** tutar. Böylece ayar değiştiğinde yeniden fetch gerekmez, çevrimdışı çalışır ve önbellek geçersizleştirme problemi hiç doğmaz (`prayer_time_tuner.dart:5-9`).

**Türetilmiş vakitler saf hesaptır.** `DerivedTimes.resolve()` yalnızca gün verisi ve sabitlerle çalışır; ağ ya da depo kullanmaz. Ertesi gün verisi yoksa `null` döner ve planlayıcı o günü sessizce atlar — uydurma bir vakit üretilmez.

**Tutarsız veride hesap yapılmaz.** Şer'i gece akşamdan ertesi imsaka kadardır; bu fark sıfır ya da negatifse `null` döner. Bozuk bir gün, gece yarısını sabaha kaydırmamalıdır (`derived_times.dart:37-38`).

**Widget bir anlık görüntü (snapshot) alır, hesap yapmaz.** `WidgetSnapshotBuilder` vakit listesini platform bağımsız bir yapıya çevirir ve 7 günlük bir pencere yazar. Native widget kodu hesap yapmaz, yalnızca payload'u okur. 7 gün bedavadır çünkü önbellek zaten 30 gün ileriyi tutar (`prayer_times_repository.dart:35`, `cacheDaysForward`); uygulama bir hafta açılmasa bile widget doğru kalır (`widget_snapshot_builder.dart:13-16`).

## Sonuçlar

### Olumlu

- Ekranda görünen zaman ile planlanan zamanın ayrışması yapısal olarak engellenir.
- Saf fonksiyonlar doğrudan test edilebilir; test hedefi sunum katmanı değil hesabın kendisidir.
- Çevrimdışı ve ayar değişikliği senaryoları ek bir geçersizleştirme mekanizması gerektirmez.

### Bedeller

- Widget penceresi kadar (7 gün) ileriye dönük veri her yayında serileştirilir; payload boyutu sabit bir maliyettir.
- Türetilmiş gece vakitleri ertesi gün verisine bağımlıdır; veri sınırında bu vakitler sessizce düşer. Bu bilinçlidir, ancak kullanıcıya görünmez.
- Düzeltmenin okuma anında uygulanması, ham veriyi doğrudan okuyan her yeni çağıranın `PrayerTimeTuner`'ı atlamaması gerektiği anlamına gelir — dikkat gerektiren bir sözleşmedir.

## Değerlendirilen alternatifler

**Düzeltmeyi sağlayıcının `tune` parametresiyle uygulamak.** Veri zaten düzeltilmiş gelir, okuma tarafı basitleşir. Reddedildi: her ayar değişikliği önbelleği geçersizleştirir ve yeniden fetch gerektirir; çevrimdışı kullanıcı ayarını değiştiremez hale gelir.

**Widget'ta native tarafta hesap yapmak.** Payload küçülür, daha az veri yazılır. Reddedildi: aynı hesabın Swift ve Kotlin'de tekrar yazılması gerekir — bu ADR'nin engellemek istediği ayrışmanın ta kendisi.

**Eksik ertesi gün verisinde tahmini bir gece uzunluğu kullanmak.** Vakit hiç kaybolmaz. Reddedildi: ibadet vakitlerinde tahmini değer üretmek kabul edilebilir değil; `null` dönüp atlamak dürüst olan davranış.

## Referanslar

- `lib/features/prayer_times/domain/derived_times.dart` — türetilmiş vakitler
- `lib/features/prayer_times/domain/prayer_time_tuner.dart:5-9` — yerel düzeltme kararı
- `lib/features/home_widget/domain/widget_snapshot_builder.dart:7-16` — snapshot penceresi
- `lib/features/notifications/domain/notification_time_rules.dart:20-24` — planlayıcının aynı kuralı çağırması
- `AGENTS.md` → "Alarm ve vakit doğruluğu" — bu ADR'nin kural olarak yazılmış hali
