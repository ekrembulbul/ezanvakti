# vakit-api — Diyanet verisini barındıran sunucu (Spec A)

- **Tarih:** 2026-09-15 · **Durum:** kabul edildi; implementasyon planı `docs/superpowers/plans/2026-09-16-vakit-api-sunucu.md` · **Branch:** `feature/vakit-api`
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
| K2 | Dil Go (≥ 1.26, `x/net` gereği), tek binary `vakit` (`serve` / `sync` alt komutları), stdlib + `golang.org/x/net/html` + `modernc.org/sqlite` (saf Go, CGO yok) | Küçük imaj, sıfır çalışma zamanı bağımlılığı, kullanıcı tercihi |
| K3 | Yayın verisi (vakit, yer listeleri, dinî günler, içerik) JSON dosyaları; değişken durum gömülü **SQLite** (`state/vakit.db`, saf Go sürücü, gömülü SQL migration'lar, WAL) — Faz 1'de sync durumu, ileride cihaz token'ı/hesap | Tek erişim deseni "kayıt + yıl" için dosya + ETag + Cloudflare cache yeter; ileriki fazlar DB'yi sıfırdan kurmasın diye şema sürümleme ilk günden var (2026-09-17 kararı: kullanıcı) |
| K4 | Kaynak soyutlaması: `awqat` (resmî API, birincil) ve `web` (namazvakitleri.diyanet.gov.tr ilçe sayfası, onay öncesi ve fesih fallback'i) aynı `Source` arayüzü | API onayı beklenmeden çalışır; form "tek taraflı fesih" hakkı içeriyor |
| K5 | Reverse proxy yok; konteyner yalnız `127.0.0.1:3060`'ta yayımlanır (sunucuda 8080 başka serviste), `cloudflared` tüneli `ezanvakti.ekrembulbul.me` → origin | Kullanıcının mevcut altyapısı; TLS/DNS/WAF/cache Cloudflare'de |
| K6 | Sözleşme `/v1` altında, sürüm kırıcı değişiklik `/v2` | Uygulama mağaza sürümleri eski sözleşmeyi yıllarca çağırır |
| K7 | Koordinatlar Diyanet'te yok → tek seferlik OSM/Nominatim eşlemesi `server/assets/tr_cities_geo.json` olarak commit'lenir, elle gözden geçirilir | Uygulamada GPS → en yakın ilçe ve kıble için gerekli; ODbL atfı uygulamaya eklenir |

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
     "qiblaAngle": 151, "qiblaAngleMagnetic": 146, "distanceToKaaba": 2400 }, ...]
  → latitude/longitude K7'den. qiblaAngle = Diyanet CityDetail `geographicQiblaAngle` (gerçek kuzey),
    qiblaAngleMagnetic = CityDetail `qiblaAngle` (manyetik); distanceToKaaba km. Bilinmiyorsa null

GET /v1/places/tr/cities
  → Türkiye'nin tüm ilçeleri tek dosyada, il adıyla zenginleştirilmiş
    [{ ...city, "stateName": "İSTANBUL" }]
  → uygulamadaki seçici, GPS→ilçe eşlemesi ve gömülü asset bu dosyadan üretilir

GET /v1/places/search?q={metin}&limit={1..25}     (2026-09-17 eki — uygulama gömülü liste taşımaz)
  { "query": "sile", "results": [
      { "id": 9547, "name": "Şile", "stateName": "İstanbul", "displayName": "Şile, İstanbul",
        "stateId": 539, "countryId": 2, "isCentre": false, "latitude": 41.17, "longitude": 29.61,
        "qiblaAngle": 151, "qiblaAngleMagnetic": 146, "distanceToKaaba": 2400,
        "matchedAlias": "Kadıköy" }, ... ] }
  → Türkçe karakter/büyük-küçük harf duyarsız; ilçe adı öneki > eşanlam > il adı > içerir sırası; il merkezi
    "İstanbul (Merkez)"; boş sorgu = büyük iller. Adlar OSM yazımıyla ("Çubuk"), Diyanet'in "CUBUK"u değil.
    matchedAlias: Diyanet'te ayrı olmayan büyükşehir merkez ilçesi (Kadıköy → İstanbul kaydı); tablo sunucuda
    gömülü (assets/tr_place_aliases.json, 6 büyükşehir; genişletilebilir). q ≤ 64 karakter.
    Cache-Control: public, max-age=3600 (Cloudflare sorguya göre cache'ler). Sorgu metni loglanmaz.

GET /v1/places/resolve?lat={enlem}&lon={boylam}
  { "city": { ...search sonucu ile aynı alanlar... }, "distanceKm": 1.2 }
  → en yakın ilçe merkezi (haversine). En yakın ilçe 60 km'den uzaksa 404 NO_COVERAGE. Koordinat ~100 m'ye
    yuvarlanır, saklanmaz, loglanmaz (erişim logu yalnız yol yazar). Cache-Control: no-store.
  → İlçe listesi henüz senkronlanmadıysa her iki uç 503 NOT_READY + Retry-After: 300.

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
| 404 | `NO_COVERAGE` — resolve: en yakın ilçe 60 km'den uzak (Türkiye dışı) |
| 500 | `INTERNAL` — dosya okunamadı; ayrıntı yalnız log'da |
| 503 | `NOT_READY` — ilçe listesi henüz senkronlanmadı (`Retry-After: 300`) |

### VAK.2 — Diyanet Awqat Salah istemcisi (`internal/awqat`)

Kaynaklar: site sayfası, kılavuz PDF (s.3–12) ve `https://awqatsalah.diyanet.gov.tr/openapi/v1.json`.
Taban adres `https://awqatsalah.diyanet.gov.tr`. Her yanıt `{ "data": T, "success": bool, "message": string|null }`
zarfındadır; `success=false` ya da HTTP ≠ 200 hata sayılır ve `message` loglanır.

| Kullanım | Uç | Not |
|---|---|---|
| Giriş | `POST /Auth/Login` `{ "email", "password" }` → `data.accessToken`, `data.refreshToken` | JWT; süre `exp` claim'inden okunur (site 45 dk, kılavuz 30 dk diyor — sabit yazılmaz) |
| Yenileme | `GET /Auth/RefreshToken/{refreshToken}` → yeni çift | Refresh 7 gün, her kullanımda döner; **7 gün kullanılmazsa geçersiz** → tam giriş. Dosyada saklanır (`data/state/awqat_token.json`, `0600`) |
| Ülkeler | `GET /api/Place/Countries` → `[{id, code, name}]` | v1: şekli kılavuzda belgeli; `code` İngilizce ad olarak kullanılır. v2'ye gerek yok: il/ilçenin ebeveyni istekten biliniyor |
| İller | `GET /api/Place/States/{countryId}` | yalnız `enabled` ülkeler |
| İlçeler | `GET /api/Place/Cities/{stateId}` | |
| İlçe detayı | `GET /api/Place/CityDetail/{cityId}` → `geographicQiblaAngle`, `qiblaAngle`, `distanceToKaaba` (string sayılar) | koordinat vermez; yalnız kıble bilgisi eksik ilçeler için çağrılır |
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

Onay gelene kadar birincil, sonra fesih/kesinti fallback'i. Yer listesi **ve** vakit tablosu verir;
dini günler, günlük içerik ve kıble açısı için web karşılığı yoktur (`ErrUnsupported`; ilgili sync
işleri web modunda uyarı loglayıp atlar). Tüm isteklerde tarayıcı `User-Agent` gönderilir.

- Ülkeler: `GET /tr-TR/9541` sayfasındaki `select.country-select` seçenekleri (`value`=id, metin=ad; 209 ülke, TÜRKİYE=2).
  Sabit bir ilçe sayfası kullanılır çünkü liste her ilçe sayfasında aynıdır.
- İller: `GET /tr-TR/home/GetRegList?ChangeType=country&CountryId={countryId}&Culture=tr-TR` →
  `{"StateList":[{"SehirAdi","SehirAdiEn","SehirID"}]}` (TR: 81).
- İlçeler: `GET /tr-TR/home/GetRegList?ChangeType=state&StateId={stateId}&Culture=tr-TR` →
  `{"StateRegionList":[{"IlceAdi","IlceAdiEn","IlceID","IlceUrl"}]}`.
- Vakitler: `GET /tr-TR/{cityId}` → 302 → `/tr-TR/{cityId}/{slug}`. Sayfada üç tablo var:
  haftalık (7 gün), **aylık** (`aria-describedby="table-caption-monthly"`, bugünden +30 gün, 31 satır) ve
  **yıllık** (`table#yourTable`, 15 Eyl 2026 itibarıyla yalnız **gelecek yıl** 2027, 365 satır; cari yılın
  kalanı bu tabloda yok). Kaynak, aylık + yıllık tabloların satırlarını okur, istenen yıla ait olanları döndürür;
  istenen yıl için satır yoksa boş liste (hata değil).
- Sütunlar `Miladi Tarih | Hicri Tarih | İmsak | Güneş | Öğle | İkindi | Akşam | Yatsı`; parser başlığı **doğrular**,
  farklıysa hata verir (HTML değişikliği sessizce yanlış sütun okumaz).
- Tarih: `"15 Eylül 2026 Salı"` → Türkçe ay adı tablosu (gün adı yok sayılır); Hicri `"4 Rebiulahir 1448"` → Diyanet ay
  adı tablosu (Muharrem, Safer, Rebiulevvel, Rebiulahir, Cemaziyelevvel, Cemaziyelahir, Recep, Şaban, Ramazan, Şevval,
  Zilkade, Zilhicce) → `{day, month, year, monthName}`.
- Web ile üretilen dosyada `astronomical*`, `qiblaTime` null; `source` yine `"diyanet"`, ek alan `"via": "web"`.

Sonuç: web modunda gelecek yıl tek çekimde tamamlanır; cari yıl ise kayan 31 günlük pencerelerin
**birikimli birleştirilmesiyle** dolar (bkz. VAK.4). Uygulama bu yüzden `complete=false` dosyalarla çalışabilmelidir.

### VAK.4 — Senkronizasyon işleri (`vakit sync <iş>`)

Hepsi idempotent; her çalıştırma ilerlemeyi SQLite'tan (`state/vakit.db`) okur/günceller. Cron (host):

```
0 3 * * *   vakit sync prayer-times --year <bu yıl> --year <gelecek yıl> --batch 150
0 4 * * 1   vakit sync places
0 4 1 * *   vakit sync religious-days --year <bu yıl> --year <gelecek yıl>
15 0 * * *  vakit sync daily-content --ahead 7
```

| İş | Yaptığı | Kota bütçesi |
|---|---|---|
| `places` | Countries → enabled ülkeler için States → Cities → her ilçe için CityDetail (yalnız eksik olanlar) → `tr_cities_geo.json` ile birleştir → `places/*` yaz | bootstrap ~1 + 81 + 970; sonrası yalnız değişenler |
| `prayer-times` | enabled ilçeler × istenen yıllar için **eksik olanları** çek → mevcut dosyayla **tarih bazında birleştir** (yeni gün eski günün üstüne yazar) → doğrula → yaz; `--batch N` çekimden sonra dur. Eksik tanımı: dosya yok, `complete=false`, ya da (web) ufuk `< bugün + 21 gün`. API modunda `DateRange` 1 Ocak–31 Aralık tek çekimde tamamlar; web modunda aylık pencere + gelecek yıl tablosu birikir | API: ilçe/yıl başına 1; 970 ilçe ≈ 7 günde (`batch 150`). Web: kontrat yok; nezaket için 1 istek/sn ve ufuk kuralıyla günde ≈140 sayfa |
| `religious-days` | `ByYear` → doğrula (tarihler artan, yıl içinde) → yaz | yılda 1 |
| `daily-content` | bugün + `--ahead` gün için içerik → `daily-content/{yyyy}/{doy}.json`; var olan gün atlanır | günde ≤ 8 |
| `quota` | `Quota/My` çıktısını yazdırır | 1 |
| `verify` | mevcut dosyaları VAK.5 kurallarıyla yeniden doğrular, ağ kullanmaz | 0 |

Kaynak seçimi: `VAKIT_SOURCE=awqat|web` (varsayılan `awqat`; kimlik bilgisi tanımlı değilse
otomatik `web` ve uyarı logu). Yayınlanan dosya her zaman aynı şemadadır; uygulama kaynağı bilmez.

`complete` = dosyadaki gün sayısı yılın gün sayısına eşit. Kaynak istenen yıl için hiç gün döndürmezse dosya
yazılmaz/değişmez, `state`'e "henüz yok" notu düşer, sonraki çalıştırma yeniden dener (Diyanet gelecek yılı
yıl sonuna doğru yayınlar).

### VAK.5 — Doğrulama (yayın öncesi)

Bir dosya ancak tüm kurallar geçerse `data/` altına atomik olarak yazılır (`.tmp` + `rename`).
Kural ihlali → dosya yazılmaz, `WARN` log (`city`, `year`, kural, örnek gün), `health` içinde
`rejected` sayacı artar.

1. Tüm tarihler istenen yıl içinde; tekrar yok; artan sıralı. Boşluk (gap) **izinli** — sync 31 günden uzun
   dururca oluşabilir; uygulama eksik günü "veri yok" olarak ele alır. `complete` yalnız 365/366 günde `true`.
2. Ardışık iki tarih arasında Hicri gün ya +1 artar ya 1'e döner (ay değişimi); ardışık olmayan çiftler kontrol edilmez.
3. Her gün: `fajr < sunrise < dhuhr < asr < maghrib < isha` (dakika cinsinden, aynı gün).
4. Önceki yılın aynı takvim günü varsa fark ≤ 5 dk (tüm vakitler). Aşarsa reddet: Diyanet'in kendi verisinde
   yıllar arası fark ±1–2 dk'dır; 5 dk üstü ayrıştırma hatasıdır.
5. Hicri: gün 1–30, ay 1–12, ay adı tabloda.
6. Dini günler: tarihler artan, hepsi istenen yılda, ad boş değil.

### VAK.6 — HTTP sunucusu (`vakit serve`)

- Go 1.22+ `net/http` desen yönlendirme (`GET /v1/prayer-times/{cityId}/{year}`); yol parametreleri
  **sayı/tarih olarak ayrıştırılır**, dosya yolu bu değerlerden üretilir — kullanıcı girdisi dosya sistemine
  ham geçmez (path traversal imkânsız).
- Yanıt `data/` altındaki dosyanın ham baytlarıdır; ETag okuma anında SHA-256 ile hesaplanır (dosyalar
  ≤ 300 KB, maliyet ihmal edilebilir; Cloudflare zaten önbellekler). `HEAD` desteklenir.
- Yalnız `127.0.0.1:8080` (`VAKIT_ADDR`); gövde okumaz; `ReadHeaderTimeout 5 s`, `WriteTimeout 15 s`,
  `MaxHeaderBytes 16 KB`.
- Erişim logu (`log/slog`, JSON): `time, level, request_id, method, path, status, bytes, duration_ms, ip`
  (`ip` = `CF-Connecting-IP`, yoksa `RemoteAddr`). `request_id` istekten (`CF-Ray`) ya da üretilir, yanıta
  `X-Request-Id` olarak döner.
- Sync ve serve aynı `data/` dizinini paylaşır; `rename` atomik olduğu için okuyucu yarım dosya görmez.

### VAK.7 — Depo düzeni ve veri dizini

```
server/
  cmd/vakit/main.go              alt komutlar: serve, sync <iş>, version
  internal/awqat/                istemci, token deposu, tipler (+ httptest testleri)
  internal/source/               Source arayüzü; awqat/, web/ uygulamaları; fixture'lar
  internal/model/                yayın şemaları (/v1 gövdeleri), Hicri ay tablosu
  internal/validate/             VAK.5 kuralları
  internal/store/                data/ yolları, atomik yazma, ETag, sync state tipleri
  internal/db/                   SQLite: açma (WAL), gömülü migration'lar, sync durumu yükle/kaydet
  internal/httpapi/              yönlendirme, başlıklar, hata zarfı, erişim logu
  internal/jobs/                 işler (places, prayer-times, ...) — stdlib `sync` ile ad çakışmasını önlemek için `jobs`
  assets/tr_cities_geo.json      K7 — ilçe koordinatları ve OSM yazımları (commit'li; `cmd/geocode-tr` üretir)
  assets/tr_place_aliases.json   Diyanet'te ayrı olmayan büyükşehir merkez ilçeleri → Diyanet kaydı
  cmd/geocode-tr/main.go         tek seferlik Nominatim eşleme aracı
  data/                          çalışma zamanı verisi, .gitignore'da
  deploy/Dockerfile              çok aşamalı: golang:1.2x → gcr.io/distroless/static
  deploy/compose.yml             vakit (serve) + ./data volume; sync için `compose run --rm vakit sync ...`
  deploy/cloudflared.example.yml ingress örneği: ezanvakti.ekrembulbul.me → http://127.0.0.1:3060
  README.md                      kurulum, env, cron, Cloudflare kuralları
```

Çalışma zamanı veri dizini (`VAKIT_DATA_DIR`, varsayılan `./data`):

```
places/countries.json · places/countries/{id}/states.json · places/states/{id}/cities.json · places/tr/cities.json
prayer-times/{cityId}/{year}.json
religious-days/{year}.json
daily-content/{yyyy}/{doy}.json
state/vakit.db (+ -wal/-shm) · state/awqat_token.json (0600)
```

Boyut: ilçe-yıl dosyası ~25 KB (gzip Cloudflare'de) → 970 ilçe ≈ 25 MB/yıl.

### VAK.8 — Konfigürasyon (ortam değişkenleri)

| Değişken | Varsayılan | Açıklama |
|---|---|---|
| `AWQAT_EMAIL`, `AWQAT_PASSWORD` | — | Diyanet hesabı; yalnız sunucuda, `deploy/vakit.env` `0600`, compose `env_file` |
| `AWQAT_BASE_URL` | `https://awqatsalah.diyanet.gov.tr` | test için değiştirilebilir |
| `VAKIT_SOURCE` | `awqat` (kimlik yoksa `web`) | K4 |
| `VAKIT_DATA_DIR` | `./data` | |
| `VAKIT_ADDR` | `127.0.0.1:8080` | |
| `VAKIT_ENABLED_COUNTRIES` | `2` | virgülle ayrılmış Diyanet ülke id'leri |
| `VAKIT_SYNC_BATCH` | `150` | çalıştırma başına en çok ilçe-yıl çekimi |
| `VAKIT_SYNC_INTERVAL` | `500ms` | istekler arası bekleme |
| `VAKIT_LOG_LEVEL` | `info` | |

### VAK.9 — Dağıtım ve Cloudflare

1. GitHub Actions (`server-deploy.yml`, `main`'e `server/` push'unda): test → GHCR imajı → SSH ile sunucuda
   `ezanvakti` kullanıcısına `~/vakit-api` (compose + `vakit.env` secret'lardan + crontab); ayrıntı `server/README.md`.
2. Tünel panelden yönetiliyor: Published application `ezanvakti.ekrembulbul.me` → **HTTP** `localhost:3060` (compose host portu).
3. Cloudflare panel: **Cache Rule** `hostname eq ezanvakti.ekrembulbul.me and starts_with(path, "/v1/")` → "Eligible for cache",
   origin `Cache-Control`'e uy (JSON varsayılan cache'lenmez, kural şart); `/v1/health` no-store zaten uyulur.
   **Rate limiting** kuralı: `/v1/*` için IP başına 60 istek/10 s (ücretsiz planda 1 kural).
4. Doğrulama: `curl -I https://ezanvakti.ekrembulbul.me/v1/health` → 200; ikinci istekte `cf-cache-status: HIT` (vakit ucu).

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

2026-09-24 canlı doğrulama (hesap rolü `Developer`, toplam 6 istek):

- ✅ `DateRange` gövdesi `Daily` ile aynı şekilde; 1 Ocak–31 Aralık tek çekimde 365 gün, `complete=true`. Web
  tablosuyla ortak 31 günde vakitler ve Hicri birebir; API ek olarak astronomik gün doğumu/batımı, kıble saati
  ve GMT farkı verir. Boş/kısmi yıl davranışı henüz görülmedi (2027 denenmedi).
- ✅ Kota: `Quota/My` yalnız `daily` dizisi döndü; her uç `benefit: 100`, kullanım
  `lines[{parameter: "cityId:9146", used, remainingUse}]` → parametre bazında. Site: günde 10, ilk 15 gün 100;
  `DateRange` ayrıca yer bazında ayda 10; küresel tavan belirtilmiyor. İlçe-yıl başına tek `DateRange` yettiğinden
  sınır senkron için dar değil; `VAKIT_SYNC_BATCH` nezaket sınırı olarak kalır.
- ✅ `IslamicReligiousDay/ByYear` kotada yok; 2026 için 25 kayıt, doğrulamadan geçti.
- ⚠️ `DailyContent/VerseHadithAndPrayer?date=` → HTTP 403 "Bu işlem için yetkiniz yok!" (`Developer` rolü); kotada
  yalnız `DailyContent Get` (bugün) görünüyor. Uygulama günlük içeriği kullanmıyor; `daily-content` işi cron'dan
  çıkarıldı, gerekirse bugün ucuna geçilir. `language` enum eşlemesi bu yüzden açık.
- ✅ Token: erişim 45 dk (JWT `exp`), refresh 7 gün.
- Go toolchain geliştirici makinesinde kurulu; sunucuda Docker + Compose var, `cloudflared` panelden yönetilen (token'lı) tünel.

## Referanslar

- Awqat Salah: https://awqatsalah.diyanet.gov.tr · `openapi/v1.json`, `openapi/v2.json` · kılavuz PDF s.3 (JWT), s.5 (kota, self-hosting), s.7–12 (uçlar)
- Örnek istemci: https://github.com/DinIsleriYuksekKurulu/AwqatSalah
- Uygulama tarafı mevcut kaynak: `lib/features/prayer_times/data/awqat_salah_provider.dart` (Aladhan; Spec B'de kaldırılır)
