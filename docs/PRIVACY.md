# Gizlilik Politikası — Ezan Vakti & Alarm

Yayındaki adres: **https://ezanvakti.ekrembulbul.me/privacy**

Metnin tek kaynağı [`server/internal/httpapi/privacy.html`](../server/internal/httpapi/privacy.html)
dosyasıdır. Dosya sunucu binary'sine gömülür; değişiklik `main`'e alınıp sunucu dağıtımı
bitince yayına çıkar. Bu adres App Store Connect ve Google Play Console'daki gizlilik
politikası alanına girilir.

Uygulamanın ya da sunucunun veri davranışı değiştiğinde (yeni izin, sunucuya giden yeni
veri, günlük kapsamı) metni ve "Son güncelleme" tarihini birlikte güncelle; Play Data
Safety cevaplarını da ([`PLAY_DATA_SAFETY.md`](PLAY_DATA_SAFETY.md)) kontrol et.
