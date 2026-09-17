# Gizlilik Politikası — Ezan Vakti

> **Taslak.** Yayına almadan önce gözden geçir; geliştirici/iletişim bilgilerini ve
> yürürlük tarihini doğrula. Bu metin App Store ve Google Play başvurularında
> **herkese açık bir URL** olarak (örn. GitHub Pages) yayımlanmalıdır.

**Son güncelleme:** 17 Eylül 2026

Bu gizlilik politikası, **Ezan Vakti** mobil uygulamasının ("Uygulama") kişisel
verileri nasıl ele aldığını açıklar. Uygulamayı kullanarak bu politikayı kabul
etmiş olursunuz.

## Özet

Uygulama; Diyanet İşleri Başkanlığı'nın namaz vakitlerini göstermek ve
hatırlatmak için tasarlanmıştır. **Hesap oluşturmanız gerekmez.** Vakit ve ilçe
verisini sunan sunucumuz kimlik bilgisi almaz ve isteklerinizi saklamaz.
Verileriniz cihazınızda saklanır. Reklam ağı veya analitik (kullanım izleme)
servisi kullanılmaz.

## İşlenen veriler

- **Konum bilgisi:** Namaz vakitleri ilçeye göre gösterilir. "Konumumu kullan"
  seçildiğinde GPS koordinatınız, en yakın ilçeyi bulmak için yaklaşık 100 m
  hassasiyete yuvarlanarak sunucumuza gönderilir; sunucu bunu saklamaz.
  Cihazınızda saklanan koordinat kıble yönü içindir. Elle arama yaptığınızda
  yazdığınız il/ilçe metni sunucumuza gönderilir.
- **Uygulama tercihleri:** Bildirim ayarları, vakit düzeltme tercihi, kayıtlı
  konumlar — tümü cihazınızda saklanır.
- **Namaz vakitleri:** Çevrimdışı kullanım için cihazınızda (SQLite) önbelleğe
  alınır.

Uygulama; adınız, e-postanız, telefon numaranız veya rehberiniz gibi kimlik
bilgilerini **toplamaz**.

## Verilerin kullanımı

İşlenen veriler yalnızca şu amaçlarla kullanılır:

- Bulunduğunuz/seçtiğiniz ilçenin namaz vakitlerini göstermek,
- Seçtiğiniz vakitler için yerel bildirim/hatırlatma oluşturmak,
- Tercihlerinizi ve vakitleri çevrimdışı kullanım için cihazda saklamak.

## Sunucu ve veri kaynakları

Vakit tabloları, il/ilçe araması ve konum çözümleme için yalnızca **bize ait
vakit sunucusuna** istek gönderilir. Sunucuya giden veriler:

- İlçe araması için yazdığınız metin,
- Konum çözümleme için yaklaşık (~100 m) koordinat,
- Vakit tablosu için seçilen ilçenin kimliği.

Sunucu bu istekleri saklamaz, günlüğe yazmaz ve kimliğinizle ilişkilendirmez;
hesap veya cihaz kimliği gönderilmez. Bağlantı HTTPS ile şifrelenir.

Vakit tabloları **Diyanet İşleri Başkanlığı**'ndan alınır. Sunucudaki ilçe
koordinatları © OpenStreetMap katkıcıları. Üçüncü taraf bir vakit ya da adres
servisine veri gönderilmez.

## Veri saklama ve silme

Tüm uygulama verileri **yalnızca cihazınızda** tutulur; sunucu tarafında size ait
bir kayıt oluşmaz. Uygulamayı kaldırdığınızda bu veriler cihazınızdan silinir. Konum ve diğer tercihleri uygulama içinden de
değiştirebilir veya kaldırabilirsiniz.

## İzinler

Uygulama şu izinleri, yalnızca ilgili işlev için ister:

- **Konum:** Bulunduğunuz ilçeyi bulup vakitleri ona göre göstermek için.
- **Bildirim:** Vakit hatırlatmalarını göstermek için.
- **Tam zamanlı alarm (Android 12+):** Hatırlatmaların doğru vakitte çalması için.
- **Yeniden başlatmada çalışma (Android):** Cihaz yeniden başladığında planlanmış
  hatırlatmaları korumak için.

## Çocukların gizliliği

Uygulama çocuklardan bilerek kişisel veri toplamaz ve genel kullanıma yöneliktir.

## Politikadaki değişiklikler

Bu politika zaman zaman güncellenebilir. Güncellemeler bu sayfada "Son güncelleme"
tarihiyle yayımlanır.

## İletişim

Sorularınız için: **ekrembulbull@proton.me**

Geliştirici: Ekrem Bülbül
