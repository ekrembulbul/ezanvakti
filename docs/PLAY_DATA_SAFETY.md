# Google Play — Data Safety formu cevapları

Play Console → App content → **Data safety** bölümünde aşağıdaki gibi doldur.
Uygulama hesap oluşturmaz, reklam/analitik kullanmaz; tek hassas veri **konum**dur ve
yalnızca işlev için işlenir, kullanıcı kimliğine bağlanmaz.

---

## Genel

- **Does your app collect or share any of the required user data types?** → **Yes**
- **Is all of the user data collected by your app encrypted in transit?** → **Yes**
  (Tüm dış istekler HTTPS üzerinden yapılır.)
- **Do you provide a way for users to request that their data is deleted?** → **Yes**
  (Veriler yalnızca cihazda tutulur; uygulama kaldırılınca veya uygulama içinden silinir.)

---

## Data types — **Location** ve **App activity → In-app search history**

Console'a 2 Kasım 2026'da bu haliyle girildi. Hesap oluşturma: "Uygulamam hesap
oluşturmaya izin vermiyor"; uygulama dışı hesapla giriş: Hayır; veri silme talebi
(isteğe bağlı soru) boş bırakıldı.

### Location → **Approximate location**

Sunucunun erişim günlüğü her isteğin IP adresini tutar; IP yaklaşık konum verir ve
günlük kısa süreli değildir. Bu yüzden ayrı ve muhafazakâr beyan edildi.

| Soru | Cevap |
|------|-------|
| Collected? | **Yes** · Shared? **No** |
| Processed ephemerally? | **No** (erişim günlüğü, boyut sınırlı) |
| Required or optional? | **Required** (her istekte) |
| **Purposes** | **App functionality**, **Fraud prevention, security, and compliance** |

### Location → **Precise location**

GPS koordinatı ~100 m'ye yuvarlanır; Play'in tanımına göre bu hâlâ "precise"tır.

| Soru | Cevap |
|------|-------|
| Collected? | **Yes** · Shared? **No** |
| Processed ephemerally? | **Yes** — en yakın ilçeyi bulmak için anlık işlenir, saklanmaz ve loglanmaz |
| Required or optional? | **Optional** (kullanıcı GPS yerine il/ilçe arayabilir) |
| **Purposes** | **App functionality** |

### App activity → **In-app search history**

İl/ilçe arama metni sunucuya gider; ne saklanır ne loglanır.

| Soru | Cevap |
|------|-------|
| Collected? | **Yes** · Shared? **No** |
| Processed ephemerally? | **Yes** |
| Required or optional? | **Optional** |
| **Purposes** | **App functionality** |

Hiçbiri izleme (tracking) için kullanılmaz ve kimliğe bağlanmaz (hesap yok).

> Not (konum ve arama için geçerli): "Shared" konusunda Play, veriyi **üçüncü tarafa** aktarmayı kasteder. Konum
> yalnızca geliştiricinin kendi sunucusuna (`vakit-api`) gider; üçüncü taraf vakit/adres
> servisi kullanılmaz. Bu yüzden beyan **No**'dur; "Collected" ise **Yes** kalır (veri
> cihazdan çıkıp geliştiricinin sunucusuna ulaşıyor). Veri pazarlanmaz, izleme için
> kullanılmaz.

---

## Toplanmayan / paylaşılmayan (formda işaretleme)

Aşağıdakilerin **hiçbiri** toplanmaz veya paylaşılmaz:
- Personal info (ad, e-posta, telefon, adres-defteri) — **No**
- Financial info — **No**
- Messages, Photos/Videos, Audio, Files — **No**
- Contacts, Calendar — **No**
- App activity (arama geçmişi dışında) / analytics — **No**
- Device or other identifiers — **No**
- Web browsing history — **No**

---

## Ek beyanlar (App content)

- **Ads:** Uygulama reklam içeriyor mu? → **No**
- **App access:** Giriş (login) gerektiren bölüm var mı? → **No** (tüm işlevler girişsiz)
- **Content rating:** IARC anketi — şiddet/uygunsuz içerik yok; büyük olasılıkla **Everyone / 3+**
- **Target audience:** Genel kullanım; çocuklara özel tasarlanmadı
- **Privacy policy URL:** https://ezanvakti.ekrembulbul.com/privacy
- **Government / News / Financial / COVID app:** Hepsi **No**
