# Ezan Vakti Uygulaması — Checklist

## Hazırlık
- [ ] Proje yapısını kur (modüller: vakitler, lokasyon, bildirimler, ayarlar)
- [ ] Awqat Salah API istemci/adapter arayüzünü tanımla
- [ ] Yerel saklama altyapısını seç ve arayüzünü yaz (SQLite)
- [ ] Bildirim planlayıcı için platform servislerini tanımla

## Vakitler (veri katmanı)
- [ ] Awqat Salah API’den (Diyanet verisi) veri çekme ve parse etme fonksiyonu
- [ ] Vakit veri modeli + repository (cache + remote)
- [ ] Cache stratejisi: bugün + ileri günleri tut; çok eski veriyi temizle
- [ ] “Son güncelleme zamanı” bilgisini kaydet ve döndür

## Lokasyon
- [ ] İl/ilçe veri kaynağı ve UI bileşeni
- [ ] Seçilen lokasyonu sakla (tek aktif lokasyon)
- [ ] Lokasyon değişiminde: vakitleri yeniden çek, cache’i güncelle, bildirimleri yeniden planla

## Offline davranış
- [ ] İnternet yokken cache’den vakitleri göster
- [ ] Güncelleme başarısızsa kullanıcıya net mesaj göster
- [ ] Cache süresi dolmuş/veri yoksa “veri alınamadı” ekranı

## Saat/Zaman Dilimi
- [ ] Vakitleri cihaz saat dilimine göre göster
- [ ] DST/timezone değişimlerinde bildirim saatlerini güncelle
- [ ] Cihaz saati hatalıysa uyarı göster (opsiyonel)

## Bildirimler
- [ ] Bildirim izni durumunu oku ve ayarlarda göster
- [ ] Her vakit için iki tetik: tam vakit ve X dk önce
- [ ] Kullanıcı bazlı offset seçimini kaydet ve uygula
- [ ] “Yakın gelecek” (örn. 7 gün) için bildirim planla; açılışta/ayar değişince yenile
- [ ] Lokasyon/kaynak değişiminde eski planları iptal, yenilerini kur
- [ ] Duplicate bildirimleri engelle (vakit + offset bazında)

## İzinler
- [ ] Bildirim iznini ihtiyaç anında iste; reddedilirse CTA göster
- [ ] Otomatik konum eklenirse: izin sadece tetiklendiğinde iste; reddedilirse manuel seçime dön

## Ekranlar ve akışlar
- [ ] İlk kurulum: lokasyon seçimi → ana ekran → (isteğe bağlı) bildirim ayarları
- [ ] Ana ekran: bugünün vakitleri, sonraki vakit vurgusu, son güncelleme zamanı, kaynak etiketi
- [ ] Vakit takvimi: en az 7 gün, tercihen 30 gün liste
- [ ] Bildirim ayarları: global toggle (opsiyonel), vakit bazlı toggle, offset seçimi, izin durumu/CTA
- [ ] Ayarlar: lokasyon değiştir, (hazır) kaynak seçimi, temel tercihler

## Hata senaryoları
- [ ] API erişilemiyor: cache varsa göster; yoksa “veri alınamadı”
- [ ] Lokasyon yok: zorunlu onboarding’e yönlendir
- [ ] Bildirim izni yok: ayar aktif edilemez, durum açıklanır
- [ ] Veri parse değişti: crash etme; logla ve kullanıcıya güncelleme mesajı göster

## Modülerlik
- [ ] Provider konseptini soyut arayüzle uygula (Türkiye/Diyanet varsayılan)
- [ ] Bildirim, lokasyon, vakitler, ayarlar modüler kalsın
- [ ] Depolama motoru değişse de iş kuralları korunacak şekilde soyutlama

## Kabul kriterleri (MVP)
- [ ] Lokasyon seçilip bugünün vakitleri görülebiliyor
- [ ] İnternet yokken önceden çekilmiş vakitler görüntüleniyor (varsa)
- [ ] Seçilen vakitlerde ve/veya X dk önce bildirim geliyor (izin verilmişse)
- [ ] Lokasyon değişince bildirimler doğru güncelleniyor (eski planlar iptal)
- [ ] Bildirim izni yoksa kullanıcı bilgilendiriliyor ve doğru aksiyona yönlendiriliyor
- [ ] Yeni kaynak eklemek tasarım olarak mümkün
