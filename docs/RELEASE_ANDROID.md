# Android Sürüm Çıkarma (Play internal testing)

iOS TestFlight akışının Android karşılığı. GitHub Actions, AAB derleyip
**Play Console internal testing** track'ine yükler (fastlane `supply`).

> Workflow `vX.Y.Z` ve `android-vX.Y.Z` tag'leriyle ya da elle (`workflow_dispatch`)
> tetiklenir. `PLAY_SERVICE_ACCOUNT_JSON_BASE64` ve `ANDROID_KEYSTORE_BASE64`
> secret'larından biri yoksa yükleme işi kırmızı olmadan **atlanır**; aşağıdaki
> kurulum bitene kadar Android sürümü çıkmaz.

---

## Bir kerelik kurulum

### 1. Upload keystore (imza anahtarı)
Play **App Signing** kullanır: sen "upload key" ile imzalarsın, Google asıl imzayı yönetir.

```bash
keytool -genkey -v -keystore ~/ezanvakti-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
Bu `.jks` dosyasını ve parolalarını güvenli sakla (repo dışı). Keystore PKCS12
olduğundan anahtar parolası keystore parolasıyla aynıdır. Yerelde derlemek için
`android/key.properties` (gitignore'da) oluştur:
```
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/Users/KULLANICI/ezanvakti-upload.jks
```

### 2. Play Console'da uygulamayı oluştur
Hesap doğrulaması bitince → Play Console → **Create app** → paket adı
`com.ekrembulbul.ezanvakti`.

### 3. İlk AAB'yi ELLE yükle
fastlane bir track'e yükleyebilmek için uygulamanın ve paket adının Play'de **var olması**
gerekir. Bu yüzden **ilk AAB'yi Play Console arayüzünden** yükle (internal testing →
Create release). Bu adımda **Play App Signing** etkinleşir. Sonraki yüklemeler CI ile olur.

Yerelde AAB üretmek:
```bash
flutter build appbundle --release \
  --dart-define=VAKIT_API_BASE_URL=https://ezanvakti.ekrembulbul.me
# çıktı: build/app/outputs/bundle/release/app-release.aab
```
- `--dart-define` verilmezse uygulama yerel geliştirme sunucusuna (`127.0.0.1`) bağlanır,
  vakitler gelmez. CI aynı değeri `VAKIT_API_BASE_URL` repository variable'ından geçer.
- `android/key.properties` yoksa derleme hata vermez, **debug anahtarıyla** imzalar;
  Play bu AAB'yi reddeder. Yüklemeden önce imzayı kontrol et:
  `jarsigner -verify -certs build/app/outputs/bundle/release/app-release.aab`
  çıktısında `CN=Android Debug` olmamalı.

### 4. Play service account (CI'nin yükleme yetkisi)
1. Play Console → **Users and permissions** → API erişimi / Google Cloud projesi bağla
2. Google Cloud → bir **service account** oluştur → JSON anahtarı indir
3. Play Console'da bu service account'a **Release/Internal testing** yetkisi ver

### 5. GitHub Secrets
Repo → Settings → Secrets and variables → Actions:

| Secret | Değer |
|--------|-------|
| `ANDROID_KEYSTORE_BASE64` | upload `.jks`'in base64'ü |
| `ANDROID_KEYSTORE_PASSWORD` | keystore parolası |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | anahtar parolası |
| `PLAY_SERVICE_ACCOUNT_JSON_BASE64` | service account JSON'unun base64'ü |

Base64 üretmek (macOS):
```bash
base64 -i ~/ezanvakti-upload.jks | pbcopy
base64 -i ~/play-service-account.json | pbcopy
```

---

## Kullanım (kurulum bitince)
- **Tag-tetikli:** `main` üzerinde `./scripts/release_tag.sh` (`vX.Y.Z`, iOS + Android)
  ya da `./scripts/release_tag.sh X.Y.Z --android` (`android-vX.Y.Z`, yalnız Android).
- **Elle:** GitHub → Actions → **Android Play (internal)** → Run workflow.

## Mağaza içeriği (App content / Data safety)
- Data Safety cevapları: `docs/PLAY_DATA_SAFETY.md`
- Gizlilik politikası: `docs/privacy.html` (host edilip URL girilir)
- Görseller: `store/play/icon_512.png`, `store/play/feature_graphic_1024x500.png`
- Ekran görüntüleri: emülatör/cihazdan alınır (en az 2 telefon görüntüsü)

## İzin beyanları (App content)
Manifest Play'in beyan istediği izinleri içerir; ilk sürüm incelemesinden önce doldur:
- **Foreground service (`mediaPlayback`):** ezan sesini çalan alarm servisi. Her tür için
  işlev açıklaması, ertelenirse kullanıcıya etkisi ve özelliği tetikleyen adımları
  gösteren **video bağlantısı** istenir.
- **Full-screen intent:** uygulama alarm işlevli olduğu için "core functionality"
  beyanı yapılır; tam ekran alarm ekranı bu izne dayanır.
- **Exact alarm (`USE_EXACT_ALARM`):** Play yalnız çekirdek işlevi tam zamanlı alarm
  olan uygulamalara izin verir; Console beyan isterse vakit alarmı gerekçe gösterilir.

## ⚠️ Bireysel hesap şartı
Production'a (halka açık) çıkmadan önce **en az 12 testçi × 14 gün kapalı test** zorunlu.
Internal testing hızlıdır; bu şart yalnızca production erişimi içindir.
