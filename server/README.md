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

## Sunucuya kurulum

    git clone <repo> && cd ezanvakti/server/deploy
    cp .env.example .env && chmod 600 .env     # kimlik bilgilerini doldur (API onayı sonrası)
    docker compose up -d --build
    docker compose run --rm vakit sync places
    docker compose run --rm vakit sync prayer-times --batch 150
    docker compose run --rm vakit sync religious-days
    docker compose run --rm vakit sync daily-content --ahead 7
    curl -s http://127.0.0.1:8080/v1/health

Kaynak `web` iken (API onayı öncesi) `religious-days` ve `daily-content` atlanır; vakitler cari yıl
için kayan 31 günlük pencereyle birikir, gelecek yıl tek seferde tamamlanır.

### Cron (host)

    0 3 * * *   cd /srv/ezanvakti/server/deploy && docker compose run --rm vakit sync prayer-times --batch 150 >> /var/log/vakit-sync.log 2>&1
    0 4 * * 1   cd /srv/ezanvakti/server/deploy && docker compose run --rm vakit sync places >> /var/log/vakit-sync.log 2>&1
    0 4 1 * *   cd /srv/ezanvakti/server/deploy && docker compose run --rm vakit sync religious-days >> /var/log/vakit-sync.log 2>&1
    15 0 * * *  cd /srv/ezanvakti/server/deploy && docker compose run --rm vakit sync daily-content --ahead 7 >> /var/log/vakit-sync.log 2>&1
    30 5 * * 0  cd /srv/ezanvakti/server/deploy && docker compose run --rm vakit sync verify >> /var/log/vakit-sync.log 2>&1

### Cloudflare Tunnel

`cloudflared` ingress: `api.<domain>` → `http://127.0.0.1:8080` (bkz. `deploy/cloudflared.example.yml`).
Cloudflare panelinde:

- **Cache Rule:** `(http.host eq "api.<domain>" and starts_with(http.request.uri.path, "/v1/"))` →
  Eligible for cache, origin `Cache-Control`'e uy. (JSON varsayılan olarak cache'lenmez; kural şart.)
- **Rate limiting:** `/v1/*` için IP başına 60 istek / 10 sn.

Doğrulama: `curl -I https://api.<domain>/v1/health` → 200; ikinci istekte vakit ucunda `cf-cache-status: HIT`.

## Veri düzeni ve yedek

`VAKIT_DATA_DIR` altında: yayın dosyaları (`places/`, `prayer-times/`, `religious-days/`, `daily-content/`)
ve `state/vakit.db` (SQLite, WAL: yanında `-wal`/`-shm` olabilir) + `state/awqat_token.json`.
Şema gömülü migration'larla sürümlenir; `serve` ve `sync` açılışta bekleyenleri uygular.
Yedek: sync çalışmıyorken klasörü kopyalamak yeter (`docker compose run --rm vakit sync verify` çıkışını bekle).

## Veri lisansı

İlçe koordinatları © OpenStreetMap contributors (ODbL), `assets/tr_cities_geo.json`.
Vakit, dinî gün ve içerik verisi: T.C. Diyanet İşleri Başkanlığı.
