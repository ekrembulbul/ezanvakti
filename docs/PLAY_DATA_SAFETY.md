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

## Data types — yalnızca **Location**

### Location → **Approximate location** ve **Precise location**

| Soru | Cevap |
|------|-------|
| Collected? | **Yes** |
| Shared? | **Yes** (yalnızca işlev için üçüncü taraf API'lere koordinat/arama metni iletilir: Aladhan, Photon/OpenStreetMap, platform jeokodlama) |
| Processed ephemerally? | API'lere giden konum **geçici** kullanılır, bizde saklanmaz. Cihazda önbellek çevrimdışı içindir. |
| Required or optional? | **Optional** (kullanıcı GPS yerine elle adres de arayabilir) |
| **Purposes** | **App functionality** (namaz vakti hesaplama ve hatırlatma) |
| Is this data used to track users? | **No** |
| Is this data linked to the user's identity? | **No** (hesap yok, kimliğe bağlanmaz) |

> Not: "Shared" konusunda Play, veriyi üçüncü tarafa aktarmayı kasteder. Konum, vakit
> hesabı/adres araması için Aladhan ve Photon/OpenStreetMap'e gönderildiğinden dürüst
> beyan **Yes**'tir. Veri pazarlanmaz, izleme için kullanılmaz.

---

## Toplanmayan / paylaşılmayan (formda işaretleme)

Aşağıdakilerin **hiçbiri** toplanmaz veya paylaşılmaz:
- Personal info (ad, e-posta, telefon, adres-defteri) — **No**
- Financial info — **No**
- Messages, Photos/Videos, Audio, Files — **No**
- Contacts, Calendar — **No**
- App activity / analytics — **No**
- Device or other identifiers — **No**
- Web browsing history — **No**

---

## Ek beyanlar (App content)

- **Ads:** Uygulama reklam içeriyor mu? → **No**
- **App access:** Giriş (login) gerektiren bölüm var mı? → **No** (tüm işlevler girişsiz)
- **Content rating:** IARC anketi — şiddet/uygunsuz içerik yok; büyük olasılıkla **Everyone / 3+**
- **Target audience:** Genel kullanım; çocuklara özel tasarlanmadı
- **Privacy policy URL:** `docs/privacy.html` host edildikten sonra o URL
- **Government / News / Financial / COVID app:** Hepsi **No**
