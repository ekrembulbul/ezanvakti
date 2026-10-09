# vakit-api

Diyanet Awqat Salah verisini (yer listeleri, ilçe bazlı yıllık vakitler + Hicri, dinî günler,
günlük içerik) ve Diyanet'in cuma/bayram hutbelerini çekip doğrulayan ve `/v1` sözleşmesiyle sunan Go sunucusu.
Tasarım: `docs/superpowers/specs/2026-09-15-vakit-api-sunucu-design.md`; hutbe: `docs/superpowers/specs/2026-10-01-hutbe-design.md`.

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
    GET /v1/daily-content/{YYYY-MM-DD}         günün ayet/hadis/duası (Türkiye günü, son 7 gün)
    GET /v1/sermons                            son 20 cuma/bayram hutbesi, tarih azalan; en/ar PDF bağlantıları (15 dk cache)
    GET /v1/sermons/{id}                       Türkçe hutbe metni, id `2026-09-25-cuma` biçiminde (1 saat cache; bilinmeyen 404)
    GET /v1/health

Gizlilik: arama metni ve koordinat loglanmaz; koordinat ~100 m'ye yuvarlanır, saklanmaz.

## Komutlar

    vakit serve
    vakit sync places
    vakit sync prayer-times [--year Y]... [--batch N]
    vakit sync religious-days [--year Y]...
    vakit sync daily-content
    vakit sync sermons        # Diyanet Haber + Din Hizmetleri; VAKIT_SOURCE'tan bağımsız
    vakit sync quota          # yalnız awqat kaynağı
    vakit sync verify         # ağ yok; sorun varsa çıkış kodu 1
    vakit version

Çıkış kodları: `0` başarı (kota/batch nedeniyle erken bitiş dahil, log'da `stopped`), `1` iş hatası, `2` kullanım hatası.

## Dağıtım (GitHub Actions)

`main`'e `server/` değişikliği gelince `.github/workflows/server-deploy.yml` çalışır (elle: Actions → server-deploy →
Run workflow): Go testleri → `ghcr.io/ekrembulbul/vakit-api:sha-<commit>` imajı → SSH ile sunucuda `ezanvakti`
kullanıcısına dağıtım → `127.0.0.1:3060` ve `https://ezanvakti.ekrembulbul.me` sağlık kontrolü. `dev` ve PR'larda
yalnız `server-ci` (test + imaj derleme) koşar.

`production` ortamının secret'ları (Settings → Environments → production; dağıtım dalı yalnız `main`). Başka daldan
başlatılan ya da değiştirilmiş bir iş akışı bunlara ulaşamaz. Repo public olduğundan sunucu adresi de secret:

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

Senkron işleri dağıtımda çalışmaz, `deploy/crontab` zamanlar (UTC; işler `flock` ile aynı
`sync.lock` kilidinde sıraya girer, çakışan iki iş durumu birbirinin üzerine yazmasın): vakitler her gün 03:00
(`VAKIT_SYNC_BATCH` kadar ilçe-yıl), yer listesi pazartesi, dinî günler ayın 1'i, `verify` pazar.
`daily-content` Türkiye saatiyle 00:05–06:05 arası saat başı: tarihsiz `GET /api/DailyContent`
ucu kullanılır (hesabın `Developer` rolü tarihli uca yetkili değil, HTTP 403). Gelen `dayOfYear`
Türkiye günüyle eşleşmezse yazılmaz, sonraki saatte yeniden denenir; o günün dosyası varsa
istek atılmaz. 7 günden eski günler silinir.
`sermons` her gün TR 22:00 (UTC 19:00), ek olarak perşembe 17:00 ve cuma 11:30 (UTC 14:00 / 08:30):
Diyanet Haber hutbe RSS'i (`/rss/hutbeler`, son 20 kayıt) okunur; metni olan ve günü geçmiş hutbenin
sayfası yeniden istenmez, hutbe günü ve öncesinde (cuma sabahı düzeltmeleri için) her çalışmada istenir.
Türkçe metin sayfadaki JSON-LD `articleBody`'den alınır, değiştirilmez; 500 karakterden kısa ya da
çözülemeyen sayfada eski metin korunur. İngilizce/Arapça PDF adresleri Din Hizmetleri ana sayfası ve hutbe
sayfasından (`/Detay/…`) bulunur, PDF kopyalanmaz; eksikse hutbe tarihinden 7 gün geçene kadar yeniden aranır.
RSS okunamazsa ya da hiç hutbe çözülemezse dosyalara dokunulmaz, iş çıkış kodu 1 ile biter. Listeden düşen
hutbenin metni silinir. İstekler arası en az 1 sn, `User-Agent: vakit-api/1.0 (+https://ezanvakti.ekrembulbul.me)`;
Din Hizmetleri'nin robots.txt ile kapattığı `/kategoriler/` hiç istenmez. Sağlık ucundaki `datasets.sermons`
(`updatedAt`, `count`) dizin dosyasından okunur.

Elle işlem (`ezanvakti` olarak, `~/vakit-api` içinde):

    docker compose run --rm -T vakit sync places              # ilk kurulumda cron'u beklemeden
    docker compose run --rm -T vakit sync prayer-times --batch 150
    docker compose run --rm -T vakit sync sermons             # ilk hutbe yüklemesi (~40 istek, ~1 dk)
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

`VAKIT_DATA_DIR` altında: yayın dosyaları (`places/`, `prayer-times/`, `religious-days/`, `daily-content/`,
`sermons/` — `index.json` + hutbe başına `{id}.json`)
ve `state/vakit.db` (SQLite, WAL: yanında `-wal`/`-shm` olabilir) + `state/awqat_token.json`.
Şema gömülü migration'larla sürümlenir; `serve` ve `sync` açılışta bekleyenleri uygular.
Yedek: sync çalışmıyorken klasörü kopyalamak yeter (`docker compose run --rm vakit sync verify` çıkışını bekle).

## Veri lisansı

İlçe koordinatları © OpenStreetMap contributors (ODbL), `assets/tr_cities_geo.json`.
Vakit, dinî gün ve içerik verisi: T.C. Diyanet İşleri Başkanlığı.
Hutbeler: Diyanet İşleri Başkanlığı yayınları — Türkçe metin Diyanet Haber'den (künye: "ajans kaynaklı haberler
hariç diğer haberlerin AKTİF LİNK kaynak belirtilerek kullanılması serbesttir"; her hutbe `sourceUrl` ile kaynak
sayfasına bağlanır), çeviri PDF'leri Din Hizmetleri Genel Müdürlüğü sitesindeki adresleriyle.
