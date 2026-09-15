# vakit-api — Diyanet verisini barındıran sunucu (Spec A)

- **Tarih:** 2026-09-15 · **Durum:** taslak, kullanıcı incelemesinde · **Branch:** `feature/vakit-api`
- **Bağlam:** [Diyanet vakit farkı](../../investigations/2026-09-14-diyanet-vakit-farki.md),
  [Aladhan–resmi tablo karşılaştırması](../../investigations/2026-09-15-aladhan-resmi-tablo-farklari.md)
- **Eşi:** Spec B (uygulama tarafı) bu belgedeki `/v1` sözleşmesine bağlıdır; ayrı yazılır.

## Amaç

Uygulama, Diyanet İşleri Başkanlığı'nın yayınladığı vakitleri **birebir** göstermeli. Aladhan
`method=13` bir taklittir (İkindi/Akşam/Yatsı ±1–2 dk, mevsimsel). Diyanet'in resmî Awqat Salah
REST servisi cihazdan çağrılamaz: kimlik bilgisi paylaşılamaz, kota endpoint+parametre başına
10 istektir (ilk 15 gün 100; kılavuzun eski metninde 5) ve kılavuz (s.5) geliştiricinin veriyi **kendi imkânlarıyla host etmesini**
şart koşar. `vakit-api` bu barındırma katmanıdır: Diyanet'ten çeker, doğrular, dosya olarak
yayınlar; uygulama yalnızca bu sunucuyla konuşur.

## Kararlar

| # | Karar | Gerekçe |
|---|---|---|
| K1 | Tek veri kaynağı Diyanet; ülke kapsamı sunucu config'i, başlangıçta yalnız Türkiye (`countryId=2`) | Birebir uyum yalnız resmî veriyle; Diyanet 202 ülkeyi aynı hiyerarşiyle veriyor, açmak konfigürasyon |
| K2 | Dil Go, tek binary `vakit` (`serve` / `sync` alt komutları), yalnız stdlib (+ `golang.org/x/net/html`) | Küçük imaj, sıfır çalışma zamanı bağımlılığı, kullanıcı tercihi |
| K3 | Depolama: JSON dosyaları (`data/`), veritabanı yok | Tek erişim deseni "kayıt + yıl"; yedek = kopya; ETag doğal; Faz 3 (token deposu) gelince DB eklenir |
| K4 | Kaynak soyutlaması: `awqat` (resmî API, birincil) ve `web` (namazvakitleri.diyanet.gov.tr ilçe sayfası, onay öncesi ve fesih fallback'i) aynı `Source` arayüzü | API onayı beklenmeden çalışır; form "tek taraflı fesih" hakkı içeriyor |
| K5 | Reverse proxy yok; Go yalnız `127.0.0.1:8080`'e bind, `cloudflared` tüneli `api.<domain>` → origin | Kullanıcının mevcut altyapısı; TLS/DNS/WAF/cache Cloudflare'de |
| K6 | Sözleşme `/v1` altında, sürüm kırıcı değişiklik `/v2` | Uygulama mağaza sürümleri eski sözleşmeyi yıllarca çağırır |
| K7 | Koordinatlar Diyanet'te yok → tek seferlik OSM/Nominatim eşlemesi `server/data/tr_cities_geo.json` olarak commit'lenir, elle gözden geçirilir | Uygulamada GPS → en yakın ilçe ve kıble için gerekli; ODbL atfı uygulamaya eklenir |

## Kapsam

### VAK.1 — `/v1` sözleşmesi (uygulamanın gördüğü tek yüzey)

Tüm yanıtlar `application/json; charset=utf-8`, yalnız `GET`. Başarılı gövdeler aşağıdaki gibidir;
liste uçları sayfalama gerektirmez (en büyük dosya ~970 kayıt).

```
GET /v1/places/countries
  [{ "id": 2, "name": "TÜRKİYE", "nameEn": "TURKEY", "enabled": true }, ...]
  → tüm Diyanet ülkeleri listelenir; uygulama yalnız enabled=true olanları gösterir

GET /v1/places/countries/{countryId}/states
  [{ "id": 539, "name": "İSTANBUL", "countryId": 2 }, ...]

GET /v1/places/states/{stateId}/cities
  [{ "id": 9541, "name": "İSTANBUL", "stateId": 539, "countryId": 2,
     "latitude": 41.0082, "longitude": 28.9784,
     "qiblaAngle": 151, "distanceToKaaba": 2400 }, ...]
  → latitude/longitude K7'den; qiblaAngle/distanceToKaaba CityDetail'den; yoksa null

GET /v1/places/tr/cities
  → Türkiye'nin tüm ilçeleri tek dosyada, il adıyla zenginleştirilmiş
    [{ ...city, "stateName": "İSTANBUL" }]
  → uygulamadaki seçici, GPS→ilçe eşlemesi ve gömülü asset bu dosyadan üretilir

GET /v1/prayer-times/{cityId}/{year}
  { "schemaVersion": 1, "source": "diyanet", "generatedAt": "2026-09-15T20:00:00Z",
    "cityId": 9541, "year": 2026,
    "days": [
      { "date": "2026-09-15",
        "hijri": { "day": 4, "month": 4, "year": 1448, "monthName": "Rebiulahir" },
        "fajr": "05:11", "sunrise": "06:37", "dhuhr": "13:04",
        "asr": "16:35", "maghrib": "19:22", "isha": "20:43",
        "astronomicalSunrise": "06:30", "astronomicalSunset": "19:15",
        "qiblaTime": "10:52", "gmtOffset": 3 }, ... ] }
  → saatler yerel duvar saati "HH:MM"; gmtOffset Diyanet'in gün bazlı değeri (DST'li ülkeler için)
  → astronomical*/qiblaTime yalnız API kaynağında var; web kaynağında null

GET /v1/religious-days/{year}
  [{ "id": 1, "date": "2026-01-15", "name": "Miraç Kandili", "isSpecial": true,
     "hijri": { "day": 26, "month": 7, "year": 1447, "monthName": "Recep" } }, ...]

GET /v1/daily-content/{date}          (date = YYYY-MM-DD)
  { "date": "2026-09-15", "dayOfYear": 258,
    "verse": "...", "verseSource": "(Şu'arâ, 42/29)",
    "hadith": "...", "hadithSource": "(Tirmizî, \"Birr\", 15)",
    "prayer": "...", "prayerSource": null }

GET /v1/health                        (cache'lenmez)
  { "status": "ok", "version": "0.1.0+abc1234", "uptimeSeconds": 1234,
    "datasets": {
      "places":        { "updatedAt": "...", "countries": 202, "enabledCountries": [2], "cities": 970 },
      "prayerTimes":   { "2026": { "cities": 970, "complete": true, "updatedAt": "..." },
                         "2027": { "cities": 412, "complete": false, "updatedAt": "..." } },
      "religiousDays": { "years": [2026, 2027], "updatedAt": "..." },
      "dailyContent":  { "days": 258, "updatedAt": "..." } } }
```

Önbellek başlıkları: `ETag` (içeriğin SHA-256'sının ilk 16 hex'i, zayıf değil), `If-None-Match` →
`304`. `Cache-Control: public, max-age=86400, stale-while-revalidate=604800` (vakit, dini gün,
günlük içerik); yer listeleri `max-age=604800`. `/v1/health` → `Cache-Control: no-store`.

Hata zarfı (CLAUDE.md standardı), her zaman JSON:

```json
{ "error": { "code": "NOT_FOUND", "message": "prayer times for city 9541 year 2031 are not published" } }
```

| Durum | Kod |
|---|---|
| 400 | `INVALID_PARAMETER` — yıl 2000–2100 dışı, tarih biçimi bozuk, id sayı değil |
| 404 | `NOT_FOUND` — bilinmeyen yol, ilçe, yıl, tarih |
| 405 | `METHOD_NOT_ALLOWED` — GET/HEAD dışı |
| 500 | `INTERNAL` — dosya okunamadı; ayrıntı yalnız log'da |

### VAK.2 — Diyanet Awqat Salah istemcisi (`internal/awqat`)

Kaynaklar: site sayfası, kılavuz PDF (s.3–12) ve `https://awqatsalah.diyanet.gov.tr/openapi/v1.json`.
Taban adres `https://awqatsalah.diyanet.gov.tr`. Her yanıt `{ "data": T, "success": bool, "message": string|null }`
zarfındadır; `success=false` ya da HTTP ≠ 200 hata sayılır ve `message` loglanır.

| Kullanım | Uç | Not |
|---|---|---|
| Giriş | `POST /Auth/Login` `{ "email", "password" }` → `data.accessToken`, `data.refreshToken` | JWT; süre `exp` claim'inden okunur (site 45 dk, kılavuz 30 dk diyor — sabit yazılmaz) |
| Yenileme | `GET /Auth/RefreshToken/{refreshToken}` → yeni çift | Refresh 7 gün, her kullanımda döner; **7 gün kullanılmazsa geçersiz** → tam giriş. Dosyada saklanır (`data/state/awqat_token.json`, `0600`) |
| Ülkeler | `GET /api/v2/Place/Countries` | v2 üst kırılımı da döner; alan adları canlıda doğrulanır, uymazsa v1'e düşülür |
| İller | `GET /api/v2/Place/States/{countryId}` | yalnız `enabled` ülkeler |
| İlçeler | `GET /api/v2/Place/Cities/{stateId}` | |
| İlçe detayı | `GET /api/Place/CityDetail/{cityId}` → `qiblaAngle`, `distanceToKaaba` | koordinat vermez |
| Yıllık vakit | `POST /api/PrayerTime/DateRange` `{ "cityId", "startDate", "endDate" }` (ISO 8601) | yer bazında ayda 10 istek; Hicri alanları dahil |
| Dini günler | `GET /api/IslamicReligiousDay/ByYear?year=` | |
| Günün içeriği | `GET /api/DailyContent` (bugün) · `GET /api/DailyContent/VerseHadithAndPrayer?date=&language=` (ileri günler) | `language` tam sayı enum, eşlemesi belgelenmemiş — canlıda doğrulanır; varsayılan dil kullanılır |
| Kota | `GET /api/Quota/My?includeUnused=true` | her sync başında çekilir, log'a yazılır, `health`'e özet düşer. Site: her hizmet, parametre bazında ayrı ayrı **10** erişim; ilk 15 gün **100**; `DateRange` yer bazında **ayda 10**. Kotalar günlük/aylık/yıllık ve parametre bazında ayrı tutulur — gerçek pencereler bu uçtan okunur |

Kullanılmayanlar: `Daily/Weekly/Monthly/Eid/Ramadan` (DateRange kapsıyor), `Location/*`
(cihaz başına çağrılamaz), `Admin/*`, `SmartDeviceDatas`, `Place/Mosques*`.

Davranış kuralları:

- Her istekte `Authorization: Bearer <accessToken>`; `exp − 2 dk` geçildiyse önce yenile; `401` → bir kez
  yenile, yine `401` → tam giriş; giriş de başarısızsa sync **durur** ve hata döner (şifre değişmiş olabilir).
- `429` ya da kota mesajı → o çalıştırma **biter**, ilerleme kaydedilir, ertesi cron devam eder. Kısa
  aralıklı yeniden deneme yapılmaz: kota günlük tükenir, beklemek fayda vermez.
- `5xx` / zaman aşımı → en fazla 3 deneme, üstel backoff 2 s → 8 s. Zaman aşımı istek başına 30 s.
- İstekler seri, aralarında `VAKIT_SYNC_INTERVAL` (varsayılan 500 ms) — "sisteme zarar verecek
  istekten kaçınma" taahhüdü.
- Kimlik bilgisi, token ve `Authorization` başlığı **hiçbir log'a yazılmaz**.

### VAK.3 — Web kaynağı (`internal/source/web`)

Onay gelene kadar birincil, sonra fesih/kesinti fallback'i. Yalnız vakit tablosu; yer listesi ve
dini günler için web kaynağı yoktur (bu veriler API onayına kadar `server/data/` altındaki
tohum dosyalarından okunur; bkz. VAK.7).

- `GET https://namazvakitleri.diyanet.gov.tr/tr-TR/{cityId}` → 302 → `/tr-TR/{cityId}/{slug}`; tarayıcı `User-Agent` şart.
- `table#yourTable` ("Yıllık Namaz Vakti"): sütunlar `Miladi Tarih | Hicri Tarih | İmsak | Güneş | Öğle | İkindi | Akşam | Yatsı`;
  bugünden ~15 ay ileriye (bugün: 15 Eyl 2026 → 31 Ara 2027, 403 satır). İstenen yıl için satırlar filtrelenir;
  yıl tam değilse dosya `"complete": false` işaretiyle yazılır ve sonraki sync tamamlar.
- Tarih ayrıştırma: `"15 Eylül 2026 Salı"` → Türkçe ay adı tablosu; Hicri: `"4 Rebiulahir 1448"` → ay adı tablosu
  (Muharrem … Zilhicce, Diyanet yazımıyla) → `{day, month, year, monthName}`.
- Parser, tablo başlığını **doğrular**; başlık beklenenden farklıysa hata verir (HTML değişikliği sessizce yanlış sütun okumaz).
- Web kaynağıyla üretilen dosyada `astronomical*`, `qiblaTime` null; `source` yine `"diyanet"`, ek alan `"via": "web"`.

### VAK.4 — Senkronizasyon işleri (`vakit sync <iş>`)

Hepsi idempotent; her çalıştırma `data/state/sync.json`'daki ilerlemeyi okur/günceller. Cron (host):

```
0 3 * * *   vakit sync prayer-times --year <bu yıl> --year <gelecek yıl> --batch 150
0 4 * * 1   vakit sync places
0 4 1 * *   vakit sync religious-days --year <bu yıl> --year <gelecek yıl>
15 0 * * *  vakit sync daily-content --ahead 7
```

| İş | Yaptığı | Kota bütçesi |
|---|---|---|
| `places` | v2 Countries → enabled ülkeler için States → Cities → her ilçe için CityDetail (yalnız eksik olanlar) → `tr_cities_geo.json` ile birleştir → `places/*` yaz | bootstrap ~1 + 81 + 970; sonrası yalnız değişenler |
| `prayer-times` | enabled ilçelerden verilen yılda dosyası olmayan/`complete=false` olanları sırayla `DateRange` ile çek (1 Ocak–31 Aralık) → doğrula → yaz; `--batch N` kadar sonra dur | ilçe/yıl başına 1; 970 ilçe ≈ 7 günde biter (`batch 150`) |
| `religious-days` | `ByYear` → doğrula (tarihler artan, yıl içinde) → yaz | yılda 1 |
| `daily-content` | bugün + `--ahead` gün için içerik → `daily-content/{yyyy}/{doy}.json`; var olan gün atlanır | günde ≤ 8 |
| `quota` | `Quota/My` çıktısını yazdırır | 1 |
| `verify` | mevcut dosyaları VAK.5 kurallarıyla yeniden doğrular, ağ kullanmaz | 0 |

Kaynak seçimi: `VAKIT_SOURCE=awqat|web` (varsayılan `awqat`; kimlik bilgisi tanımlı değilse
otomatik `web` ve uyarı logu). Yayınlanan dosya her zaman aynı şemadadır; uygulama kaynağı bilmez.

Gelecek yıl verisi Diyanet'te yıl sonuna doğru yayınlanır; `DateRange` boş/kısmi dönerse dosya
yazılmaz, `state`'e "henüz yok" notu düşer, sonraki çalıştırma yeniden dener.

### VAK.5 — Doğrulama (yayın öncesi)

Bir dosya ancak tüm kurallar geçerse `data/` altına atomik olarak yazılır (`.tmp` + `rename`).
Kural ihlali → dosya yazılmaz, `WARN` log (`city`, `year`, kural, örnek gün), `health` içinde
`rejected` sayacı artar.

1. Gün sayısı yılın uzunluğuna eşit (365/366) ya da `complete=false` ile kısmi yazım (yalnız web kaynağı).
2. Tarihler ardışık, tekrar yok.
3. Her gün: `fajr < sunrise < dhuhr < asr < maghrib < isha` (dakika cinsinden, aynı gün).
4. Önceki yılın aynı takvim günü varsa fark ≤ 5 dk (tüm vakitler). Aşarsa reddet: Diyanet'in kendi verisinde
   yıllar arası fark ±1–2 dk'dır; 5 dk üstü ayrıştırma hatasıdır.
5. Hicri: gün 1–30, ay 1–12, ay adı tabloda; ardışık günlerde Hicri gün ya +1 artar ya 1'e döner.
6. Dini günler: tarihler artan, hepsi istenen yılda, ad boş değil.

### VAK.6 — HTTP sunucusu (`vakit serve`)

- Go 1.22+ `net/http` desen yönlendirme (`GET /v1/prayer-times/{cityId}/{year}`); yol parametreleri
  **sayı/tarih olarak ayrıştırılır**, dosya yolu bu değerlerden üretilir — kullanıcı girdisi dosya sistemine
  ham geçmez (path traversal imkânsız).
- Yanıt `data/` altındaki dosyanın ham baytlarıdır; ETag dosya yazılırken hesaplanır ve yanında
  `.etag` olarak saklanır (her istekte hash yok). `HEAD` desteklenir.
- Yalnız `127.0.0.1:8080` (`VAKIT_ADDR`); gövde okumaz; `ReadHeaderTimeout 5 s`, `WriteTimeout 15 s`,
  `MaxHeaderBytes 16 KB`.
- Erişim logu (`log/slog`, JSON): `time, level, request_id, method, path, status, bytes, duration_ms, ip`
  (`ip` = `CF-Connecting-IP`, yoksa `RemoteAddr`). `request_id` istekten (`CF-Ray`) ya da üretilir, yanıta
  `X-Request-Id` olarak döner.
- Sync ve serve aynı `data/` dizinini paylaşır; `rename` atomik olduğu için okuyucu yarım dosya görmez.

### VAK.7 — Depo düzeni, veri dizini, tohum dosyaları

```
server/
  cmd/vakit/main.go              alt komutlar: serve, sync <iş>, version
  internal/awqat/                istemci, token deposu, tipler (+ httptest testleri)
  internal/source/               Source arayüzü; awqat/, web/ uygulamaları; fixture'lar
  internal/model/                yayın şemaları (/v1 gövdeleri), Hicri ay tablosu
  internal/validate/             VAK.5 kuralları
  internal/store/                data/ yolları, atomik yazma, ETag, sync state
  internal/httpapi/              yönlendirme, başlıklar, hata zarfı, erişim logu
  internal/sync/                 işler (places, prayer-times, ...)
  data/tr_cities_geo.json        K7 — ilçe koordinatları (commit'li)
  data/seed/places/...           API onayı öncesi yer listesi tohumu (Diyanet ID'leri; kaynağı belgelenir)
  deploy/Dockerfile              çok aşamalı: golang:1.2x → gcr.io/distroless/static
  deploy/compose.yml             vakit (serve) + ./data volume; sync için `compose run --rm vakit sync ...`
  deploy/cloudflared.example.yml ingress örneği: api.<domain> → http://127.0.0.1:8080
  README.md                      kurulum, env, cron, Cloudflare kuralları
```

Çalışma zamanı veri dizini (`VAKIT_DATA_DIR`, varsayılan `./data`):

```
places/countries.json · places/countries/{id}/states.json · places/states/{id}/cities.json · places/tr/cities.json
prayer-times/{cityId}/{year}.json (+ .etag)
religious-days/{year}.json
daily-content/{yyyy}/{doy}.json
state/sync.json · state/awqat_token.json (0600)
```

Boyut: ilçe-yıl dosyası ~25 KB (gzip Cloudflare'de) → 970 ilçe ≈ 25 MB/yıl.

### VAK.8 — Konfigürasyon (ortam değişkenleri)

| Değişken | Varsayılan | Açıklama |
|---|---|---|
| `AWQAT_EMAIL`, `AWQAT_PASSWORD` | — | Diyanet hesabı; yalnız sunucuda, `.env` `0600`, compose `env_file` |
| `AWQAT_BASE_URL` | `https://awqatsalah.diyanet.gov.tr` | test için değiştirilebilir |
| `VAKIT_SOURCE` | `awqat` (kimlik yoksa `web`) | K4 |
| `VAKIT_DATA_DIR` | `./data` | |
| `VAKIT_ADDR` | `127.0.0.1:8080` | |
| `VAKIT_ENABLED_COUNTRIES` | `2` | virgülle ayrılmış Diyanet ülke id'leri |
| `VAKIT_SYNC_BATCH` | `150` | çalıştırma başına en çok ilçe-yıl çekimi |
| `VAKIT_SYNC_INTERVAL` | `500ms` | istekler arası bekleme |
| `VAKIT_LOG_LEVEL` | `info` | |

### VAK.9 — Dağıtım ve Cloudflare

1. Sunucuda: repo `server/` → `docker compose up -d` (serve); cron satırları VAK.4.
2. `cloudflared` ingress: `api.<domain>` → `http://127.0.0.1:8080` (mevcut tünel config'ine eklenir).
3. Cloudflare panel: **Cache Rule** `hostname eq api.<domain> and starts_with(path, "/v1/")` → "Eligible for cache",
   origin `Cache-Control`'e uy (JSON varsayılan cache'lenmez, kural şart); `/v1/health` no-store zaten uyulur.
   **Rate limiting** kuralı: `/v1/*` için IP başına 60 istek/10 s (ücretsiz planda 1 kural).
4. Doğrulama: `curl -I https://api.<domain>/v1/health` → 200; ikinci istekte `cf-cache-status: HIT` (vakit ucu).

### VAK.10 — Gözlemlenebilirlik

- Erişim logu (VAK.6) ve sync özeti: `job, source, fetched, written, rejected, skipped, quota_remaining, duration_ms`.
- `health.datasets` eksik yıl/ilçe sayısını verir; dış uptime izleyicisi (kullanıcının mevcut aracı) `/v1/health` çeker.
- Sync hatası cron çıkış kodunu `≠0` yapar; cron mail/uyarısı kullanıcının altyapısında.

### VAK.11 — Test

- `internal/awqat`: `httptest` sunucusuyla giriş, süre dolumu → yenileme, `401` → giriş, `429` → durma, `success=false` → hata.
- `internal/source/web`: kaydedilmiş ilçe sayfası fixture'ı (İstanbul 9541) → 403 satır, bilinen günler; başlık değişikliği → hata.
- `internal/source/awqat`: kılavuz örnekleri + canlı kayıt fixture'ları (onay sonrası eklenir) → model dönüşümü, Hicri ayrıştırma.
- `internal/validate`: her kural için geçen/kalan örnek.
- `internal/store`: atomik yazma (yarım dosya görünmez), ETag kararlılığı, yol üretimi (traversal denemesi 404).
- `internal/httpapi`: 200/304/404/405, başlıklar, hata zarfı, `HEAD`.
- Uçtan uca: `make smoke` — web kaynağıyla 1 ilçe sync → serve → curl; CI'da (GitHub Actions, `server/**` değişince) `go vet`, `go test ./...`, `docker build`.

## Kapsam dışı (bu spec)

- Uygulama tarafı (Spec B): `Location` v2, seçici, GPS→ilçe, `DiyanetProvider`, Hicri tüketicileri, migrasyon, Aladhan/Photon kaldırma, gizlilik dokümanları, ADR 0006.
- Türkiye dışı ülke açma (config değişikliği + o ülkelerin koordinat dosyası).
- Push, hesap, senkron (Faz 3–4); veritabanı.
- `Location/CityFromLocation` proxy'si; `DailyContent/ReligiousCalendar`; `Place/Mosques*`.

## Açık noktalar (implementasyonda doğrulanır)

- v2 `Place/*` alan adları (OpenAPI yalnız `IResult` gösteriyor) — canlı yanıtla; uymazsa v1 + ayrı çağrılar.
- `DateRange` yanıt gövdesi (`Daily` ile aynı varsayımı) ve boş/kısmi yıl davranışı.
- Kota gerçek sayıları (`Quota/My`) — `VAKIT_SYNC_BATCH` buna göre ayarlanır; küresel günlük tavan varsa 970 ilçe daha uzun sürer.
- `DailyContent` `language` enum eşlemesi.
- Tohum yer listesi kaynağı: onay öncesi Diyanet ID'leri ilçe sayfası seçicilerinden ya da açık veri setinden alınır; hangisi olursa `data/seed/README.md`'de yazılır.
- Go toolchain geliştirici makinesinde yok (`brew install go`); sunucuda Docker var, `cloudflared` çalışıyor.

## Referanslar

- Awqat Salah: https://awqatsalah.diyanet.gov.tr · `openapi/v1.json`, `openapi/v2.json` · kılavuz PDF s.3 (JWT), s.5 (kota, self-hosting), s.7–12 (uçlar)
- Örnek istemci: https://github.com/DinIsleriYuksekKurulu/AwqatSalah
- Uygulama tarafı mevcut kaynak: `lib/features/prayer_times/data/awqat_salah_provider.dart` (Aladhan; Spec B'de kaldırılır)
