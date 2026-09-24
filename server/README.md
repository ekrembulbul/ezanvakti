# vakit-api

Diyanet Awqat Salah verisini (yer listeleri, ilçe bazlı yıllık vakitler + Hicri, dinî günler,
günlük içerik) çekip doğrulayan ve `/v1` sözleşmesiyle sunan Go sunucusu.
Tasarım: `docs/superpowers/specs/2026-09-15-vakit-api-sunucu-design.md`.

## Geliştirme

    brew install go
    cd server && make vet test
    make smoke            # ağ: web kaynağıyla uçtan uca

## Ortam değişkenleri

| Değişken | Varsayılan | Açıklama |
|---|---|---|
| `AWQAT_EMAIL` / `AWQAT_PASSWORD` | — | Diyanet hesabı; yalnız sunucuda |
| `AWQAT_BASE_URL` | `https://awqatsalah.diyanet.gov.tr` | |
| `VAKIT_SOURCE` | `awqat` (kimlik yoksa `web`) | `awqat` \| `web` |
| `VAKIT_DATA_DIR` | `./data` | yayın dosyaları |
| `VAKIT_ADDR` | `127.0.0.1:8080` | |
| `VAKIT_ENABLED_COUNTRIES` | `2` | Diyanet ülke id'leri, virgülle |
| `VAKIT_SYNC_BATCH` | `150` | çalıştırma başına en çok çekim |
| `VAKIT_SYNC_INTERVAL` | `500ms` | istekler arası bekleme (web kaynağında en az 1 s) |
| `VAKIT_LOG_LEVEL` | `info` | `debug` \| `info` \| `warn` \| `error` |

## Uygulamanın kullandığı uçlar

    GET /v1/places/search?q=sile&limit=10      il/ilçe arama (Türkçe duyarsız, eşanlamlı: Kadıköy → İstanbul)
    GET /v1/places/resolve?lat=41.17&lon=29.6  GPS → en yakın ilçe (60 km dışı: 404 NO_COVERAGE)
    GET /v1/prayer-times/{cityId}/{year}       yıllık vakitler + Hicri
    GET /v1/religious-days/{year}              dinî günler (API onayı sonrası)
    GET /v1/daily-content/{YYYY-MM-DD}         günün ayet/hadis/duası (API onayı sonrası)
    GET /v1/health

Gizlilik: arama metni ve koordinat loglanmaz; koordinat ~100 m'ye yuvarlanır, saklanmaz.

## Komutlar

    vakit serve
    vakit sync places
    vakit sync prayer-times [--year Y]... [--batch N]
    vakit sync religious-days [--year Y]...
    vakit sync daily-content [--ahead N]
    vakit sync quota          # yalnız awqat kaynağı
    vakit sync verify         # ağ yok; sorun varsa çıkış kodu 1
    vakit version

Çıkış kodları: `0` başarı (kota/batch nedeniyle erken bitiş dahil, log'da `stopped`), `1` iş hatası, `2` kullanım hatası.

## Dağıtım (GitHub Actions)

`main`'e `server/` değişikliği gelince `.github/workflows/server-deploy.yml` çalışır (elle: Actions → server-deploy →
Run workflow): Go testleri → `ghcr.io/ekrembulbul/vakit-api:sha-<commit>` imajı → SSH ile sunucuda `ezanvakti`
kullanıcısına dağıtım → `127.0.0.1:3060` ve `https://ezanvakti.ekrembulbul.me` sağlık kontrolü. `dev` ve PR'larda
yalnız `server-ci` (test + imaj derleme) koşar.

Repository secret'ları (Settings → Secrets and variables → Actions); repo public olduğundan sunucu adresi de secret:

| Secret | İçerik |
|---|---|
| `SERVER_HOST` | sunucunun IP'si |
| `SERVER_SSH_KEY` | `ezanvakti` kullanıcısının deploy anahtarı (özel anahtar; açık anahtar sunucuda `restrict` ile) |
| `SERVER_KNOWN_HOSTS` | `ssh-keyscan -t ed25519 <ip>` satırı |
| `AWQAT_EMAIL`, `AWQAT_PASSWORD` | Diyanet hesabı; tek tırnak ve satır sonu içeremez |

Sunucuda (`ezanvakti` kullanıcısı, docker grubunda, sudo yok) her dağıtım şunları yazar:

    ~/vakit-api/compose.yml   ← deploy/compose.prod.yml (port, ayarlar, log sınırı)
    ~/vakit-api/.env          imaj etiketi + kullanıcı uid/gid (compose için)
    ~/vakit-api/vakit.env     kimlik bilgileri (secret'lardan, 0600)
    ~/vakit-api/crontab       deploy/crontab → kullanıcının crontab'ı olarak kurulur
    ~/vakit-api/data/         kalıcı veri (dağıtım dokunmaz)
    ~/vakit-api/logs/sync.log cron çıktısı

Senkron işleri dağıtımda çalışmaz, `deploy/crontab` zamanlar (UTC): vakitler her gün 03:00
(`VAKIT_SYNC_BATCH` kadar ilçe-yıl), yer listesi pazartesi, dinî günler ayın 1'i, `verify` pazar.
`daily-content` yok: hesabın `Developer` rolü tarihli içerik ucuna yetkili değil (HTTP 403).

Elle işlem (`ezanvakti` olarak, `~/vakit-api` içinde):

    docker compose run --rm -T vakit sync places              # ilk kurulumda cron'u beklemeden
    docker compose run --rm -T vakit sync prayer-times --batch 150
    docker compose run --rm -T vakit sync quota
    docker compose logs --tail 100 vakit
    tail -n 50 logs/sync.log

Yerelde imajla deneme: `deploy/compose.yml` (kaynaktan derler, `deploy/vakit.env` okur).

### Cloudflare Tunnel

Tünel Cloudflare panelinden yönetiliyor (token'lı `cloudflared`, yerel config yok): Zero Trust → Networks →
Tunnels → Published application `ezanvakti.ekrembulbul.me` → **HTTP** `localhost:3060`. Origin düz HTTP konuşur;
servis türü HTTPS seçilirse tünel origin'e TLS ile bağlanmaya çalışır ve istekler 502 döner. Yerel config'li
tünel için `deploy/cloudflared.example.yml`. Cloudflare panelinde:

- **Cache Rule:** `(http.host eq "ezanvakti.ekrembulbul.me" and starts_with(http.request.uri.path, "/v1/"))` →
  Eligible for cache, origin `Cache-Control`'e uy. (JSON varsayılan olarak cache'lenmez; kural şart.)
- **Rate limiting:** `/v1/*` için IP başına 60 istek / 10 sn.

Doğrulama: `curl -I https://ezanvakti.ekrembulbul.me/v1/health` → 200; ikinci istekte vakit ucunda `cf-cache-status: HIT`.

## Diyanet API kotası

2026-09-24'te canlı doğrulandı. Sınırlar uç + parametre bazında sayılır (`vakit sync quota` çıktısında
`lines[].parameter`, ör. `cityId:9146`): günde 10, hesabın ilk 15 gününde 100; `PrayerTime/DateRange` ayrıca
ilçe başına ayda 10. İlçe-yıl başına tek `DateRange` yeter, yani sınırlar senkron için dar değil;
`VAKIT_SYNC_BATCH` nezaket sınırıdır. `IslamicReligiousDay` kotaya sayılmaz. Erişim token'ı 45 dk, refresh 7 gün.

## Veri düzeni ve yedek

`VAKIT_DATA_DIR` altında: yayın dosyaları (`places/`, `prayer-times/`, `religious-days/`, `daily-content/`)
ve `state/vakit.db` (SQLite, WAL: yanında `-wal`/`-shm` olabilir) + `state/awqat_token.json`.
Şema gömülü migration'larla sürümlenir; `serve` ve `sync` açılışta bekleyenleri uygular.
Yedek: sync çalışmıyorken klasörü kopyalamak yeter (`docker compose run --rm vakit sync verify` çıkışını bekle).

## Veri lisansı

İlçe koordinatları © OpenStreetMap contributors (ODbL), `assets/tr_cities_geo.json`.
Vakit, dinî gün ve içerik verisi: T.C. Diyanet İşleri Başkanlığı.
