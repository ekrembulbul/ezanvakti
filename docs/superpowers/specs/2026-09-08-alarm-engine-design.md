# Alarm motoru güvenilirlik tasarımı

Kullanıcı, cihaz incelemesindeki bulgular için tasarım ve düzeltmelerin uygulanmasını istedi. Çalışma mimaridir; keşif, implementasyon ve review inline yürütülür. Dayanak: [fiziksel cihaz incelemesi](../../investigations/2026-09-08-device-alarm-audit.md).

## Davranış

- iOS sistem Stop aksiyonu foreground açılışı istemez. Alarm/çalış kimliğini native olarak işler, görev durumunu saklar ve gerekiyorsa nöbetçiyi kurar. Kilidin açılmaması bu işlemleri iptal etmez.
- Native alarmda ayrı bir **Görevi aç** aksiyonu bulunur; görevsiz ve ertelemeli alarmda **Alarmı aç** kullanılır. Bu aksiyon uygulamayı açar. Görevli alarmın sistem aksiyonu “Ertele” diye adlandırılmaz. Uygulama içindeki erteleme, mevcut açık/kapalı ve hak sınırı tercihine uyar.
- Süresi geçmiş ertelemeden görev başlatılırken snooze tarihi temizlenir. Sayaçlar native son tarihten okunur; Flutter aynı süreyi yeniden hesaplayıp uzatmaz.
- Bir görev tamamlanınca yalnız o çalışın yardımcı alarmları temizlenir. Silme/pasifleştirme ise kök alarma ait ana, yedek, nöbetçi ve bekleyen görev durumlarının tamamını hedefler.
- Başarısız native iptal başarı olarak gösterilmez. Silme niyeti depoda kalır; kullanıcı retry yapabilir ve sonraki plan uzlaştırması temizliği tekrar dener.

## Plan uzlaştırma

`AlarmScheduler` vakit/offset/tekrar hesabının tek kaynağı kalır. Native'e tek bir istenen plan gönderilir:

- Kararlı kimlikli ana kayıtlar ve yapılandırmaları.
- Aktif kök alarm kimlikleri; silinen/pasif köklerin canlı zincir korumasından yararlanmasını önler.
- Vakit verisiyle yeni çalış üretilemediğinden mevcut planı korunacak aktif çıpalı kökler; kısmi cache için eksik kaynak günlerinin offset uygulanmış zaman aralıkları.
- Tek seferlik atlamanın kök id ve asıl çalma zamanı; ertelenen timer zamanı örnek kimliğinin yerine geçmez.

Native uzlaştırıcı gerçek OS kayıtlarını ve kalıcı yapılandırmayı karşılaştırır. Değişmeyen kayıtlar yeniden kurulmaz. Yeni/değişen kayıt kabul edilmeden aynı kökün eski geçerli planı kaldırılmaz. Bir kökün hatası diğer kökleri durdurmaz. Yakındaki ana çalışmalar tüm alarmlar arasında önce ele alınır; ileri günler ve fallback kayıtları bir ana alarmı aç bırakmaz.

OS tarafından çalıyor görünen kayıtlar otomatik refresh ile durdurulmaz. Yakın zamanda zamanı geçmiş bir çalışın yapılandırması, gecikmiş stop/open intent'inin çözülebilmesi için sınırlı süre tutulur; fallback'ler de bu kurala dahildir. Explicit delete bu korumayı aşarak bütün kökü kapatır.

Planlama, CRUD ve explicit iptal Dart'ta aynı kuyruğu kullanır. Her plan kuyruğa girdiği sırada değil, çalışmaya başladığında güncel depoyu okur. Böylece eski bir snapshot, silmeden sonra alarmı geri kuramaz. Native SDK mutasyonları ve intent işlemleri de tek native kuyrukta yürür.

Sabit saatli alarmlar vakit cache'i yokken de planlanır. Yeni çıpalı çalış hesaplanamıyorsa o kökün geçerli planı korunur. Kısmi cache'te yalnız eksik kaynak günlerine ait gelecekteki kayıtlar korunur; verisi bulunan günlerde eski kayıtlar normal biçimde değiştirilir. Silme ve açık tek seferlik atlama bu korumayı aşar.

Tek seferlik atlama, ilgili çalışın canlı zincir korumasını da aşar. Native tarafta atlama saklanır; gecikmiş callback onu geri açamaz. Geçmiş atlamalar 24 saat tutulur, gelecekteki atlama geri alınabilir. iOS atlama varken sabit alarmı tarihli diziyle kurar; atlanan zaman geçtikten sonraki durdurmada haftalık template'i geri yükler. Android tek haftalık template'i korur ve atlanan teslimi receiver/mission katmanında eler. Haftada bir tekrarlanan alarm için de sonraki yedi kayıt üretilebilsin diye hesaplama ufku 64 gündür.

## Görev durumu

Native alarm/çalış oturumları kalıcı ve esas kaynaktır. Flutter, `getMissionSessions` ile snapshot okur; bir kuyruğu tüketip sonra SQLite'a yazmaya bağımlı olmaz. Yeniden açılış, başarısız UI işlemi veya bir başka alarmın gelmesi mevcut native oturumu kaybettirmez.

Flutter aynı anda tek görev ekranı gösterebilir, fakat tüm bekleyen/ertelenen oturumları tutar. Listeler kendi alarmının oturumunu seçer. Begin/snooze/complete/abort işlemleri kök id'ye ek olarak çalış zamanını doğrular; eski bir ekran yeni günün alarmını tamamlayamaz.

Tekrarlanan stop/open çağrıları aynı çalışın sayaçlarını gereksiz artırmaz. Open, zaten açılmış görevi veya var olan ertelemeyi yeniden başlatmaz. Eski yardımcı kayıtların callback'leri tamamlanmış veya daha yeni bir oturumu canlandırmaz.

## Nöbetçi ve fallback

Mevcut +5/+10/+15 fallback politikası ilk yakın çalışma için korunur; ana alarmın saatine kaydırma uygulanmaz. Bu kayıtlar açık rol ve kaynak çalış kimliğiyle izlenir. Stop başarıyla işlendiğinde kısa nöbetçi, görev başlayınca görev son tarihi, ertelemede tercih edilen süre kullanılır.

Nöbetçi değişiminde yeni, farklı kimlikli kayıt önce kurulur; eski yardımcı kayıtlar sonra kaldırılır. Yeni kurulum başarısızsa önceki güvence kalır. Başarılı yeni kayıttan sonra cleanup hata verirse yeni durum korunur, hata görünür/kayıtlı olur ve cleanup tekrar denenir. Retry hak/süreyi tekrar artırmaz.

## Katmanlar ve uyumluluk

- Dart: tipli plan modeli, scheduler komut kuyruğu, native snapshot kullanan coordinator.
- iOS: Flutter bridge + AlarmKit adaptörü; Foundation tabanlı, OS adaptörü taklit edilebilen plan/görev motoru; mevcut v2 kayıtlarını okuyabilen store.
- Android: aynı plan/snapshot/çalış doğrulama kontratı; PendingIntent kimliği korunur; boot kurtarması süresi geçmiş ertelemeyi gelecekteki bir nöbetçiye taşır, kapalı kökü veya bitmiş zinciri canlandırmaz. Native görev açılışı mevcut Android akışını izler.
- Bridge'e protocolVersion=2 planı ve snapshot yöntemleri eklenir. Mevcut RPC'ler geçiş için korunur; native veri alanları eski kayıtları okuyacak şekilde eklenir.

## Tanı ve hata yönetimi

Release logger açıkça production filtresi kullanır. Native alarm motoru sınırlı bir yerel journal tutar: işlem, opak kök/çalış/native kimliği, beklenen zaman, gözlenen OS durumu, sonuç ve hata kodu. Kullanıcı etiketi, QR içeriği ve özel dosya yolu journal'a girmez. Başarılı sonraki plan geçmiş hataları silmez.

OS durumu gözlemi, fiziksel ses başlangıcı gibi raporlanmaz. Güncel planlama hataları arayüzde kullanılmaya devam eder. Silme/pasifleştirme hatası ve retry mesajları TR/EN/AR olarak eklenir.

## Alternatifler ve tercih

Yalnız `openAppWhenRun` ve snooze alanını düzeltmek, toplu iptal ve silme yarışlarını bırakır. Tüm uygulamayı yeniden yazmak ise vakit hesabı ve UI gibi çalışan alanları gereksiz değiştirir. Tercih, alarm motorunu yukarıdaki sorumluluklarla ayıran ve mevcut modelleri taşıyan kontrollü refactor'dır.

## Kabul koşulları

1. Refresh değişmeyen 08:00 kaydını iptal etmez; yeni schedule hatasında eski geçerli kayıt kalır.
2. Silinen/kapalı kökün aktif yardımcıları temizlenir; cache yokluğu ve bekleyen eski batch bu sonucu değiştirmez.
3. Cold start'ta fallback id'si çözülebilir; eski callback yeni çalışı değiştiremez.
4. Süresi geçmiş snooze sonrası begin geleceğe planlanır; sayaç native deadline ile aynıdır.
5. Nöbetçi kurulum hatası mevcut güvenceyi silmez; cleanup hatası ve retry idempotent davranır.
6. Birden fazla ertelenmiş alarmın durumları ayrı kalır; snapshot tekrar okunabilir ve Flutter depolama hatası olayı tüketmez.
7. Native stop foreground istemez; görev açma aksiyonu ayrı ve doğru etiketlidir.
8. Dart/native testler, analyze ve iki platformun debug build'i tamamlanır. Gerçek iPhone kilit ekranı ve fiziksel ses testi ayrıca raporlanır; simulator/unit sonuçları bunun yerine geçmez.

## Uygulama ve doğrulama

Tasarım uygulandı. Test kapsamı, build sonuçları ve fiziksel cihaz kabul adımları [doğrulama kaydında](../../investigations/2026-09-08-alarm-engine-verification.md) bulunur.
