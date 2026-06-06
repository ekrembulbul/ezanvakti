# iOS Sürüm Çıkarma (TestFlight)

İki yol var:

1. **Yerel** — `scripts/release_ios.sh` ile kendi Mac'inde derleyip yükle.
2. **GitHub Actions (önerilen)** — `scripts/release_tag.sh` ile tag at; bulutta otomatik derlenip TestFlight'a yüklenir.

Bu belge 2. yolun **bir kerelik kurulumunu** ve günlük kullanımını anlatır.

---

## Akış (kurulum bitince)

```bash
# main dalında, çalışma ağacı temiz
# (önce CHANGELOG'u elle güncelle)
./scripts/release_tag.sh 0.1.9
```

Bu komut: pubspec sürümünü günceller → commit'ler → `v0.1.9` tag'i atar → push eder.
Tag push'u `.github/workflows/ios-testflight.yml`'i tetikler; GitHub bir macOS makinesinde
IPA'yı derler ve TestFlight'a yükler. İlerlemeyi **GitHub repo → Actions → "iOS TestFlight"**
sekmesinden izleyebilirsin.

Build numarası argümansız `+1` artar; tam kontrol için `./scripts/release_tag.sh 0.1.9+10`.

---

## Bir kerelik kurulum — GitHub Secrets

GitHub repo → **Settings → Secrets and variables → Actions → New repository secret**
ile aşağıdakileri ekle:

| Secret adı | Değer |
|---|---|
| `IOS_DIST_CERT_P12` | `Certificates.p12`'nin **base64**'ü (aşağıdaki komut) |
| `IOS_DIST_CERT_PASSWORD` | `.p12` dışa aktarma parolası |
| `ASC_KEY_ID` | API anahtarı Key ID — `X4PW7D9887` |
| `ASC_ISSUER_ID` | App Store Connect → Users and Access → Integrations → "Issuer ID" |
| `ASC_KEY_P8_BASE64` | `AuthKey_X4PW7D9887.p8`'in **base64**'ü |
| `APPLE_TEAM_ID` | `MW25H55RX4` |

Base64 üretmek (macOS):

```bash
base64 -i ~/Downloads/Certificates.p12 | pbcopy            # IOS_DIST_CERT_P12
base64 -i ~/.appstoreconnect/private_keys/AuthKey_X4PW7D9887.p8 | pbcopy   # ASC_KEY_P8_BASE64
```

> Hiçbir secret/anahtar repoya konmaz; yalnızca GitHub Secrets'ta şifreli durur.

---

## Nasıl çalışır (özet)

- **Tetik:** `v*` tag push'u.
- **Ortam:** GitHub `macos-15` runner, Flutter 3.44.1.
- **İmzalama:** `fastlane` dağıtım sertifikasını geçici keychain'e aktarır; App Store
  dağıtım profilini App Store Connect API anahtarıyla otomatik üretir (`sigh`).
- **Derleme/yükleme:** `build_app` (app-store) → `upload_to_testflight`.

Yapılandırma dosyaları: `.github/workflows/ios-testflight.yml`, `ios/fastlane/Fastfile`,
`ios/fastlane/Appfile`, `ios/Gemfile`.

---

## Notlar

- İlk çalıştırmada iOS CI imzalaması genelde 1-2 küçük ayar gerektirir; Actions
  loglarındaki hataya göre düzeltilir.
- TestFlight'ta build "Processing" → "Ready to Test" olunca test edilebilir.
- Public App Store sürümüne geçerken pubspec'i `1.0.0`'a çek ve App Store Connect'te
  sürümü "Submit for Review" ile gönder.
