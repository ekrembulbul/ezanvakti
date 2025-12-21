PLAN.md — Ezan Vakti Uygulaması (Ürün Sınırları + Kurallar)

1) Amaç

Türkiye için (başlangıçta) Diyanet kaynağından ezan vakitlerini alıp, telefonda lokal saklayan ve bu vakitlere göre bildirim gönderebilen bir mobil uygulama (Android + iOS). İleride yeni ülke/kaynak eklenebilecek şekilde genişlemeye açık olmalı.

2) Kapsam sınırları (Net çizgiler)

2.1 Dahil (MVP)
	•	Türkiye lokasyonları için vakitleri çekme (Diyanet).
	•	Vakitleri cihazda lokal saklama, offline gösterme.
	•	Kullanıcının lokasyon seçebilmesi (en az il/ilçe seviyesinde).
	•	Bildirim ayarları:
	•	“Vaktinde bildir”
	•	“X dakika önce bildir” (X kullanıcı seçer; ör. 5/10/15/30/60)
	•	Vakit bazında aç/kapat (imsak/öğle/ikindi/akşam/yatsı vb.)
	•	İzin yönetimi (bildirim izni başta olmak üzere).
	•	Hata durumları ve fallback’ler (internet yok, API hata, izin yok).

2.2 Hariç (MVP’de yok)
	•	Sunucu, kullanıcı hesabı, senkronizasyon.
	•	Online DB, remote config, backend işleri.
	•	Sosyal özellikler.
	•	Ezan sesi/streaming gibi medya özellikleri (isteğe bağlı sonra).
	•	Widget (opsiyonel: MVP sonrası).

3) Çekirdek iş kuralları

3.1 Vakit Kaynağı
	•	Varsayılan kaynak: Diyanet (Türkiye).
	•	Mimari olarak “kaynak sağlayıcı” konsepti olmalı:
	•	Kaynak değiştirmek (gelecekte) mümkün olmalı.
	•	Kaynağa özgü parse/format değişiklikleri uygulamanın geri kalanını kırmamalı.

3.2 Lokasyon
	•	Kullanıcı en az bir lokasyon seçer:
	•	MVP: tek aktif lokasyon yeterli.
	•	Sonra: favori lokasyonlar eklenebilir.
	•	Lokasyon değişince:
	•	Gösterilen vakitler değişir
	•	Bildirimler yeniden planlanır (eski lokasyonun bildirimleri iptal edilir)

3.3 Offline davranış
	•	Uygulama internet yokken:
	•	En son kaydedilmiş vakitleri göstermeli
	•	“Son güncelleme zamanı” ve “veri güncellenemedi” gibi net bilgi vermeli
	•	Cache stratejisi:
	•	En az “bugün + ileri günler” (ör. 30 gün) tutulması hedeflenir
	•	Çok eski veriler temizlenebilir (ör. 90 gün)

3.4 Saat/Zaman Dilimi
	•	Vakitler cihazın saat dilimiyle doğru gösterilmeli.
	•	Yaz saati / timezone değişimleri bildirim saatlerini bozmamalı (mümkün olduğunca).
	•	Kullanıcının cihaz saati yanlışsa:
	•	Uygulama garanti veremez; kullanıcıya uyarı gösterebilir (opsiyonel).

4) Bildirim davranışı (ürün gereksinimi)

4.1 Bildirim türleri
	•	Her bir vakit için iki tip tetik:
	•	Tam vakitte (offset = 0)
	•	Öncesinde (offset = -X dakika)
	•	Kullanıcı her vakit için ayrı seçebilmeli.

4.2 Planlama politikası
	•	Bildirimler “yakın gelecek” için planlanır (örn 7 gün).
	•	Uygulama açılışında ve ayar değişimlerinde yeniden planlama yapılır.
	•	Çakışma/tekrar önleme:
	•	Aynı vakit için aynı offset ile duplicate bildirim oluşmamalı.
	•	Lokasyon değişimi / kaynak değişimi:
	•	Tüm eski planlar iptal + yeni planlar kur.

4.3 Sistem kısıtları (kabul)
	•	iOS ve Android’in pil optimizasyonları nedeniyle bazı cihazlarda gecikme olabilir:
	•	MVP kabul kriteri: “mümkün olan en güvenilir yerel planlama”.
	•	İleri sürüm: platforma özel iyileştirmeler.

5) İzinler ve kullanıcı onayı (MVP’nin parçası)

İzin isteme prensibi: İhtiyaç oldukça iste. İlk açılışta izin bombardımanı yok.

5.1 Bildirim izni (kritik)
	•	iOS: bildirim izni olmadan bildirim gönderilemez.
	•	Android: yeni sürümlerde bildirim izni gerekebilir.
Kural:
	•	Kullanıcı “Bildirimleri Aç” eylemini yaptığında izin istenir.
	•	İzin yoksa:
	•	Ayarlar ekranında net uyarı + “İzin ver” / “Ayarlar’a git” aksiyonu.
	•	İzin reddedilirse:
	•	Bildirim planlanmaz, kullanıcıya durum açıklanır.

5.2 Konum izni (opsiyonel)
	•	MVP’de lokasyon manuel seçilebiliyorsa konum izni zorunlu değil.
	•	Eğer “Konumdan otomatik bul” eklenirse:
	•	Konum izni yalnız o özellik tetiklenince istenir.
	•	Reddedilirse manuel seçime geri düşülür.

5.3 Widget (MVP sonrası)
	•	Widget için genelde kullanıcıdan runtime izin değil, platform kurulum/entitlement gereksinimleri olur.
	•	Widget yoksa bu bölüm “ileride” olarak işaretlenir.

6) Ekranlar ve kullanıcı akışları (MVP)

6.1 İlk kurulum akışı
	1.	Uygulama açılır
	2.	Lokasyon seçimi ekranı (il/ilçe)
	3.	Ana ekran (bugünün vakitleri)
	4.	Kullanıcı isterse bildirim ayarlarına gider

6.2 Ana ekran
	•	Bugünün vakitleri listesi
	•	“Bir sonraki vakit” vurgusu (opsiyonel)
	•	“Son veri güncelleme zamanı”
	•	Kaynak: Diyanet (etiket)

6.3 Vakit takvimi ekranı
	•	En az 7 gün, tercihen 30 gün liste görünümü

6.4 Bildirim ayarları ekranı
	•	Global aç/kapat (opsiyonel)
	•	Vakit bazlı toggle
	•	Önceden bildirim için dakika seçimi
	•	İzin durumu görünür olmalı (izin yoksa CTA)

6.5 Ayarlar ekranı
	•	Lokasyon değiştir
	•	(İleriye hazırlık) Kaynak seçimi (şimdilik tek seçenek olabilir ama UI hazır)
	•	Basit tercih ayarları (tema/dil vb. sonra)

7) Hata senaryoları (beklenen davranış)
	•	API erişilemiyor:
	•	Cache varsa göster, yoksa “veri alınamadı” ekranı
	•	Lokasyon seçilmemiş:
	•	Zorunlu onboarding’e yönlendir
	•	Bildirim izni yok:
	•	Bildirim ayarı aktif edilemez / etkinleşmez; kullanıcıya açık anlat
	•	Veri parse değişti:
	•	Uygulama crash etmemeli; hata log + kullanıcıya “güncelleme gerekiyor olabilir” benzeri mesaj

8) Modülerlik ve genişleme sınırları
	•	Yeni ülke/kaynak ekleme:
	•	Uygulama içi “Provider” konsepti olmalı.
	•	Türkiye (Diyanet) default; diğerleri sonradan eklenebilir.
	•	Yeni feature ekleme:
	•	Bildirim, lokasyon, vakitler, ayarlar ayrı modüller/alanlar olarak düşünülmeli.
	•	Yerel saklama değişebilir:
	•	Depolama motoru ileride değişse bile “iş kuralları” bozulmamalı.

9) Gizlilik ve veri prensipleri
	•	Kullanıcı verisi dışarı gönderilmez (MVP).
	•	Lokasyon bilgisi cihazda tutulur.
	•	İzin metinleri açık ve anlaşılır olmalı.

10) Kabul kriterleri (MVP “Done”)
	•	Kullanıcı lokasyon seçebiliyor ve bugünün vakitlerini görüyor.
	•	İnternet yokken daha önce çekilmiş vakitler görüntüleniyor (varsa).
	•	Kullanıcı seçtiği vakitlerde ve/veya X dk önce bildirim alabiliyor (izin verilmişse).
	•	Lokasyon değişince bildirimler doğru şekilde güncelleniyor (eski planlar iptal).
	•	Bildirim izni yoksa uygulama bunu düzgün anlatıyor ve kullanıcıyı doğru aksiyona yönlendiriyor.
	•	Yeni kaynak eklemek “teorik olarak” mümkün (tasarım buna kapalı değil).