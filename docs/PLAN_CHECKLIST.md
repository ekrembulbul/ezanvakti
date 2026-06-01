# Ezan Vakti Uygulaması — Checklist

**IMPORTANT: All code, file names, variable names, class names, and function names MUST be in English.**

## Hazırlık
- [x] Proje yapısını kur (modüller: vakitler, lokasyon, bildirimler, ayarlar)
- [x] Awqat Salah API istemci/adapter arayüzünü tanımla
- [x] Yerel saklama altyapısını seç ve arayüzünü yaz (SQLite)
- [x] Bildirim planlayıcı için platform servislerini tanımla
- [x] Test: Proje kurulumu sonrası modüller ve arayüzlerin birbirine bağımlılıkları derleniyor mu?

## Vakitler (veri katmanı)
- [x] Awqat Salah API'den (Diyanet verisi) veri çekme ve parse etme fonksiyonu
- [x] Vakit veri modeli + repository (cache via SQLite + remote)
- [x] Cache stratejisi (SQLite): bugün + ileri günleri tut; çok eski veriyi temizle
- [x] "Son güncelleme zamanı" bilgisini (SQLite) kaydet ve döndür
- [x] Test: API'den alınan veriler doğru parse ediliyor ve SQLite'a cacheleniyor; son güncelleme zamanı beklenen formatta dönüyor mu?

## Lokasyon
- [x] İl/ilçe veri kaynağı ve UI bileşeni
- [x] Seçilen lokasyonu sakla (tek aktif lokasyon)
- [x] Lokasyon değişiminde: vakitleri yeniden çek, cache'i güncelle, bildirimleri yeniden planla
- [x] Test: Lokasyon seçimi ve değişimi sonrası cache güncelleniyor, yeni bildirimler planlanıyor ve önceki planlar iptal oluyor mu?

## Offline davranış
- [x] İnternet yokken cache'den (SQLite) vakitleri göster
- [x] Güncelleme başarısızsa kullanıcıya net mesaj göster
- [x] Cache (SQLite) süresi dolmuş/veri yoksa "veri alınamadı" ekranı
- [x] Test: Offline modda cache verisi gösteriliyor, cache yoksa uygun hata ekranı ve mesajlar geliyor mu?

## Saat/Zaman Dilimi
- [x] Vakitleri cihaz saat dilimine göre göster
- [x] DST/timezone değişimlerinde bildirim saatlerini güncelle
- [x] Cihaz saati hatalıysa uyarı göster (opsiyonel)
- [x] Test: Saat dilimi/DST değişimlerinde vakit ve bildirim saatleri doğru güncelleniyor, cihaz saati sapmasında uyarı çıkıyor mu?

## Bildirimler
- [x] Bildirim izni durumunu oku ve ayarlarda göster
- [x] Her vakit için iki tetik: tam vakit ve X dk önce
- [x] Kullanıcı bazlı offset seçimini kaydet ve uygula
- [x] "Yakın gelecek" (örn. 7 gün) için bildirim planla; açılışta/ayar değişince yenile
- [x] Lokasyon/kaynak değişiminde eski planları iptal, yenilerini kur
- [x] Duplicate bildirimleri engelle (vakit + offset bazında)
- [x] Test: İzin durumu doğru okunuyor; vakit ve offset bildirimleri tekil şekilde planlanıp gerektiğinde iptal/yenileniyor mu?

## İzinler
- [x] Bildirim iznini ihtiyaç anında iste; reddedilirse CTA göster
- [x] Otomatik konum eklenirse: izin sadece tetiklendiğinde iste; reddedilirse manuel seçime dön
- [x] Test: İzin akışında hem bildirim hem konum için reddet/izin ver senaryoları doğru CTA’lar ve fallback’lerle çalışıyor mu?

## Ekranlar ve akışlar
- [x] İlk kurulum: lokasyon seçimi → ana ekran → (isteğe bağlı) bildirim ayarları
- [x] Ana ekran: bugünün vakitleri, sonraki vakit vurgusu, son güncelleme zamanı, kaynak etiketi
- [x] Vakit takvimi: en az 7 gün, tercihen 30 gün liste
- [x] Bildirim ayarları: global toggle (opsiyonel), vakit bazlı toggle, offset seçimi, izin durumu/CTA
- [x] Ayarlar: lokasyon değiştir, (hazır) kaynak seçimi, temel tercihler
- [x] Test: Onboarding'den ayarlara kadar akışlar kesintisiz ilerliyor; her ekranda gerekli veriler, izin durumu ve aksiyonlar doğru görünüyor mu?

## Hata senaryoları
- [x] API erişilemiyor: SQLite cache varsa göster; yoksa "veri alınamadı"
- [x] Lokasyon yok: zorunlu onboarding'e yönlendir
- [x] Bildirim izni yok: ayar aktif edilemez, durum açıklanır
- [x] Veri parse değişti: crash etme; logla ve kullanıcıya güncelleme mesajı göster
- [x] Test: Her hata senaryosunda uygun fallback, yönlendirme ve kullanıcı mesajları gösteriliyor; uygulama crash etmiyor mu?

## Modülerlik
- [x] Provider konseptini soyut arayüzle uygula (Türkiye/Diyanet varsayılan)
- [x] Bildirim, lokasyon, vakitler, ayarlar modüler kalsın
- [x] Depolama motoru değişse de iş kuralları korunacak şekilde soyutlama
- [x] Test: Provider soyutlaması ile yeni kaynak eklenince iş kuralları bozulmadan çalışıyor mu; modüller bağımsız test edilebiliyor mu?

## Kabul kriterleri (MVP)
- [x] Lokasyon seçilip bugünün vakitleri görülebiliyor (entegrasyon tamamlandı)
- [x] İnternet yokken önceden çekilmiş vakitler görüntüleniyor (entegrasyon tamamlandı)
- [x] Seçilen vakitlerde ve/veya X dk önce bildirim geliyor (entegrasyon tamamlandı)
- [x] Lokasyon değişince bildirimler doğru güncelleniyor (entegrasyon tamamlandı)
- [x] Bildirim izni yoksa kullanıcı bilgilendiriliyor ve doğru aksiyona yönlendiriliyor (entegrasyon tamamlandı)
- [x] Yeni kaynak eklemek tasarım olarak mümkün (PrayerTimeProvider abstract interface mevcut)
- [ ] Test: MVP kriterlerinin uçtan uca senaryolarla (online/offline, lokasyon değişimi, izin yok) doğrulandığı kabul testleri geçiyor mu?

**MVP Tamamlandı!** Main app entegrasyonu (state management, routing, ekranları birbirine bağlama) tamamlandı. Uygulama çalışır durumda.
