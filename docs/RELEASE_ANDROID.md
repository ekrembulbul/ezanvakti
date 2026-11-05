# Android Sürüm Çıkarma (Play internal testing)

iOS TestFlight akışının Android karşılığı. Tag push'u GitHub Actions'ı tetikler; AAB
bulutta derlenip imzalanır ve fastlane `supply` ile **Play Console internal testing**
kanalına yüklenir. Yüklenen sürüm testçilere doğrudan açılır (Console'da ayrıca
"yayınla" gerekmez).

> Workflow `vX.Y.Z` ve `android-vX.Y.Z` tag'leriyle ya da elle (`workflow_dispatch`)
> tetiklenir. `PLAY_SERVICE_ACCOUNT_JSON_BASE64` ve `ANDROID_KEYSTORE_BASE64`
> secret'larından biri yoksa yükleme işi kırmızı olmadan **atlanır**.

---

## Durum (2026-10-30)

Bir kerelik kurulum **tamam**; sürümler otomatik çıkar.

- Play uygulaması: **Ezan Vakti & Alarm**, paket `com.ekrembulbul.ezanvakti`.
- İlk AAB (0.31.1, derleme 75) Console'dan elle yüklendi; internal testing kanalı etkin.
- Testçiler Console'daki **"Dahili test"** e-posta listesinde (Test edin ve yayınlayın →
  Dahili test → Test kullanıcıları). Liste kanala bağlı; yeni adres eklemek yeterli.
- CI yükleme kimliği: service account `play-upload@ezanvakti-play.iam.gserviceaccount.com`
  (Google Cloud projesi `ezanvakti-play`, Google Play Android Developer API açık). Play'de
  yalnız bu uygulama için *uygulama bilgilerini görüntüleme* + *test kanallarına yayınlama*
  izni var; üretime yayınlama yetkisi **yok**.
- Tüm GitHub secret'ları tanımlı (aşağıdaki tablo).
- Henüz yapılmayan: mağaza kaydı, App content beyanları, gizlilik politikası URL'i ve kapalı
  test. Bunlar bitene kadar testçiler uygulamayı geçici adla
  (`com.ekrembulbul.ezanvakti (unreviewed)`) görür.

---

## Sürüm çıkarma (günlük akış)

1. `dev`'de `flutter analyze` + ilgili testler yeşil; CHANGELOG girişi ayrı commit'le yazılır
   (script changelog yazmaz).
2. `main`'e `git merge --ff-only dev`.
3. `main` üzerinde:
   - yalnız Android: `./scripts/release_tag.sh X.Y.Z --android` (tag `android-vX.Y.Z`)
   - iOS + Android: `./scripts/release_tag.sh X.Y.Z` (tag `vX.Y.Z`)

   Script pubspec sürümünü ve build numarasını artırır, commit'ler, tag atar, `main` ve
   tag'i push eder.
4. İlerleme: `gh run list --workflow android-play.yml` (Actions → **Android Play (internal)**).
5. İş bitince sürüm Play'de internal testing'de "completed" olur; testçilerin telefonuna
   güncelleme gelir (genelde dakikalar, bazen bir saate kadar).

**Kurallar**
- Build numarası (pubspec `+N`, Android `versionCode`) her yüklemede **artmalı**; Play aynı
  numarayı ikinci kez kabul etmez. Elle yüklenen 75'ten sonra 76+ gerekir. Bu yüzden CI'yi
  aynı sürümle `workflow_dispatch` ile yeniden çalıştırmak yükleme hatası verir.
- `vX.Y.Z` tag'i iOS'u da tetikler; yalnız Android değiştiyse `--android` kullan.

---

## Testçi ekleme ve kurulum

- Console → Dahili test → Test kullanıcıları → "Dahili test" listesi → adres ekle → kaydet.
- Play internal testing'de davet e-postası **gitmez**; kişiye katılım bağlantısını sen
  iletirsin: `https://play.google.com/apps/internaltest/4701332445920428033`
- Bağlantı **Chrome'da** açılmalı; Play Store uygulaması içinde açılınca sayfa boş kalıyor.
  Testçi kendi hesabıyla "Accept invite" der, sonra "Download test app" ile kurar.
- "Öğe bulunamadı" görülürse: davet o hesapla kabul edilmemiş, Play Store'da başka hesap
  açık ya da kabul henüz yansımamış. Play Store önbelleğini temizleyip birkaç dakika sonra
  dene; Chrome'da `https://play.google.com/store/apps/details?id=com.ekrembulbul.ezanvakti`
  sayfasından "Yükle" de çalışır.

---

## Yerel derleme ve doğrulama

```bash
flutter build appbundle --release \
  --dart-define=VAKIT_API_BASE_URL=https://ezanvakti.ekrembulbul.com
# çıktı: build/app/outputs/bundle/release/app-release.aab
```
- `--dart-define` verilmezse uygulama yerel geliştirme sunucusuna (`127.0.0.1`) bağlanır,
  vakitler gelmez. CI aynı değeri `VAKIT_API_BASE_URL` repository variable'ından geçer.
- Yerel imza `android/key.properties`'ten okunur (gitignore'da). `storeFile` upload
  keystore'un gerçek yolunu göstermeli. Dosya yoksa ya da yol yanlışsa derleme **hata
  vermez, debug anahtarıyla imzalar**; Play bu AAB'yi reddeder. İmzacıyı kontrol et:
  `keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab`
  çıktısında `CN=Android Debug` olmamalı; parmak izi upload keystore'unkiyle aynı olmalı.

---

## Kurulum kaydı (yeniden kurulum gerekirse)

### 1. Upload keystore (imza anahtarı)
Play **App Signing** kullanır: biz "upload key" ile imzalarız, Google asıl imzayı yönetir.
```bash
keytool -genkey -v -keystore ezanvakti-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
`.jks` ve parolaları repo dışında, güvenli yerde durur. Keystore PKCS12 olduğundan anahtar
parolası keystore parolasıyla aynıdır. `android/key.properties`:
```
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/mutlak/yol/ezanvakti-upload.jks
```

### 2. Play Console'da uygulama ve ilk AAB
fastlane bir kanala yükleyebilmek için uygulamanın Play'de var olması gerekir; **ilk AAB
Console'dan elle** yüklenir (internal testing → Yeni sürüm oluştur). Play App Signing bu
adımda etkinleşir. Hiç yayınlanmamış uygulamaya API yalnız taslak sürüm yükleyebilir;
ilk sürüm elle yayınlandıktan sonra Fastfile `release_status: "completed"` kullanır.

### 3. Service account
1. Google Cloud'da proje aç, **Google Play Android Developer API**'yi etkinleştir.
2. IAM & Admin → Service Accounts → hesap oluştur (rol gerekmez) → Keys → JSON anahtar.
3. Play Console → Kullanıcılar ve izinler → Yeni kullanıcı davet et → service account
   e-postası → uygulama izinleri: *Uygulama bilgilerini görüntüleme* + *Uygulamaları test
   kanallarına yayınlama*. Yönetici ve üretime yayınlama izni verilmez.

Bağlantıyı yerelde, hiçbir şey yayınlamadan denemek için Play API'de bir edit açıp
internal kanalı okumak ve edit'i silmek yeterli (fastlane `validate_play_store_json_key`
de aynı işi görür; sistem Ruby'sinde bundler sürümü uymadığı için yerelde çalışmayabilir).

### 4. GitHub Secrets
Repo → Settings → Secrets and variables → Actions:

| Secret | Değer |
|--------|-------|
| `ANDROID_KEYSTORE_BASE64` | upload `.jks`'in base64'ü |
| `ANDROID_KEYSTORE_PASSWORD` | keystore parolası |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | anahtar parolası |
| `PLAY_SERVICE_ACCOUNT_JSON_BASE64` | service account JSON'unun base64'ü |

```bash
base64 -i ezanvakti-upload.jks | tr -d '\n' | gh secret set ANDROID_KEYSTORE_BASE64
base64 -i service-account.json | tr -d '\n' | gh secret set PLAY_SERVICE_ACCOUNT_JSON_BASE64
```

---

## Mağaza içeriği (App content / Data safety)
- Mağaza metinleri ve App content cevapları: `store/play/LISTING.md`
- Data Safety cevapları: `docs/PLAY_DATA_SAFETY.md`
- Gizlilik politikası: https://ezanvakti.ekrembulbul.com/privacy (kaynak `server/internal/httpapi/privacy.html`, sunucu dağıtımıyla yayına çıkar)
- Görseller: `store/play/icon_512.png`, `store/play/feature_graphic_1024x500.png`
- Ekran görüntüleri: emülatör/cihazdan alınır (en az 2 telefon görüntüsü)

## İzin beyanları (App content)
Manifest Play'in beyan istediği izinleri içerir; ilk sürüm incelemesinden önce doldur
(metinler `store/play/LISTING.md`'de):
- **Foreground service (`mediaPlayback`):** ezan sesini çalan alarm servisi. İşlev
  açıklaması, ertelenirse kullanıcıya etkisi ve özelliği gösteren **video bağlantısı** istenir.
- **Full-screen intent:** uygulama alarm işlevli olduğu için "core functionality" beyanı.
- **Exact alarm (`USE_EXACT_ALARM`):** yalnız çekirdek işlevi tam zamanlı alarm olan
  uygulamalara izin verilir; Console beyan isterse vakit alarmı gerekçe gösterilir.

## ⚠️ Bireysel hesap şartı
Production'a (halka açık) çıkmadan önce **en az 12 testçi × 14 gün kapalı test** zorunlu.
Internal testing bu şarta tabi değildir.
