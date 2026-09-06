# Kerahat ve Ramazan imsakiyesi

Durum: onaylanan tasarım uygulandı. [HTML önizlemesi](kerahat-imsakiye.html) örnek saatler içeren tasarım kaydıdır; canlı veri değildir.

## Kerahat

Ana sayaç sıradaki namaz vaktini göstermeye devam eder. Cetveldeki üç bordo aralık ve altındaki durum satırı aynı domain hesabını kullanır. Ayrıntı panelinde yaklaşık hesap ve kaynak açıklanır. Mevcut 45/10/45 dakika değerleri, her enlem ve mevsim için kesin astronomik sınır olarak sunulmaz.

[Diyanet Din İşleri Yüksek Kurulu](https://kurul.diyanet.gov.tr/tr/fetva/mekruh-vakitler-hangileridir-hangi-vakitlerde-kaza-ve-hangi-vakitlerde-nafile-namaz-kilinmaz/0193c42d-52b7-7186-d5b4-f1d3c950ad73), mutedil bölgelerde doğuştan sonra 40–50 dakika, öğle öncesinde yaklaşık 10 dakika ve batıştan önce 40–50 dakika açıklar. Namaz türü ve mezhep istisnaları nedeniyle genel bir yasak metni kullanılmaz. Görsel gösterim alarm ve bildirim planlamasını değiştirmez.

## Tam ay imsakiyesi

[Takvim](../../lib/presentation/screens/calendar_screen.dart) yıl boyunca Vakit Takvimi / İmsakiye seçimi sunar. Normal görünüm Home'un mevcut 13 günlük aralığını kullanır; imsakiye bağımsız repository ve controller ile seçilen Ramazan ayının tamamını yükler. Yalnızca kaynakla doğrulanmış 1445–1452 dönemleri seçilebilir. 2030'da başlayan iki ay hicri yıl kimliğiyle ayrıdır.

[Dönem kataloğu](../../lib/core/data/ramadan_periods.dart) başlangıç ve bayramın ilk gününü kaynak URL'leriyle saklar. Aralık başlangıç dahil, bayram hariçtir. 1447 dönemi 19 Şubat–19 Mart 2026, 1448 dönemi 8 Şubat–8 Mart 2027'dir; ikisi de 29 gündür. Katalog dışındaki dönemler için tarih tahmini yapılmaz.

Ay tarihleri Diyanet'in yayımladığı takvime; saatler mevcut Aladhan provider, seçili hesap yöntemi ve kullanıcı düzeltmelerine dayanır. Bu ayrım ekran ve paylaşımda belirtilir. İmsak ve İftar sütunları belirgindir. Dar ekranlarda tablo yatay kaydırılır; kaynak ve tarih aralığı kaydırma dışında da okunur.

Eksik, yinelenen veya aralık dışındaki günler tam ay olarak gösterilmez ve paylaşılamaz. Aynı kaynakla yenileme hatasında önceki tam ay korunur; konum/hesap ayarı değiştiğinde eski tablo kaldırılır. Request generation geciken cevapları; cache generation ve kısa yazma/silme kuyruğu eski fetch/save işlemlerinin temizlenmiş cache'i yeniden doldurmasını engeller. GPS koordinat değişimi aynı id'nin gelecekteki ay cache'ini de geçersizleştirir.

## Paylaşım ve doğrulama

İmsakiye paylaşımı, bütün satırları içeren ayrı bir widget ağacını PNG olarak render eder. Ekrandaki scroll konumu paylaşımı etkilemez. Görsel seçilen ay, tarih aralığı, konum ve kaynak ayrımını içerir. Image ve render kaynakları temizlenir, geçici paylaşım dosyaları işlem sonunda kaldırılır; iPad origin ve yinelenen paylaşım koruması bulunur.

Testler 29/30 gün, yıl geçişi, DST cache tamamlığı, eksik cache, tune, ters async cevaplar, kaynak/revision değişimi, GPS cache invalidation, dönem seçimi, dar ekran, büyük metin ve RTL davranışını kapsar. Gerçek fontla son günün İftar saatini değiştirmek üretilen PNG'yi değiştirir; tam ay görseli viewport yüksekliğini aşar. Unit/widget testleri native alarmın cihazda zamanında çalmasını kanıtlamaz. Platform build ve simulator smoke sonuçları teslim raporunda ayrıca belirtilir.
