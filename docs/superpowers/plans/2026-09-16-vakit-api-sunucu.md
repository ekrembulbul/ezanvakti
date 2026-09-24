# vakit-api Sunucu — Implementation Plan (Spec A)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Bu projede kullanıcı tercihi **inline yürütme**dir (bkz. memory: inline-execution-and-release-loop).

**Goal:** Diyanet Awqat Salah verisini (yer listeleri, ilçe bazlı yıllık vakitler + Hicri, dinî günler, günlük içerik) çekip doğrulayan, JSON dosya olarak yayınlayan ve `/v1` sözleşmesiyle sunan Go sunucusu `vakit`.

**Architecture:** Tek binary; `vakit sync <iş>` cron'dan çalışır, `Source` arayüzü üzerinden `awqat` (resmî API) ya da `web` (namazvakitleri.diyanet.gov.tr) kaynağından çeker, `validate` kurallarından geçen veriyi `store` ile atomik olarak `data/` altına yazar. `vakit serve` aynı `data/` dizinini `net/http` ile yalnız `127.0.0.1:8080`'de sunar; TLS/cache/rate-limit Cloudflare Tunnel + Cloudflare kurallarında.

**Tech Stack:** Go ≥ 1.24, stdlib (`net/http` desen yönlendirme, `log/slog`, `encoding/json`, `embed`), tek dış bağımlılık `golang.org/x/net/html`; Docker (distroless), docker compose, cloudflared, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-15-vakit-api-sunucu-design.md`

## Global Constraints

- Go modülü `server/` altında, modül adı `vakit`; `go.mod` içinde `go 1.24`. Bağımlılık: yalnız `golang.org/x/net` (K2).
- Depolama: JSON dosyaları; veritabanı yok (K3). Çalışma zamanı verisi `VAKIT_DATA_DIR` (varsayılan `./data`), `.gitignore`'da.
- Sunucu yalnız `127.0.0.1:8080`'e bind (K5); yalnız `GET`/`HEAD`; gövde okumaz.
- Hata zarfı her zaman `{"error":{"code","message"}}`; kodlar `INVALID_PARAMETER`, `NOT_FOUND`, `METHOD_NOT_ALLOWED`, `INTERNAL` (VAK.1).
- Cache: `ETag` = `"` + SHA-256 hex ilk 16 karakter + `"`; `Cache-Control: public, max-age=86400, stale-while-revalidate=604800` (vakit, dinî gün, günlük içerik), `public, max-age=604800, stale-while-revalidate=604800` (yer listeleri), `/v1/health` → `no-store`.
- Diyanet istemcisi: `Authorization: Bearer`, JWT `exp` claim'i okunur, `exp − 2 dk` geçince yenile, `401` → yenile → olmazsa giriş; `429` → dur (yeniden deneme yok); `5xx`/timeout → en çok 3 deneme, backoff 2 s → 4 s → 8 s; istek zaman aşımı 30 s; istekler arası `VAKIT_SYNC_INTERVAL` (varsayılan 500 ms). Kimlik bilgisi/token **hiç loglanmaz** (VAK.2).
- Web kaynağı tarayıcı `User-Agent` gönderir; tablo başlığını doğrular (VAK.3).
- Doğrulama kuralları VAK.5: tarihler istenen yılda, tekrar yok, artan; vakit sırası; önceki yıl ±5 dk; Hicri gün 1–30, ay 1–12, ardışık günde +1 ya da 1'e dönüş; `complete` yalnız 365/366 günde.
- Loglar `log/slog` JSON; erişim logu alanları `request_id, method, path, status, bytes, duration_ms, ip` (VAK.6, VAK.10).
- Her commit öncesi: `cd server && gofmt -l . && go vet ./... && go test ./...` temiz. Commit mesajları Türkçe Conventional Commits, sonunda `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`. Branch: `feature/vakit-api`.
- Ön koşul: bu Mac'te Go yok → `brew install go` (Task 1, Step 0). Sunucuda Docker + cloudflared var.

---

## Dosya yapısı

```
server/
  go.mod, go.sum, .gitignore, Makefile, README.md
  cmd/vakit/main.go            alt komut dağıtımı (serve | sync | version)
  cmd/vakit/serve.go           HTTP sunucusu başlatma, graceful shutdown
  cmd/vakit/sync.go            sync alt komutları, flag'ler, kaynak seçimi
  cmd/geocode-tr/main.go       tek seferlik Nominatim eşleme aracı → assets/tr_cities_geo.json
  assets/assets.go             //go:embed tr_cities_geo.json
  assets/tr_cities_geo.json    ilçe koordinatları (Task 10'da boş iskelet, Task 14'te dolu)
  internal/model/              yayın şemaları (/v1 gövdeleri), Hicri ay tablosu, TR tarih/saat ayrıştırma
  internal/store/              data/ yolları, atomik yazma, ETag, sync state
  internal/validate/           VAK.5 kuralları
  internal/config/             env → Config
  internal/httpapi/            yönlendirme, dosya sunumu, hata zarfı, health, erişim logu
  internal/awqat/              Diyanet REST istemcisi (token, retry, uçlar)
  internal/source/             Source arayüzü, ErrUnsupported, ErrQuotaExceeded
  internal/source/awqatsrc/    awqat → model adaptörü
  internal/source/web/         ilçe sayfası + GetRegList kaynağı (testdata/ fixture'ları hazır)
  internal/geo/                tr_cities_geo.json ayrıştırma
  internal/jobs/               places, prayer-times, religious-days, daily-content, verify işleri
  deploy/Dockerfile, deploy/compose.yml, deploy/cloudflared.example.yml, deploy/.env.example
.github/workflows/server-ci.yml
```

---

### Task 1: Go modülü iskeleti ve `vakit version`

**Files:**
- Create: `server/go.mod`, `server/.gitignore`, `server/cmd/vakit/main.go`, `server/cmd/vakit/main_test.go`

**Interfaces:**
- Produces: `run(args []string, stdout, stderr io.Writer) int` — sonraki task'lar `serve`/`sync` dallarını bu switch'e ekler. `var version = "dev"` (`-ldflags "-X main.version=..."`).

- [ ] **Step 0: Go toolchain**

Run: `brew install go && go version`
Expected: `go version go1.2x ...` (≥ 1.24)

- [ ] **Step 1: Modül ve gitignore**

```bash
mkdir -p server/cmd/vakit && cd server && go mod init vakit && sed -i '' 's/^go .*/go 1.24/' go.mod && cat go.mod
```

`server/.gitignore`:
```
data/
deploy/.env
/vakit
*.test
coverage.out
```

- [ ] **Step 2: Failing test**

`server/cmd/vakit/main_test.go`:
```go
package main

import (
	"bytes"
	"strings"
	"testing"
)

func TestRun_VersionPrintsVersionAndExitsZero(t *testing.T) {
	version = "1.2.3+test"
	var out, errOut bytes.Buffer
	code := run([]string{"version"}, &out, &errOut)
	if code != 0 {
		t.Fatalf("exit code = %d, want 0 (stderr: %s)", code, errOut.String())
	}
	if got := strings.TrimSpace(out.String()); got != "1.2.3+test" {
		t.Fatalf("stdout = %q, want %q", got, "1.2.3+test")
	}
}

func TestRun_NoArgsPrintsUsageAndExitsTwo(t *testing.T) {
	var out, errOut bytes.Buffer
	if code := run(nil, &out, &errOut); code != 2 {
		t.Fatalf("exit code = %d, want 2", code)
	}
	if !strings.Contains(errOut.String(), "Kullanım") {
		t.Fatalf("stderr should contain usage, got %q", errOut.String())
	}
}

func TestRun_UnknownCommandExitsTwo(t *testing.T) {
	var out, errOut bytes.Buffer
	if code := run([]string{"bogus"}, &out, &errOut); code != 2 {
		t.Fatalf("exit code = %d, want 2", code)
	}
}
```

- [ ] **Step 3: Run, fail**

Run: `cd server && go test ./cmd/vakit/`
Expected: FAIL — `undefined: run`, `undefined: version`

- [ ] **Step 4: Implement**

`server/cmd/vakit/main.go`:
```go
// Command vakit: Diyanet vakit verisini çeken (sync) ve sunan (serve) tek binary.
package main

import (
	"fmt"
	"io"
	"os"
)

// version -ldflags "-X main.version=<sürüm>" ile doldurulur.
var version = "dev"

const usage = `vakit — Diyanet vakit verisi sunucusu

Kullanım:
  vakit serve                  HTTP sunucusunu başlatır (VAKIT_ADDR, VAKIT_DATA_DIR)
  vakit sync <iş> [flags]      Diyanet'ten veri çeker: places | prayer-times | religious-days | daily-content | quota | verify
  vakit version                sürümü yazar
`

func main() {
	os.Exit(run(os.Args[1:], os.Stdout, os.Stderr))
}

func run(args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		fmt.Fprint(stderr, usage)
		return 2
	}
	switch args[0] {
	case "version":
		fmt.Fprintln(stdout, version)
		return 0
	default:
		fmt.Fprintf(stderr, "bilinmeyen komut: %q\n\n%s", args[0], usage)
		return 2
	}
}
```

- [ ] **Step 5: Run, pass**

Run: `cd server && gofmt -l . && go vet ./... && go test ./...`
Expected: `ok  vakit/cmd/vakit`

- [ ] **Step 6: Commit**

```bash
git add server/go.mod server/.gitignore server/cmd/vakit
git commit -m "feat(server): vakit modül iskeleti ve version komutu

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: `internal/model` — yayın şemaları, Hicri ay tablosu, TR tarih/saat ayrıştırma

**Files:**
- Create: `server/internal/model/model.go`, `server/internal/model/hijri.go`, `server/internal/model/parse.go`, `server/internal/model/model_test.go`

**Interfaces:**
- Produces: `Country, State, City, CityWithState, CityDetail, Hijri, Day, YearTimes, ReligiousDay, DailyContent` tipleri (JSON etiketleri = VAK.1 alan adları); `const SchemaVersion = 1`, `SourceDiyanet = "diyanet"`, `ViaWeb = "web"`; `HijriMonths [12]string`, `HijriMonthNumber(name string) (int, bool)`, `ParseHijriLong("4 Rebiulahir 1448") (Hijri, error)`, `ParseHijriShort("4.4.1448") (Hijri, error)`, `ParseTurkishDate("15 Eylül 2026 Salı") (time.Time, error)`, `ClockMinutes("05:11") (int, error)`, `const DateLayout = "2006-01-02"`.

- [ ] **Step 1: Failing tests**

`server/internal/model/model_test.go`:
```go
package model

import (
	"encoding/json"
	"testing"
	"time"
)

func TestHijriMonthNumber_AcceptsDiyanetSpellings(t *testing.T) {
	cases := map[string]int{
		"Muharrem": 1, "Safer": 2, "Rebiulevvel": 3, "Rebiülevvel": 3, "Rebiulahir": 4, "Rebiülahir": 4,
		"Cemaziyelevvel": 5, "Cemaziyelahir": 6, "Recep": 7, "Şaban": 8, "Ramazan": 9, "Şevval": 10,
		"Zilkade": 11, "Zilkâde": 11, "Zilhicce": 12, "zilhicce": 12,
	}
	for name, want := range cases {
		got, ok := HijriMonthNumber(name)
		if !ok || got != want {
			t.Errorf("HijriMonthNumber(%q) = %d,%v; want %d,true", name, got, ok, want)
		}
	}
	if _, ok := HijriMonthNumber("Bilinmeyen"); ok {
		t.Error("unknown month must not resolve")
	}
}

func TestParseHijriLong(t *testing.T) {
	got, err := ParseHijriLong("4 Rebiulahir 1448")
	if err != nil {
		t.Fatal(err)
	}
	want := Hijri{Day: 4, Month: 4, Year: 1448, MonthName: "Rebiulahir"}
	if got != want {
		t.Fatalf("got %+v want %+v", got, want)
	}
	for _, bad := range []string{"", "Rebiulahir 1448", "4 Foo 1448", "x Rebiulahir 1448", "31 Recep 1448"} {
		if _, err := ParseHijriLong(bad); err == nil {
			t.Errorf("ParseHijriLong(%q) should fail", bad)
		}
	}
}

func TestParseHijriShort_UsesCanonicalMonthName(t *testing.T) {
	got, err := ParseHijriShort("5.5.1444")
	if err != nil {
		t.Fatal(err)
	}
	want := Hijri{Day: 5, Month: 5, Year: 1444, MonthName: "Cemaziyelevvel"}
	if got != want {
		t.Fatalf("got %+v want %+v", got, want)
	}
	if _, err := ParseHijriShort("5.13.1444"); err == nil {
		t.Error("month 13 must fail")
	}
}

func TestParseTurkishDate(t *testing.T) {
	cases := map[string]string{
		"15 Eylül 2026 Salı":  "2026-09-15",
		"01 Ocak 2027 Cuma":   "2027-01-01",
		"31 Aralık 2027 Cuma": "2027-12-31",
		"3 Mayıs 2027":        "2027-05-03",
	}
	for in, want := range cases {
		got, err := ParseTurkishDate(in)
		if err != nil {
			t.Errorf("ParseTurkishDate(%q): %v", in, err)
			continue
		}
		if got.Format(DateLayout) != want {
			t.Errorf("ParseTurkishDate(%q) = %s want %s", in, got.Format(DateLayout), want)
		}
	}
	for _, bad := range []string{"15 September 2026", "Eylül 2026", "32 Eylül 2026"} {
		if _, err := ParseTurkishDate(bad); err == nil {
			t.Errorf("ParseTurkishDate(%q) should fail", bad)
		}
	}
}

func TestClockMinutes(t *testing.T) {
	if got, _ := ClockMinutes("05:11"); got != 311 {
		t.Fatalf("05:11 = %d want 311", got)
	}
	if got, _ := ClockMinutes("5:11"); got != 311 {
		t.Fatalf("5:11 = %d want 311", got)
	}
	if got, _ := ClockMinutes("19:22:00"); got != 1162 {
		t.Fatalf("19:22:00 = %d want 1162", got)
	}
	for _, bad := range []string{"", "25:00", "12:60", "ab:cd", "12"} {
		if _, err := ClockMinutes(bad); err == nil {
			t.Errorf("ClockMinutes(%q) should fail", bad)
		}
	}
}

func TestYearTimes_JSONFieldNamesMatchContract(t *testing.T) {
	yt := YearTimes{SchemaVersion: SchemaVersion, Source: SourceDiyanet, CityID: 9541, Year: 2026,
		GeneratedAt: time.Date(2026, 9, 15, 20, 0, 0, 0, time.UTC),
		Days: []Day{{Date: "2026-09-15", Hijri: Hijri{4, 4, 1448, "Rebiulahir"},
			Fajr: "05:11", Sunrise: "06:37", Dhuhr: "13:04", Asr: "16:35", Maghrib: "19:22", Isha: "20:43"}}}
	b, err := json.Marshal(yt)
	if err != nil {
		t.Fatal(err)
	}
	for _, key := range []string{`"schemaVersion":1`, `"source":"diyanet"`, `"cityId":9541`, `"complete":false`,
		`"hijri":{"day":4,"month":4,"year":1448,"monthName":"Rebiulahir"}`, `"maghrib":"19:22"`,
		`"astronomicalSunrise":null`, `"qiblaTime":null`, `"gmtOffset":null`} {
		if !contains(b, key) {
			t.Errorf("JSON missing %s in %s", key, b)
		}
	}
	if contains(b, `"via"`) {
		t.Error(`"via" must be omitted when empty`)
	}
}

func contains(b []byte, s string) bool { return json.Valid(b) && string(b) != "" && indexOf(string(b), s) >= 0 }

func indexOf(s, sub string) int {
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return i
		}
	}
	return -1
}
```

- [ ] **Step 2: Run, fail**

Run: `cd server && go test ./internal/model/`
Expected: FAIL — undefined symbols

- [ ] **Step 3: Implement**

`server/internal/model/model.go`:
```go
// Package model, /v1 sözleşmesinin yayın şemalarını ve Diyanet metinlerini
// ayrıştıran yardımcıları içerir. Alan adları spec VAK.1 ile birebirdir.
package model

import "time"

const (
	SchemaVersion = 1
	SourceDiyanet = "diyanet"
	ViaWeb        = "web"
	DateLayout    = "2006-01-02"
)

type Country struct {
	ID      int    `json:"id"`
	Name    string `json:"name"`
	NameEn  string `json:"nameEn"`
	Enabled bool   `json:"enabled"`
}

type State struct {
	ID        int    `json:"id"`
	Name      string `json:"name"`
	CountryID int    `json:"countryId"`
}

type City struct {
	ID                 int      `json:"id"`
	Name               string   `json:"name"`
	StateID            int      `json:"stateId"`
	CountryID          int      `json:"countryId"`
	Latitude           *float64 `json:"latitude"`
	Longitude          *float64 `json:"longitude"`
	QiblaAngle         *float64 `json:"qiblaAngle"`         // gerçek kuzey (Diyanet geographicQiblaAngle)
	QiblaAngleMagnetic *float64 `json:"qiblaAngleMagnetic"` // manyetik (Diyanet qiblaAngle)
	DistanceToKaaba    *float64 `json:"distanceToKaaba"`    // km
}

type CityWithState struct {
	City
	StateName string `json:"stateName"`
}

// CityDetail, Diyanet CityDetail ucundan gelen kıble bilgisidir; City'ye işlenir.
type CityDetail struct {
	CityID             int
	QiblaAngle         *float64
	QiblaAngleMagnetic *float64
	DistanceToKaaba    *float64
}

type Hijri struct {
	Day       int    `json:"day"`
	Month     int    `json:"month"`
	Year      int    `json:"year"`
	MonthName string `json:"monthName"`
}

type Day struct {
	Date                string  `json:"date"` // YYYY-MM-DD
	Hijri               Hijri   `json:"hijri"`
	Fajr                string  `json:"fajr"`
	Sunrise             string  `json:"sunrise"`
	Dhuhr               string  `json:"dhuhr"`
	Asr                 string  `json:"asr"`
	Maghrib             string  `json:"maghrib"`
	Isha                string  `json:"isha"`
	AstronomicalSunrise *string `json:"astronomicalSunrise"`
	AstronomicalSunset  *string `json:"astronomicalSunset"`
	QiblaTime           *string `json:"qiblaTime"`
	GMTOffset           *int    `json:"gmtOffset"`
}

// Clocks, doğrulama ve karşılaştırma için altı vakti sabit sırayla döner.
func (d Day) Clocks() [6]string {
	return [6]string{d.Fajr, d.Sunrise, d.Dhuhr, d.Asr, d.Maghrib, d.Isha}
}

var ClockNames = [6]string{"fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha"}

type YearTimes struct {
	SchemaVersion int       `json:"schemaVersion"`
	Source        string    `json:"source"`
	Via           string    `json:"via,omitempty"`
	GeneratedAt   time.Time `json:"generatedAt"`
	CityID        int       `json:"cityId"`
	Year          int       `json:"year"`
	Complete      bool      `json:"complete"`
	Days          []Day     `json:"days"`
}

type ReligiousDay struct {
	ID        int    `json:"id"`
	Date      string `json:"date"`
	Name      string `json:"name"`
	IsSpecial bool   `json:"isSpecial"`
	Hijri     Hijri  `json:"hijri"`
}

type DailyContent struct {
	Date         string  `json:"date"`
	DayOfYear    int     `json:"dayOfYear"`
	Verse        string  `json:"verse"`
	VerseSource  string  `json:"verseSource"`
	Hadith       string  `json:"hadith"`
	HadithSource string  `json:"hadithSource"`
	Prayer       string  `json:"prayer"`
	PrayerSource *string `json:"prayerSource"`
}
```

`server/internal/model/hijri.go`:
```go
package model

import (
	"fmt"
	"strconv"
	"strings"
)

// HijriMonths, Diyanet'in kullandığı yazımla kanonik ay adlarıdır (index+1 = ay).
var HijriMonths = [12]string{
	"Muharrem", "Safer", "Rebiulevvel", "Rebiulahir", "Cemaziyelevvel", "Cemaziyelahir",
	"Recep", "Şaban", "Ramazan", "Şevval", "Zilkade", "Zilhicce",
}

// foldTR, ay adı karşılaştırması için küçük harfe indirir ve şapkalı/noktalı
// varyantları (Rebiülahir, Zilkâde) kanonik yazıma yaklaştırır.
func foldTR(s string) string {
	s = strings.ToLower(strings.TrimSpace(s))
	return strings.NewReplacer("ü", "u", "â", "a", "î", "i", "û", "u").Replace(s)
}

func HijriMonthNumber(name string) (int, bool) {
	want := foldTR(name)
	for i, m := range HijriMonths {
		if foldTR(m) == want {
			return i + 1, true
		}
	}
	return 0, false
}

// ParseHijriLong "4 Rebiulahir 1448" biçimini ayrıştırır (web tablosu ve API hijriDateLong).
func ParseHijriLong(s string) (Hijri, error) {
	parts := strings.Fields(s)
	if len(parts) != 3 {
		return Hijri{}, fmt.Errorf("hijri long %q: expected 'day month year'", s)
	}
	day, err := strconv.Atoi(parts[0])
	if err != nil {
		return Hijri{}, fmt.Errorf("hijri long %q: day: %w", s, err)
	}
	month, ok := HijriMonthNumber(parts[1])
	if !ok {
		return Hijri{}, fmt.Errorf("hijri long %q: unknown month %q", s, parts[1])
	}
	year, err := strconv.Atoi(parts[2])
	if err != nil {
		return Hijri{}, fmt.Errorf("hijri long %q: year: %w", s, err)
	}
	return newHijri(day, month, year)
}

// ParseHijriShort "4.4.1448" biçimini ayrıştırır (API hijriDateShort).
func ParseHijriShort(s string) (Hijri, error) {
	parts := strings.Split(strings.TrimSpace(s), ".")
	if len(parts) != 3 {
		return Hijri{}, fmt.Errorf("hijri short %q: expected 'd.m.y'", s)
	}
	nums := [3]int{}
	for i, p := range parts {
		n, err := strconv.Atoi(p)
		if err != nil {
			return Hijri{}, fmt.Errorf("hijri short %q: %w", s, err)
		}
		nums[i] = n
	}
	return newHijri(nums[0], nums[1], nums[2])
}

func newHijri(day, month, year int) (Hijri, error) {
	if day < 1 || day > 30 {
		return Hijri{}, fmt.Errorf("hijri day %d out of range 1-30", day)
	}
	if month < 1 || month > 12 {
		return Hijri{}, fmt.Errorf("hijri month %d out of range 1-12", month)
	}
	if year < 1300 || year > 1700 {
		return Hijri{}, fmt.Errorf("hijri year %d implausible", year)
	}
	return Hijri{Day: day, Month: month, Year: year, MonthName: HijriMonths[month-1]}, nil
}
```

`server/internal/model/parse.go`:
```go
package model

import (
	"fmt"
	"strconv"
	"strings"
	"time"
)

var turkishMonths = map[string]time.Month{
	"ocak": time.January, "şubat": time.February, "mart": time.March, "nisan": time.April,
	"mayıs": time.May, "haziran": time.June, "temmuz": time.July, "ağustos": time.August,
	"eylül": time.September, "ekim": time.October, "kasım": time.November, "aralık": time.December,
}

// ParseTurkishDate "15 Eylül 2026 Salı" ya da "01 Ocak 2027" biçimini UTC gün başına çevirir.
func ParseTurkishDate(s string) (time.Time, error) {
	parts := strings.Fields(s)
	if len(parts) < 3 {
		return time.Time{}, fmt.Errorf("turkish date %q: expected 'day month year [weekday]'", s)
	}
	day, err := strconv.Atoi(parts[0])
	if err != nil {
		return time.Time{}, fmt.Errorf("turkish date %q: day: %w", s, err)
	}
	month, ok := turkishMonths[strings.ToLower(parts[1])]
	if !ok {
		return time.Time{}, fmt.Errorf("turkish date %q: unknown month %q", s, parts[1])
	}
	year, err := strconv.Atoi(parts[2])
	if err != nil {
		return time.Time{}, fmt.Errorf("turkish date %q: year: %w", s, err)
	}
	t := time.Date(year, month, day, 0, 0, 0, 0, time.UTC)
	if t.Day() != day || t.Month() != month { // 32 Eylül gibi taşmaları yakala
		return time.Time{}, fmt.Errorf("turkish date %q: invalid day of month", s)
	}
	return t, nil
}

// ClockMinutes "HH:MM" ya da "HH:MM:SS" duvar saatini gün başından itibaren dakikaya çevirir.
func ClockMinutes(s string) (int, error) {
	parts := strings.Split(strings.TrimSpace(s), ":")
	if len(parts) < 2 {
		return 0, fmt.Errorf("clock %q: expected HH:MM", s)
	}
	h, err := strconv.Atoi(parts[0])
	if err != nil || h < 0 || h > 23 {
		return 0, fmt.Errorf("clock %q: bad hour", s)
	}
	m, err := strconv.Atoi(parts[1])
	if err != nil || m < 0 || m > 59 {
		return 0, fmt.Errorf("clock %q: bad minute", s)
	}
	return h*60 + m, nil
}

// NormalizeClock "06:11:00" → "06:11"; "5:11" → "05:11".
func NormalizeClock(s string) (string, error) {
	mins, err := ClockMinutes(s)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%02d:%02d", mins/60, mins%60), nil
}
```

- [ ] **Step 4: Run, pass**

Run: `cd server && gofmt -l . && go vet ./... && go test ./internal/model/`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/internal/model
git commit -m "feat(server): /v1 yayın modelleri, Hicri ay tablosu ve Türkçe tarih ayrıştırma

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: `internal/store` — atomik yazma, ETag, yollar, sync state

**Files:**
- Create: `server/internal/store/store.go`, `server/internal/store/paths.go`, `server/internal/store/state.go`, `server/internal/store/store_test.go`

**Interfaces:**
- Consumes: `model.*` (Task 2)
- Produces: `type Store struct{ Root string }`; `New(root string) *Store`; `(*Store).WriteJSON(rel string, v any) error`; `(*Store).WriteRaw(rel string, data []byte) error`; `(*Store).Read(rel string) (data []byte, etag string, err error)` (yoksa `fs.ErrNotExist`); `(*Store).ReadJSON(rel string, v any) error`; `(*Store).Exists(rel string) bool`; `ETag([]byte) string`; yol üreticileri `CountriesPath()`, `StatesPath(countryID)`, `CitiesPath(stateID)`, `TRCitiesPath()`, `PrayerTimesPath(cityID, year)`, `ReligiousDaysPath(year)`, `DailyContentPath(t time.Time)`, `StatePath()`; `SyncState`, `CityYearState`, `PlacesState`, `DailyContentState`, `CityYearKey(cityID, year) string`, `(*Store).LoadState() (*SyncState, error)`, `(*Store).SaveState(*SyncState) error`.

- [ ] **Step 1: Failing tests**

`server/internal/store/store_test.go`:
```go
package store

import (
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestWriteJSON_WritesFileAtomicallyWithoutTempLeftovers(t *testing.T) {
	st := New(t.TempDir())
	if err := st.WriteJSON("prayer-times/9541/2026.json", map[string]int{"a": 1}); err != nil {
		t.Fatal(err)
	}
	data, etag, err := st.Read("prayer-times/9541/2026.json")
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != `{"a":1}` {
		t.Fatalf("data = %s", data)
	}
	if etag != ETag(data) || !strings.HasPrefix(etag, `"`) || len(etag) != 18 {
		t.Fatalf("etag = %q", etag)
	}
	entries, _ := os.ReadDir(filepath.Join(st.Root, "prayer-times", "9541"))
	for _, e := range entries {
		if strings.HasPrefix(e.Name(), ".tmp-") {
			t.Fatalf("temp file left behind: %s", e.Name())
		}
	}
}

func TestRead_MissingFileIsNotExist(t *testing.T) {
	st := New(t.TempDir())
	_, _, err := st.Read("prayer-times/1/2026.json")
	if !errors.Is(err, fs.ErrNotExist) {
		t.Fatalf("err = %v, want fs.ErrNotExist", err)
	}
	if st.Exists("prayer-times/1/2026.json") {
		t.Fatal("Exists must be false")
	}
}

func TestWriteJSON_OverwriteReplacesContent(t *testing.T) {
	st := New(t.TempDir())
	_ = st.WriteJSON("x.json", map[string]int{"v": 1})
	if err := st.WriteJSON("x.json", map[string]int{"v": 2}); err != nil {
		t.Fatal(err)
	}
	var got map[string]int
	if err := st.ReadJSON("x.json", &got); err != nil || got["v"] != 2 {
		t.Fatalf("got %v err %v", got, err)
	}
}

func TestETag_IsStableAndQuoted(t *testing.T) {
	a, b := ETag([]byte("abc")), ETag([]byte("abc"))
	if a != b || a != `"ba7816bf8f01cfea"` {
		t.Fatalf("etag = %s / %s", a, b)
	}
}

func TestPaths(t *testing.T) {
	cases := map[string]string{
		CountriesPath():                                 "places/countries.json",
		StatesPath(2):                                   "places/countries/2/states.json",
		CitiesPath(539):                                 "places/states/539/cities.json",
		TRCitiesPath():                                  "places/tr/cities.json",
		PrayerTimesPath(9541, 2026):                     "prayer-times/9541/2026.json",
		ReligiousDaysPath(2026):                         "religious-days/2026.json",
		DailyContentPath(time.Date(2026, 9, 15, 0, 0, 0, 0, time.UTC)): "daily-content/2026/258.json",
		StatePath():                                     "state/sync.json",
	}
	for got, want := range cases {
		if got != want {
			t.Errorf("path = %q want %q", got, want)
		}
	}
	if CityYearKey(9541, 2026) != "9541/2026" {
		t.Error("CityYearKey")
	}
}

func TestState_RoundTripAndEmptyDefault(t *testing.T) {
	st := New(t.TempDir())
	s, err := st.LoadState()
	if err != nil || s == nil || s.PrayerTimes == nil {
		t.Fatalf("empty state should load with maps initialised: %v %v", s, err)
	}
	s.PrayerTimes[CityYearKey(9541, 2026)] = CityYearState{Days: 31, Horizon: "2026-10-15"}
	if err := st.SaveState(s); err != nil {
		t.Fatal(err)
	}
	again, err := st.LoadState()
	if err != nil {
		t.Fatal(err)
	}
	if again.PrayerTimes["9541/2026"].Days != 31 {
		t.Fatalf("state not persisted: %+v", again)
	}
}
```

- [ ] **Step 2: Run, fail**

Run: `cd server && go test ./internal/store/`
Expected: FAIL — undefined

- [ ] **Step 3: Implement**

`server/internal/store/store.go`:
```go
// Package store, data/ dizinindeki JSON dosyalarını atomik yazar ve okur.
// Sync ile serve aynı dizini paylaşır; rename atomik olduğu için okuyucu
// yarım dosya görmez.
package store

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

type Store struct {
	Root string
}

func New(root string) *Store { return &Store{Root: root} }

func (s *Store) full(rel string) string {
	return filepath.Join(s.Root, filepath.FromSlash(rel))
}

// ETag, içeriğin SHA-256 özetinin ilk 16 hex karakterini tırnaklı döner (güçlü ETag).
func ETag(data []byte) string {
	sum := sha256.Sum256(data)
	return `"` + hex.EncodeToString(sum[:8]) + `"`
}

func (s *Store) WriteJSON(rel string, v any) error {
	data, err := json.Marshal(v)
	if err != nil {
		return fmt.Errorf("store: marshal %s: %w", rel, err)
	}
	return s.WriteRaw(rel, data)
}

// WriteRaw: geçici dosyaya yaz, fsync, 0644, sonra rename.
func (s *Store) WriteRaw(rel string, data []byte) error {
	full := s.full(rel)
	dir := filepath.Dir(full)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return fmt.Errorf("store: mkdir %s: %w", dir, err)
	}
	tmp, err := os.CreateTemp(dir, ".tmp-*")
	if err != nil {
		return fmt.Errorf("store: temp for %s: %w", rel, err)
	}
	tmpName := tmp.Name()
	fail := func(step string, err error) error {
		tmp.Close()
		os.Remove(tmpName)
		return fmt.Errorf("store: %s %s: %w", step, rel, err)
	}
	if _, err := tmp.Write(data); err != nil {
		return fail("write", err)
	}
	if err := tmp.Sync(); err != nil {
		return fail("sync", err)
	}
	if err := tmp.Close(); err != nil {
		os.Remove(tmpName)
		return fmt.Errorf("store: close %s: %w", rel, err)
	}
	if err := os.Chmod(tmpName, 0o644); err != nil {
		os.Remove(tmpName)
		return fmt.Errorf("store: chmod %s: %w", rel, err)
	}
	if err := os.Rename(tmpName, full); err != nil {
		os.Remove(tmpName)
		return fmt.Errorf("store: rename %s: %w", rel, err)
	}
	return nil
}

// Read dosyayı ve ETag'ini döner; dosya yoksa hata fs.ErrNotExist'i sarar.
func (s *Store) Read(rel string) ([]byte, string, error) {
	data, err := os.ReadFile(s.full(rel))
	if err != nil {
		return nil, "", err
	}
	return data, ETag(data), nil
}

func (s *Store) ReadJSON(rel string, v any) error {
	data, _, err := s.Read(rel)
	if err != nil {
		return err
	}
	if err := json.Unmarshal(data, v); err != nil {
		return fmt.Errorf("store: decode %s: %w", rel, err)
	}
	return nil
}

func (s *Store) Exists(rel string) bool {
	_, err := os.Stat(s.full(rel))
	return err == nil
}
```

`server/internal/store/paths.go`:
```go
package store

import (
	"fmt"
	"time"
)

func CountriesPath() string             { return "places/countries.json" }
func StatesPath(countryID int) string   { return fmt.Sprintf("places/countries/%d/states.json", countryID) }
func CitiesPath(stateID int) string     { return fmt.Sprintf("places/states/%d/cities.json", stateID) }
func TRCitiesPath() string              { return "places/tr/cities.json" }
func PrayerTimesPath(cityID, year int) string {
	return fmt.Sprintf("prayer-times/%d/%d.json", cityID, year)
}
func ReligiousDaysPath(year int) string { return fmt.Sprintf("religious-days/%d.json", year) }
func DailyContentPath(t time.Time) string {
	return fmt.Sprintf("daily-content/%d/%d.json", t.Year(), t.YearDay())
}
func StatePath() string                 { return "state/sync.json" }
func TokenPath() string                 { return "state/awqat_token.json" }
func CityYearKey(cityID, year int) string { return fmt.Sprintf("%d/%d", cityID, year) }
```

`server/internal/store/state.go`:
```go
package store

import (
	"errors"
	"io/fs"
	"time"
)

// SyncState, sync işlerinin ilerlemesini tutar; health bu dosyadan üretilir.
type SyncState struct {
	Places        PlacesState              `json:"places"`
	PrayerTimes   map[string]CityYearState `json:"prayerTimes"` // CityYearKey → durum
	ReligiousDays map[string]time.Time     `json:"religiousDays"` // yıl → updatedAt
	DailyContent  DailyContentState        `json:"dailyContent"`
	Rejected      int                      `json:"rejected"` // doğrulamadan geçmeyen yazım sayısı (kümülatif)
}

type PlacesState struct {
	UpdatedAt        time.Time `json:"updatedAt"`
	Countries        int       `json:"countries"`
	Cities           int       `json:"cities"`
	EnabledCountries []int     `json:"enabledCountries"`
}

type CityYearState struct {
	LastFetchedAt time.Time `json:"lastFetchedAt"`
	Horizon       string    `json:"horizon"` // dosyadaki son tarih (YYYY-MM-DD)
	Complete      bool      `json:"complete"`
	Days          int       `json:"days"`
	Note          string    `json:"note,omitempty"`
}

type DailyContentState struct {
	UpdatedAt time.Time `json:"updatedAt"`
	Days      int       `json:"days"`
}

func newSyncState() *SyncState {
	return &SyncState{
		PrayerTimes:   map[string]CityYearState{},
		ReligiousDays: map[string]time.Time{},
	}
}

// LoadState dosya yoksa boş durum döner; bozuk dosya hatadır (sessizce sıfırlanmaz).
func (s *Store) LoadState() (*SyncState, error) {
	st := newSyncState()
	err := s.ReadJSON(StatePath(), st)
	if errors.Is(err, fs.ErrNotExist) {
		return newSyncState(), nil
	}
	if err != nil {
		return nil, err
	}
	if st.PrayerTimes == nil {
		st.PrayerTimes = map[string]CityYearState{}
	}
	if st.ReligiousDays == nil {
		st.ReligiousDays = map[string]time.Time{}
	}
	return st, nil
}

func (s *Store) SaveState(st *SyncState) error { return s.WriteJSON(StatePath(), st) }
```

- [ ] **Step 4: Run, pass**

Run: `cd server && gofmt -l . && go vet ./... && go test ./internal/store/`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/internal/store
git commit -m "feat(server): atomik JSON store, ETag, veri yolları ve sync state

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: `internal/validate` — VAK.5 kuralları

**Files:**
- Create: `server/internal/validate/validate.go`, `server/internal/validate/validate_test.go`

**Interfaces:**
- Consumes: `model.Day`, `model.ReligiousDay`, `model.ClockMinutes`, `model.HijriMonthNumber`
- Produces: `type Problem struct{ Rule, Date, Detail string }` (`Error()`); `const MaxYearOverYearDriftMinutes = 5`; `DaysInYear(year int) int`; `IsComplete(days []model.Day, year int) bool`; `YearTimes(days []model.Day, year int, previous []model.Day) error`; `ReligiousDays(list []model.ReligiousDay, year int) error`.

- [ ] **Step 1: Failing tests**

`server/internal/validate/validate_test.go`:
```go
package validate

import (
	"errors"
	"testing"
	"time"

	"vakit/internal/model"
)

func day(date string, hijri model.Hijri, clocks ...string) model.Day {
	return model.Day{Date: date, Hijri: hijri, Fajr: clocks[0], Sunrise: clocks[1], Dhuhr: clocks[2],
		Asr: clocks[3], Maghrib: clocks[4], Isha: clocks[5]}
}

func goodDays(year int, n int) []model.Day {
	start := time.Date(year, 9, 1, 0, 0, 0, 0, time.UTC)
	days := make([]model.Day, 0, n)
	h := model.Hijri{Day: 19, Month: 3, Year: 1448, MonthName: "Rebiulevvel"}
	for i := 0; i < n; i++ {
		days = append(days, day(start.AddDate(0, 0, i).Format(model.DateLayout), h,
			"05:00", "06:30", "13:00", "16:30", "19:20", "20:40"))
		h.Day++
		if h.Day > 30 {
			h.Day, h.Month = 1, h.Month+1
		}
	}
	return days
}

func ruleOf(t *testing.T, err error) string {
	t.Helper()
	var p *Problem
	if !errors.As(err, &p) {
		t.Fatalf("expected *Problem, got %v", err)
	}
	return p.Rule
}

func TestYearTimes_AcceptsWellFormedPartialYear(t *testing.T) {
	if err := YearTimes(goodDays(2026, 31), 2026, nil); err != nil {
		t.Fatal(err)
	}
}

func TestYearTimes_RejectsEmpty(t *testing.T) {
	if got := ruleOf(t, YearTimes(nil, 2026, nil)); got != "nonempty" {
		t.Fatal(got)
	}
}

func TestYearTimes_RejectsDateOutsideYear(t *testing.T) {
	d := goodDays(2026, 2)
	d[1].Date = "2027-01-01"
	if got := ruleOf(t, YearTimes(d, 2026, nil)); got != "year" {
		t.Fatal(got)
	}
}

func TestYearTimes_RejectsDuplicateOrUnsortedDates(t *testing.T) {
	d := goodDays(2026, 3)
	d[2].Date = d[1].Date
	if got := ruleOf(t, YearTimes(d, 2026, nil)); got != "order" {
		t.Fatal(got)
	}
}

func TestYearTimes_RejectsPrayerOrderViolation(t *testing.T) {
	d := goodDays(2026, 1)
	d[0].Asr = "12:00" // dhuhr'dan önce
	if got := ruleOf(t, YearTimes(d, 2026, nil)); got != "prayer-order" {
		t.Fatal(got)
	}
}

func TestYearTimes_RejectsBadClock(t *testing.T) {
	d := goodDays(2026, 1)
	d[0].Isha = "25:00"
	if got := ruleOf(t, YearTimes(d, 2026, nil)); got != "clock" {
		t.Fatal(got)
	}
}

func TestYearTimes_RejectsYearOverYearDrift(t *testing.T) {
	cur := goodDays(2026, 1)
	prev := goodDays(2025, 1) // aynı ay-gün: 09-01
	prev[0].Maghrib = "19:26" // 6 dk fark
	if got := ruleOf(t, YearTimes(cur, 2026, prev)); got != "drift" {
		t.Fatal(got)
	}
	prev[0].Maghrib = "19:25" // 5 dk sınırda kabul
	if err := YearTimes(cur, 2026, prev); err != nil {
		t.Fatal(err)
	}
}

func TestYearTimes_HijriStepMustBePlusOneOrResetToOne(t *testing.T) {
	d := goodDays(2026, 2)
	d[1].Hijri.Day = d[0].Hijri.Day + 2
	if got := ruleOf(t, YearTimes(d, 2026, nil)); got != "hijri-step" {
		t.Fatal(got)
	}
	d = goodDays(2026, 2)
	d[0].Hijri = model.Hijri{Day: 29, Month: 12, Year: 1447, MonthName: "Zilhicce"}
	d[1].Hijri = model.Hijri{Day: 1, Month: 1, Year: 1448, MonthName: "Muharrem"}
	if err := YearTimes(d, 2026, nil); err != nil {
		t.Fatalf("year rollover must be accepted: %v", err)
	}
}

func TestYearTimes_GapBetweenDatesIsAllowedAndSkipsHijriStep(t *testing.T) {
	d := goodDays(2026, 3)
	d = []model.Day{d[0], d[2]} // 1 günlük boşluk, hicri gün +2
	if err := YearTimes(d, 2026, nil); err != nil {
		t.Fatal(err)
	}
}

func TestYearTimes_RejectsHijriMonthNameMismatch(t *testing.T) {
	d := goodDays(2026, 1)
	d[0].Hijri.MonthName = "Ramazan" // ay 3 ile uyumsuz
	if got := ruleOf(t, YearTimes(d, 2026, nil)); got != "hijri" {
		t.Fatal(got)
	}
}

func TestIsCompleteAndDaysInYear(t *testing.T) {
	if DaysInYear(2028) != 366 || DaysInYear(2026) != 365 || DaysInYear(2100) != 365 {
		t.Fatal("leap rules")
	}
	if IsComplete(goodDays(2026, 31), 2026) {
		t.Fatal("31 days is not complete")
	}
}

func TestReligiousDays(t *testing.T) {
	ok := []model.ReligiousDay{
		{ID: 1, Date: "2026-01-15", Name: "Miraç Kandili", Hijri: model.Hijri{26, 7, 1447, "Recep"}},
		{ID: 2, Date: "2026-01-20", Name: "Şaban Ayı Başlangıcı", Hijri: model.Hijri{1, 8, 1447, "Şaban"}},
		{ID: 3, Date: "2026-01-20", Name: "Aynı güne ikinci kayıt", Hijri: model.Hijri{1, 8, 1447, "Şaban"}},
	}
	if err := ReligiousDays(ok, 2026); err != nil {
		t.Fatal(err)
	}
	bad := append([]model.ReligiousDay{}, ok...)
	bad[1].Date = "2026-01-10" // sıra bozuk
	if got := ruleOf(t, ReligiousDays(bad, 2026)); got != "order" {
		t.Fatal(got)
	}
	bad = append([]model.ReligiousDay{}, ok...)
	bad[0].Name = ""
	if got := ruleOf(t, ReligiousDays(bad, 2026)); got != "name" {
		t.Fatal(got)
	}
	bad = append([]model.ReligiousDay{}, ok...)
	bad[0].Date = "2025-12-31"
	if got := ruleOf(t, ReligiousDays(bad, 2026)); got != "year" {
		t.Fatal(got)
	}
	if err := ReligiousDays(nil, 2026); err == nil {
		t.Fatal("empty list must fail")
	}
}
```

- [ ] **Step 2: Run, fail**

Run: `cd server && go test ./internal/validate/`
Expected: FAIL — undefined

- [ ] **Step 3: Implement**

`server/internal/validate/validate.go`:
```go
// Package validate, yayın öncesi veri kurallarını (spec VAK.5) uygular.
// Kural ihlali dosya yazımını engeller; hata *Problem olarak döner.
package validate

import (
	"fmt"
	"time"

	"vakit/internal/model"
)

const MaxYearOverYearDriftMinutes = 5

type Problem struct {
	Rule   string // nonempty | date | year | order | clock | prayer-order | hijri | hijri-step | drift | name
	Date   string
	Detail string
}

func (p *Problem) Error() string {
	if p.Date == "" {
		return fmt.Sprintf("validate[%s]: %s", p.Rule, p.Detail)
	}
	return fmt.Sprintf("validate[%s] %s: %s", p.Rule, p.Date, p.Detail)
}

func isLeap(year int) bool { return year%4 == 0 && (year%100 != 0 || year%400 == 0) }

func DaysInYear(year int) int {
	if isLeap(year) {
		return 366
	}
	return 365
}

func IsComplete(days []model.Day, year int) bool { return len(days) == DaysInYear(year) }

// YearTimes: tarihler yıl içinde, tekrar yok, artan; vakit sırası; Hicri sağlamlığı;
// ardışık günde Hicri adımı; önceki yılın aynı ay-günüyle ±5 dk. Boşluk izinli.
func YearTimes(days []model.Day, year int, previous []model.Day) error {
	if len(days) == 0 {
		return &Problem{Rule: "nonempty", Detail: "no days"}
	}
	prevByMonthDay := make(map[string]model.Day, len(previous))
	for _, p := range previous {
		if t, err := time.Parse(model.DateLayout, p.Date); err == nil {
			prevByMonthDay[t.Format("01-02")] = p
		}
	}
	var lastDate time.Time
	var lastDay *model.Day
	for i := range days {
		d := &days[i]
		t, err := time.Parse(model.DateLayout, d.Date)
		if err != nil {
			return &Problem{Rule: "date", Date: d.Date, Detail: "not YYYY-MM-DD"}
		}
		if t.Year() != year {
			return &Problem{Rule: "year", Date: d.Date, Detail: fmt.Sprintf("outside %d", year)}
		}
		if lastDay != nil && !t.After(lastDate) {
			return &Problem{Rule: "order", Date: d.Date, Detail: "dates must be strictly ascending"}
		}
		if err := checkClocks(d); err != nil {
			return err
		}
		if err := checkHijri(d); err != nil {
			return err
		}
		if lastDay != nil && t.Sub(lastDate) == 24*time.Hour {
			if err := checkHijriStep(lastDay, d); err != nil {
				return err
			}
		}
		if p, ok := prevByMonthDay[t.Format("01-02")]; ok {
			if err := checkDrift(d, &p); err != nil {
				return err
			}
		}
		lastDate, lastDay = t, d
	}
	return nil
}

func checkClocks(d *model.Day) error {
	clocks := d.Clocks()
	prev := -1
	for i, c := range clocks {
		mins, err := model.ClockMinutes(c)
		if err != nil {
			return &Problem{Rule: "clock", Date: d.Date, Detail: fmt.Sprintf("%s=%q", model.ClockNames[i], c)}
		}
		if mins <= prev {
			return &Problem{Rule: "prayer-order", Date: d.Date,
				Detail: fmt.Sprintf("%s (%s) not after %s", model.ClockNames[i], c, model.ClockNames[i-1])}
		}
		prev = mins
	}
	return nil
}

func checkHijri(d *model.Day) error {
	h := d.Hijri
	if h.Day < 1 || h.Day > 30 || h.Month < 1 || h.Month > 12 {
		return &Problem{Rule: "hijri", Date: d.Date, Detail: fmt.Sprintf("day=%d month=%d", h.Day, h.Month)}
	}
	if n, ok := model.HijriMonthNumber(h.MonthName); !ok || n != h.Month {
		return &Problem{Rule: "hijri", Date: d.Date, Detail: fmt.Sprintf("monthName %q != month %d", h.MonthName, h.Month)}
	}
	return nil
}

// checkHijriStep: ertesi gün ya aynı ayda +1 gündür ya da bir sonraki ayın 1'i (yıl devri dahil).
func checkHijriStep(prev, cur *model.Day) error {
	p, c := prev.Hijri, cur.Hijri
	sameMonthNext := c.Year == p.Year && c.Month == p.Month && c.Day == p.Day+1
	nextMonthFirst := c.Day == 1 && ((c.Year == p.Year && c.Month == p.Month+1) ||
		(p.Month == 12 && c.Month == 1 && c.Year == p.Year+1))
	if sameMonthNext || nextMonthFirst {
		return nil
	}
	return &Problem{Rule: "hijri-step", Date: cur.Date,
		Detail: fmt.Sprintf("%d.%d.%d after %d.%d.%d", c.Day, c.Month, c.Year, p.Day, p.Month, p.Year)}
}

func checkDrift(cur, prev *model.Day) error {
	cc, pc := cur.Clocks(), prev.Clocks()
	for i := range cc {
		a, errA := model.ClockMinutes(cc[i])
		b, errB := model.ClockMinutes(pc[i])
		if errA != nil || errB != nil {
			continue // önceki yılın bozuk değeri bu yılı reddettirmez; cur zaten checkClocks'tan geçti
		}
		if diff := a - b; diff > MaxYearOverYearDriftMinutes || diff < -MaxYearOverYearDriftMinutes {
			return &Problem{Rule: "drift", Date: cur.Date,
				Detail: fmt.Sprintf("%s %s vs previous year %s (%d min)", model.ClockNames[i], cc[i], pc[i], diff)}
		}
	}
	return nil
}

// ReligiousDays: tarihler yıl içinde ve azalmayan; ad boş değil; Hicri sağlam.
func ReligiousDays(list []model.ReligiousDay, year int) error {
	if len(list) == 0 {
		return &Problem{Rule: "nonempty", Detail: "no religious days"}
	}
	var last time.Time
	for i, r := range list {
		t, err := time.Parse(model.DateLayout, r.Date)
		if err != nil {
			return &Problem{Rule: "date", Date: r.Date, Detail: "not YYYY-MM-DD"}
		}
		if t.Year() != year {
			return &Problem{Rule: "year", Date: r.Date, Detail: fmt.Sprintf("outside %d", year)}
		}
		if i > 0 && t.Before(last) {
			return &Problem{Rule: "order", Date: r.Date, Detail: "dates must be non-decreasing"}
		}
		if r.Name == "" {
			return &Problem{Rule: "name", Date: r.Date, Detail: "empty name"}
		}
		if err := checkHijri(&model.Day{Date: r.Date, Hijri: r.Hijri}); err != nil {
			return err
		}
		last = t
	}
	return nil
}
```

- [ ] **Step 4: Run, pass**

Run: `cd server && gofmt -l . && go vet ./... && go test ./internal/validate/`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/internal/validate
git commit -m "feat(server): yayın öncesi doğrulama kuralları (VAK.5)

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: `internal/config` + `internal/httpapi` + `vakit serve`

**Files:**
- Create: `server/internal/config/config.go`, `server/internal/config/config_test.go`, `server/internal/httpapi/handler.go`, `server/internal/httpapi/errors.go`, `server/internal/httpapi/health.go`, `server/internal/httpapi/middleware.go`, `server/internal/httpapi/handler_test.go`, `server/cmd/vakit/serve.go`
- Modify: `server/cmd/vakit/main.go` (switch'e `serve` dalı)

**Interfaces:**
- Consumes: `store.Store`, `store.SyncState` (Task 3)
- Produces: `config.Config{AwqatEmail, AwqatPassword, AwqatBaseURL, Source, DataDir, Addr, EnabledCountries []int, SyncBatch int, SyncInterval time.Duration, LogLevel slog.Level}`; `config.FromEnv(getenv func(string) string) (Config, error)`; `config.SourceAwqat = "awqat"`, `config.SourceWeb = "web"`; `httpapi.NewHandler(st *store.Store, opts httpapi.Options, logger *slog.Logger) http.Handler` (`Options{Version string; StartedAt time.Time}`); `httpapi.NewLogger(w io.Writer, level slog.Level) *slog.Logger`; `runServe(args, stdout, stderr) int`.

- [ ] **Step 1: Failing config tests**

`server/internal/config/config_test.go`:
```go
package config

import (
	"log/slog"
	"testing"
	"time"
)

func env(m map[string]string) func(string) string {
	return func(k string) string { return m[k] }
}

func TestFromEnv_DefaultsToWebWhenNoCredentials(t *testing.T) {
	cfg, err := FromEnv(env(nil))
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Source != SourceWeb || cfg.DataDir != "./data" || cfg.Addr != "127.0.0.1:8080" ||
		len(cfg.EnabledCountries) != 1 || cfg.EnabledCountries[0] != 2 || cfg.SyncBatch != 150 ||
		cfg.SyncInterval != 500*time.Millisecond || cfg.LogLevel != slog.LevelInfo ||
		cfg.AwqatBaseURL != "https://awqatsalah.diyanet.gov.tr" {
		t.Fatalf("unexpected defaults: %+v", cfg)
	}
}

func TestFromEnv_DefaultsToAwqatWhenCredentialsPresent(t *testing.T) {
	cfg, err := FromEnv(env(map[string]string{"AWQAT_EMAIL": "a@b.c", "AWQAT_PASSWORD": "x"}))
	if err != nil || cfg.Source != SourceAwqat {
		t.Fatalf("cfg=%+v err=%v", cfg, err)
	}
}

func TestFromEnv_AwqatWithoutCredentialsIsError(t *testing.T) {
	if _, err := FromEnv(env(map[string]string{"VAKIT_SOURCE": "awqat"})); err == nil {
		t.Fatal("expected error")
	}
}

func TestFromEnv_ParsesLists_Durations_Levels(t *testing.T) {
	cfg, err := FromEnv(env(map[string]string{
		"VAKIT_ENABLED_COUNTRIES": "2, 1", "VAKIT_SYNC_BATCH": "20", "VAKIT_SYNC_INTERVAL": "2s",
		"VAKIT_LOG_LEVEL": "debug", "VAKIT_ADDR": "127.0.0.1:9090", "VAKIT_DATA_DIR": "/data",
	}))
	if err != nil {
		t.Fatal(err)
	}
	if len(cfg.EnabledCountries) != 2 || cfg.EnabledCountries[1] != 1 || cfg.SyncBatch != 20 ||
		cfg.SyncInterval != 2*time.Second || cfg.LogLevel != slog.LevelDebug || cfg.Addr != "127.0.0.1:9090" {
		t.Fatalf("%+v", cfg)
	}
	for _, bad := range []map[string]string{
		{"VAKIT_ENABLED_COUNTRIES": "2,x"}, {"VAKIT_SYNC_BATCH": "0"}, {"VAKIT_SYNC_INTERVAL": "soon"},
		{"VAKIT_LOG_LEVEL": "loud"}, {"VAKIT_SOURCE": "ftp"},
	} {
		if _, err := FromEnv(env(bad)); err == nil {
			t.Errorf("expected error for %v", bad)
		}
	}
}
```

- [ ] **Step 2: Implement config**

`server/internal/config/config.go`:
```go
// Package config, ortam değişkenlerini Config'e çevirir (spec VAK.8).
package config

import (
	"fmt"
	"log/slog"
	"strconv"
	"strings"
	"time"
)

const (
	SourceAwqat = "awqat"
	SourceWeb   = "web"

	defaultBaseURL  = "https://awqatsalah.diyanet.gov.tr"
	defaultDataDir  = "./data"
	defaultAddr     = "127.0.0.1:8080"
	defaultBatch    = 150
	defaultInterval = 500 * time.Millisecond
	turkeyCountryID = 2
)

type Config struct {
	AwqatEmail       string
	AwqatPassword    string
	AwqatBaseURL     string
	Source           string
	DataDir          string
	Addr             string
	EnabledCountries []int
	SyncBatch        int
	SyncInterval     time.Duration
	LogLevel         slog.Level
}

func FromEnv(getenv func(string) string) (Config, error) {
	cfg := Config{
		AwqatEmail:       getenv("AWQAT_EMAIL"),
		AwqatPassword:    getenv("AWQAT_PASSWORD"),
		AwqatBaseURL:     orDefault(getenv("AWQAT_BASE_URL"), defaultBaseURL),
		DataDir:          orDefault(getenv("VAKIT_DATA_DIR"), defaultDataDir),
		Addr:             orDefault(getenv("VAKIT_ADDR"), defaultAddr),
		EnabledCountries: []int{turkeyCountryID},
		SyncBatch:        defaultBatch,
		SyncInterval:     defaultInterval,
		LogLevel:         slog.LevelInfo,
	}
	hasCreds := cfg.AwqatEmail != "" && cfg.AwqatPassword != ""
	switch src := getenv("VAKIT_SOURCE"); src {
	case "":
		cfg.Source = SourceWeb
		if hasCreds {
			cfg.Source = SourceAwqat
		}
	case SourceAwqat:
		if !hasCreds {
			return cfg, fmt.Errorf("config: VAKIT_SOURCE=awqat requires AWQAT_EMAIL and AWQAT_PASSWORD")
		}
		cfg.Source = SourceAwqat
	case SourceWeb:
		cfg.Source = SourceWeb
	default:
		return cfg, fmt.Errorf("config: VAKIT_SOURCE=%q must be awqat or web", src)
	}
	if v := getenv("VAKIT_ENABLED_COUNTRIES"); v != "" {
		ids, err := parseIntList(v)
		if err != nil {
			return cfg, fmt.Errorf("config: VAKIT_ENABLED_COUNTRIES: %w", err)
		}
		cfg.EnabledCountries = ids
	}
	if v := getenv("VAKIT_SYNC_BATCH"); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil || n < 1 {
			return cfg, fmt.Errorf("config: VAKIT_SYNC_BATCH=%q must be a positive integer", v)
		}
		cfg.SyncBatch = n
	}
	if v := getenv("VAKIT_SYNC_INTERVAL"); v != "" {
		d, err := time.ParseDuration(v)
		if err != nil || d < 0 {
			return cfg, fmt.Errorf("config: VAKIT_SYNC_INTERVAL=%q must be a duration like 500ms", v)
		}
		cfg.SyncInterval = d
	}
	if v := getenv("VAKIT_LOG_LEVEL"); v != "" {
		var lvl slog.Level
		if err := lvl.UnmarshalText([]byte(strings.ToUpper(v))); err != nil {
			return cfg, fmt.Errorf("config: VAKIT_LOG_LEVEL=%q must be debug|info|warn|error", v)
		}
		cfg.LogLevel = lvl
	}
	return cfg, nil
}

func orDefault(v, def string) string {
	if strings.TrimSpace(v) == "" {
		return def
	}
	return v
}

func parseIntList(v string) ([]int, error) {
	var out []int
	for _, part := range strings.Split(v, ",") {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		n, err := strconv.Atoi(part)
		if err != nil {
			return nil, fmt.Errorf("%q is not an integer", part)
		}
		out = append(out, n)
	}
	if len(out) == 0 {
		return nil, fmt.Errorf("empty list")
	}
	return out, nil
}
```

Run: `cd server && go test ./internal/config/` → PASS

- [ ] **Step 3: Failing httpapi tests**

`server/internal/httpapi/handler_test.go`:
```go
package httpapi

import (
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"vakit/internal/model"
	"vakit/internal/store"
)

func newTestHandler(t *testing.T) (http.Handler, *store.Store) {
	t.Helper()
	st := store.New(t.TempDir())
	yt := model.YearTimes{SchemaVersion: 1, Source: "diyanet", CityID: 9541, Year: 2026, Days: []model.Day{
		{Date: "2026-09-15", Hijri: model.Hijri{4, 4, 1448, "Rebiulahir"}, Fajr: "05:11", Sunrise: "06:37",
			Dhuhr: "13:04", Asr: "16:35", Maghrib: "19:22", Isha: "20:43"}}}
	if err := st.WriteJSON(store.PrayerTimesPath(9541, 2026), yt); err != nil {
		t.Fatal(err)
	}
	_ = st.WriteJSON(store.CountriesPath(), []model.Country{{ID: 2, Name: "TÜRKİYE", NameEn: "TURKEY", Enabled: true}})
	state, _ := st.LoadState()
	state.PrayerTimes[store.CityYearKey(9541, 2026)] = store.CityYearState{Days: 1, Horizon: "2026-09-15",
		LastFetchedAt: time.Date(2026, 9, 15, 20, 0, 0, 0, time.UTC)}
	state.PrayerTimes[store.CityYearKey(9547, 2026)] = store.CityYearState{Days: 365, Complete: true,
		LastFetchedAt: time.Date(2026, 9, 16, 3, 0, 0, 0, time.UTC)}
	_ = st.SaveState(state)
	logger := NewLogger(io.Discard, slog.LevelDebug)
	return NewHandler(st, Options{Version: "test", StartedAt: time.Now()}, logger), st
}

func get(t *testing.T, h http.Handler, method, target string, hdr map[string]string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(method, target, nil)
	for k, v := range hdr {
		req.Header.Set(k, v)
	}
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

func errorCode(t *testing.T, body string) string {
	t.Helper()
	var e struct {
		Error struct{ Code, Message string } `json:"error"`
	}
	if err := json.Unmarshal([]byte(body), &e); err != nil || e.Error.Code == "" || e.Error.Message == "" {
		t.Fatalf("body is not an error envelope: %s", body)
	}
	return e.Error.Code
}

func TestPrayerTimes_OKWithCacheHeaders(t *testing.T) {
	h, _ := newTestHandler(t)
	rec := get(t, h, "GET", "/v1/prayer-times/9541/2026", nil)
	if rec.Code != 200 {
		t.Fatalf("code %d body %s", rec.Code, rec.Body.String())
	}
	if ct := rec.Header().Get("Content-Type"); ct != "application/json; charset=utf-8" {
		t.Fatal(ct)
	}
	if cc := rec.Header().Get("Cache-Control"); cc != "public, max-age=86400, stale-while-revalidate=604800" {
		t.Fatal(cc)
	}
	if et := rec.Header().Get("ETag"); !strings.HasPrefix(et, `"`) {
		t.Fatal(et)
	}
	if rec.Header().Get("X-Request-Id") == "" {
		t.Fatal("missing X-Request-Id")
	}
	if !strings.Contains(rec.Body.String(), `"maghrib":"19:22"`) {
		t.Fatal(rec.Body.String())
	}
}

func TestPrayerTimes_IfNoneMatchReturns304(t *testing.T) {
	h, _ := newTestHandler(t)
	first := get(t, h, "GET", "/v1/prayer-times/9541/2026", nil)
	etag := first.Header().Get("ETag")
	rec := get(t, h, "GET", "/v1/prayer-times/9541/2026", map[string]string{"If-None-Match": etag})
	if rec.Code != 304 || rec.Body.Len() != 0 {
		t.Fatalf("code %d len %d", rec.Code, rec.Body.Len())
	}
	if rec.Header().Get("ETag") != etag {
		t.Fatal("304 must carry ETag")
	}
	weak := get(t, h, "GET", "/v1/prayer-times/9541/2026", map[string]string{"If-None-Match": "W/" + etag + `, "other"`})
	if weak.Code != 304 {
		t.Fatalf("weak/list match failed: %d", weak.Code)
	}
}

func TestPrayerTimes_HeadHasLengthNoBody(t *testing.T) {
	h, _ := newTestHandler(t)
	rec := get(t, h, "HEAD", "/v1/prayer-times/9541/2026", nil)
	if rec.Code != 200 || rec.Body.Len() != 0 || rec.Header().Get("Content-Length") == "" {
		t.Fatalf("code %d len %d cl %q", rec.Code, rec.Body.Len(), rec.Header().Get("Content-Length"))
	}
}

func TestPrayerTimes_UnknownCityIs404Envelope(t *testing.T) {
	h, _ := newTestHandler(t)
	rec := get(t, h, "GET", "/v1/prayer-times/1/2026", nil)
	if rec.Code != 404 || errorCode(t, rec.Body.String()) != "NOT_FOUND" {
		t.Fatalf("%d %s", rec.Code, rec.Body.String())
	}
}

func TestPrayerTimes_BadParamsAre400(t *testing.T) {
	h, _ := newTestHandler(t)
	for _, target := range []string{"/v1/prayer-times/abc/2026", "/v1/prayer-times/9541/1999", "/v1/prayer-times/9541/2101",
		"/v1/prayer-times/-1/2026", "/v1/religious-days/20x6", "/v1/daily-content/2026-13-01", "/v1/places/countries/x/states"} {
		rec := get(t, h, "GET", target, nil)
		if rec.Code != 400 || errorCode(t, rec.Body.String()) != "INVALID_PARAMETER" {
			t.Errorf("%s: %d %s", target, rec.Code, rec.Body.String())
		}
	}
}

func TestMethodNotAllowedIsJSON(t *testing.T) {
	h, _ := newTestHandler(t)
	rec := get(t, h, "POST", "/v1/prayer-times/9541/2026", nil)
	if rec.Code != 405 || errorCode(t, rec.Body.String()) != "METHOD_NOT_ALLOWED" || rec.Header().Get("Allow") != "GET, HEAD" {
		t.Fatalf("%d %s allow=%q", rec.Code, rec.Body.String(), rec.Header().Get("Allow"))
	}
}

func TestUnknownPathIs404Envelope(t *testing.T) {
	h, _ := newTestHandler(t)
	rec := get(t, h, "GET", "/v1/nope", nil)
	if rec.Code != 404 || errorCode(t, rec.Body.String()) != "NOT_FOUND" {
		t.Fatalf("%d %s", rec.Code, rec.Body.String())
	}
}

func TestPlaces_CountriesUsesWeeklyCache(t *testing.T) {
	h, _ := newTestHandler(t)
	rec := get(t, h, "GET", "/v1/places/countries", nil)
	if rec.Code != 200 || rec.Header().Get("Cache-Control") != "public, max-age=604800, stale-while-revalidate=604800" {
		t.Fatalf("%d %s", rec.Code, rec.Header().Get("Cache-Control"))
	}
}

func TestHealth_NoStoreAndDatasetSummary(t *testing.T) {
	h, _ := newTestHandler(t)
	rec := get(t, h, "GET", "/v1/health", nil)
	if rec.Code != 200 || rec.Header().Get("Cache-Control") != "no-store" {
		t.Fatalf("%d %s", rec.Code, rec.Header().Get("Cache-Control"))
	}
	var body struct {
		Status   string `json:"status"`
		Version  string `json:"version"`
		Datasets struct {
			PrayerTimes map[string]struct {
				Cities   int  `json:"cities"`
				Complete bool `json:"complete"`
			} `json:"prayerTimes"`
		} `json:"datasets"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if body.Status != "ok" || body.Version != "test" || body.Datasets.PrayerTimes["2026"].Cities != 2 || body.Datasets.PrayerTimes["2026"].Complete {
		t.Fatalf("%s", rec.Body.String())
	}
}
```

- [ ] **Step 4: Run, fail**

Run: `cd server && go test ./internal/httpapi/`
Expected: FAIL — undefined

- [ ] **Step 5: Implement httpapi**

`server/internal/httpapi/errors.go`:
```go
package httpapi

import (
	"encoding/json"
	"net/http"
)

type apiError struct {
	Status  int
	Code    string
	Message string
}

func errInvalidParam(msg string) *apiError {
	return &apiError{Status: http.StatusBadRequest, Code: "INVALID_PARAMETER", Message: msg}
}

var (
	errNotFound = &apiError{Status: http.StatusNotFound, Code: "NOT_FOUND", Message: "resource is not published"}
	errMethod   = &apiError{Status: http.StatusMethodNotAllowed, Code: "METHOD_NOT_ALLOWED", Message: "only GET and HEAD are supported"}
	errInternal = &apiError{Status: http.StatusInternalServerError, Code: "INTERNAL", Message: "internal error"}
)

// writeError, spec VAK.1 hata zarfını yazar: {"error":{"code","message"}}.
func writeError(w http.ResponseWriter, e *apiError) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(e.Status)
	_ = json.NewEncoder(w).Encode(map[string]any{"error": map[string]string{"code": e.Code, "message": e.Message}})
}
```

`server/internal/httpapi/handler.go`:
```go
// Package httpapi, data/ dizinindeki yayın dosyalarını /v1 sözleşmesiyle sunar.
// Yol parametreleri sayı/tarih olarak ayrıştırılır; dosya yolu bu değerlerden
// üretilir, kullanıcı girdisi dosya sistemine ham geçmez.
package httpapi

import (
	"errors"
	"io/fs"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"time"

	"vakit/internal/model"
	"vakit/internal/store"
)

const (
	cacheDaily  = "public, max-age=86400, stale-while-revalidate=604800"
	cacheWeekly = "public, max-age=604800, stale-while-revalidate=604800"
	minYear     = 2000
	maxYear     = 2100
)

type Options struct {
	Version   string
	StartedAt time.Time
}

type handler struct {
	st     *store.Store
	opts   Options
	logger *slog.Logger
}

type resolver func(r *http.Request) (rel string, err *apiError)

func NewHandler(st *store.Store, opts Options, logger *slog.Logger) http.Handler {
	h := &handler{st: st, opts: opts, logger: logger}
	mux := http.NewServeMux()
	mux.HandleFunc("/v1/places/countries", h.file(cacheWeekly, func(*http.Request) (string, *apiError) {
		return store.CountriesPath(), nil
	}))
	mux.HandleFunc("/v1/places/countries/{countryId}/states", h.file(cacheWeekly, func(r *http.Request) (string, *apiError) {
		id, err := pathID(r, "countryId")
		if err != nil {
			return "", err
		}
		return store.StatesPath(id), nil
	}))
	mux.HandleFunc("/v1/places/states/{stateId}/cities", h.file(cacheWeekly, func(r *http.Request) (string, *apiError) {
		id, err := pathID(r, "stateId")
		if err != nil {
			return "", err
		}
		return store.CitiesPath(id), nil
	}))
	mux.HandleFunc("/v1/places/tr/cities", h.file(cacheWeekly, func(*http.Request) (string, *apiError) {
		return store.TRCitiesPath(), nil
	}))
	mux.HandleFunc("/v1/prayer-times/{cityId}/{year}", h.file(cacheDaily, func(r *http.Request) (string, *apiError) {
		id, err := pathID(r, "cityId")
		if err != nil {
			return "", err
		}
		year, err := pathYear(r)
		if err != nil {
			return "", err
		}
		return store.PrayerTimesPath(id, year), nil
	}))
	mux.HandleFunc("/v1/religious-days/{year}", h.file(cacheDaily, func(r *http.Request) (string, *apiError) {
		year, err := pathYear(r)
		if err != nil {
			return "", err
		}
		return store.ReligiousDaysPath(year), nil
	}))
	mux.HandleFunc("/v1/daily-content/{date}", h.file(cacheDaily, func(r *http.Request) (string, *apiError) {
		t, err := time.Parse(model.DateLayout, r.PathValue("date"))
		if err != nil {
			return "", errInvalidParam("date must be YYYY-MM-DD")
		}
		return store.DailyContentPath(t), nil
	}))
	mux.HandleFunc("/v1/health", h.health)
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) { writeError(w, errNotFound) })
	return accessLog(logger, mux)
}

func pathID(r *http.Request, name string) (int, *apiError) {
	n, err := strconv.Atoi(r.PathValue(name))
	if err != nil || n <= 0 {
		return 0, errInvalidParam(name + " must be a positive integer")
	}
	return n, nil
}

func pathYear(r *http.Request) (int, *apiError) {
	n, err := strconv.Atoi(r.PathValue("year"))
	if err != nil || n < minYear || n > maxYear {
		return 0, errInvalidParam("year must be between 2000 and 2100")
	}
	return n, nil
}

func (h *handler) file(cacheControl string, resolve resolver) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet && r.Method != http.MethodHead {
			w.Header().Set("Allow", "GET, HEAD")
			writeError(w, errMethod)
			return
		}
		rel, aerr := resolve(r)
		if aerr != nil {
			writeError(w, aerr)
			return
		}
		data, etag, err := h.st.Read(rel)
		if errors.Is(err, fs.ErrNotExist) {
			writeError(w, errNotFound)
			return
		}
		if err != nil {
			h.logger.Error("store read failed", "path", rel, "err", err.Error())
			writeError(w, errInternal)
			return
		}
		hdr := w.Header()
		hdr.Set("Content-Type", "application/json; charset=utf-8")
		hdr.Set("ETag", etag)
		hdr.Set("Cache-Control", cacheControl)
		if etagMatches(r.Header.Get("If-None-Match"), etag) {
			w.WriteHeader(http.StatusNotModified)
			return
		}
		hdr.Set("Content-Length", strconv.Itoa(len(data)))
		w.WriteHeader(http.StatusOK)
		if r.Method == http.MethodHead {
			return
		}
		_, _ = w.Write(data)
	}
}

// etagMatches, If-None-Match listesindeki (zayıf öneki yok sayılarak) herhangi bir değer
// ya da "*" ile eşleşirse true döner.
func etagMatches(ifNoneMatch, etag string) bool {
	if strings.TrimSpace(ifNoneMatch) == "" {
		return false
	}
	for _, candidate := range strings.Split(ifNoneMatch, ",") {
		candidate = strings.TrimSpace(candidate)
		candidate = strings.TrimPrefix(candidate, "W/")
		if candidate == "*" || candidate == etag {
			return true
		}
	}
	return false
}
```

`server/internal/httpapi/health.go`:
```go
package httpapi

import (
	"encoding/json"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"time"

	"vakit/internal/store"
)

type yearHealth struct {
	Cities    int       `json:"cities"`
	Complete  bool      `json:"complete"`
	UpdatedAt time.Time `json:"updatedAt"`
}

type healthResponse struct {
	Status        string `json:"status"`
	Version       string `json:"version"`
	UptimeSeconds int64  `json:"uptimeSeconds"`
	Datasets      struct {
		Places        store.PlacesState     `json:"places"`
		PrayerTimes   map[string]yearHealth `json:"prayerTimes"`
		ReligiousDays struct {
			Years     []int     `json:"years"`
			UpdatedAt time.Time `json:"updatedAt"`
		} `json:"religiousDays"`
		DailyContent store.DailyContentState `json:"dailyContent"`
		Rejected     int                     `json:"rejected"`
	} `json:"datasets"`
}

func buildHealth(state *store.SyncState, opts Options, now time.Time) healthResponse {
	resp := healthResponse{Status: "ok", Version: opts.Version, UptimeSeconds: int64(now.Sub(opts.StartedAt).Seconds())}
	resp.Datasets.Places = state.Places
	resp.Datasets.DailyContent = state.DailyContent
	resp.Datasets.Rejected = state.Rejected
	years := map[string]*yearHealth{}
	for key, cy := range state.PrayerTimes {
		_, yearStr, ok := strings.Cut(key, "/")
		if !ok {
			continue
		}
		yh, exists := years[yearStr]
		if !exists {
			yh = &yearHealth{Complete: true}
			years[yearStr] = yh
		}
		yh.Cities++
		yh.Complete = yh.Complete && cy.Complete
		if cy.LastFetchedAt.After(yh.UpdatedAt) {
			yh.UpdatedAt = cy.LastFetchedAt
		}
	}
	resp.Datasets.PrayerTimes = make(map[string]yearHealth, len(years))
	for y, yh := range years {
		resp.Datasets.PrayerTimes[y] = *yh
	}
	for y, at := range state.ReligiousDays {
		if n, err := strconv.Atoi(y); err == nil {
			resp.Datasets.ReligiousDays.Years = append(resp.Datasets.ReligiousDays.Years, n)
		}
		if at.After(resp.Datasets.ReligiousDays.UpdatedAt) {
			resp.Datasets.ReligiousDays.UpdatedAt = at
		}
	}
	sort.Ints(resp.Datasets.ReligiousDays.Years)
	return resp
}

func (h *handler) health(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet && r.Method != http.MethodHead {
		w.Header().Set("Allow", "GET, HEAD")
		writeError(w, errMethod)
		return
	}
	state, err := h.st.LoadState()
	if err != nil {
		h.logger.Error("health: state unreadable", "err", err.Error())
		writeError(w, errInternal)
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(http.StatusOK)
	if r.Method == http.MethodHead {
		return
	}
	_ = json.NewEncoder(w).Encode(buildHealth(state, h.opts, time.Now()))
}
```

`server/internal/httpapi/middleware.go`:
```go
package httpapi

import (
	"crypto/rand"
	"encoding/hex"
	"io"
	"log/slog"
	"net"
	"net/http"
	"time"
)

func NewLogger(w io.Writer, level slog.Level) *slog.Logger {
	return slog.New(slog.NewJSONHandler(w, &slog.HandlerOptions{Level: level}))
}

type statusRecorder struct {
	http.ResponseWriter
	status int
	bytes  int
}

func (s *statusRecorder) WriteHeader(code int) {
	s.status = code
	s.ResponseWriter.WriteHeader(code)
}

func (s *statusRecorder) Write(b []byte) (int, error) {
	if s.status == 0 {
		s.status = http.StatusOK
	}
	n, err := s.ResponseWriter.Write(b)
	s.bytes += n
	return n, err
}

// accessLog: request_id (CF-Ray ya da rastgele), CF-Connecting-IP, süre ve durum kodu.
func accessLog(logger *slog.Logger, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		id := r.Header.Get("CF-Ray")
		if id == "" {
			id = randomID()
		}
		w.Header().Set("X-Request-Id", id)
		rec := &statusRecorder{ResponseWriter: w}
		next.ServeHTTP(rec, r)
		if rec.status == 0 {
			rec.status = http.StatusOK
		}
		logger.Info("request",
			"request_id", id, "method", r.Method, "path", r.URL.Path, "status", rec.status,
			"bytes", rec.bytes, "duration_ms", time.Since(start).Milliseconds(), "ip", clientIP(r))
	})
}

func clientIP(r *http.Request) string {
	if ip := r.Header.Get("CF-Connecting-IP"); ip != "" {
		return ip
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

func randomID() string {
	var b [8]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "unknown"
	}
	return hex.EncodeToString(b[:])
}
```

Run: `cd server && go test ./internal/httpapi/` → PASS

- [ ] **Step 6: `vakit serve`**

`server/cmd/vakit/serve.go`:
```go
package main

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"vakit/internal/config"
	"vakit/internal/httpapi"
	"vakit/internal/store"
)

const (
	readHeaderTimeout = 5 * time.Second
	writeTimeout      = 15 * time.Second
	idleTimeout       = 60 * time.Second
	maxHeaderBytes    = 16 << 10
	shutdownGrace     = 10 * time.Second
)

func runServe(_ []string, stdout, stderr io.Writer) int {
	cfg, err := config.FromEnv(os.Getenv)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 2
	}
	logger := httpapi.NewLogger(stdout, cfg.LogLevel)
	handler := httpapi.NewHandler(store.New(cfg.DataDir), httpapi.Options{Version: version, StartedAt: time.Now()}, logger)
	srv := &http.Server{
		Addr: cfg.Addr, Handler: handler,
		ReadHeaderTimeout: readHeaderTimeout, WriteTimeout: writeTimeout, IdleTimeout: idleTimeout,
		MaxHeaderBytes: maxHeaderBytes,
	}
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	errCh := make(chan error, 1)
	go func() { errCh <- srv.ListenAndServe() }()
	logger.Info("serve started", "addr", cfg.Addr, "data_dir", cfg.DataDir, "version", version)
	select {
	case err := <-errCh:
		if !errors.Is(err, http.ErrServerClosed) {
			logger.Error("serve failed", "err", err.Error())
			return 1
		}
	case <-ctx.Done():
		shutdownCtx, cancel := context.WithTimeout(context.Background(), shutdownGrace)
		defer cancel()
		if err := srv.Shutdown(shutdownCtx); err != nil {
			logger.Error("shutdown failed", "err", err.Error())
			return 1
		}
		logger.Info("serve stopped")
	}
	return 0
}
```

`server/cmd/vakit/main.go` switch'e ekle (version dalından önce):
```go
	case "serve":
		return runServe(args[1:], stdout, stderr)
```

- [ ] **Step 7: Elle duman testi**

```bash
cd server && mkdir -p data && go run ./cmd/vakit serve &
sleep 1; curl -s -i http://127.0.0.1:8080/v1/health | head -12; curl -s -i http://127.0.0.1:8080/v1/prayer-times/9541/2026 | head -8; kill %1
```
Expected: health 200 `no-store`; prayer-times 404 `{"error":{"code":"NOT_FOUND",...}}`; JSON erişim logu satırları.

- [ ] **Step 8: Run all, commit**

Run: `cd server && gofmt -l . && go vet ./... && go test ./...` → PASS

```bash
git add server/internal/config server/internal/httpapi server/cmd/vakit
git commit -m "feat(server): /v1 HTTP sunucusu, env konfigürasyonu ve health

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: `internal/awqat` — istemci çekirdeği (token, yenileme, retry, kota)

**Files:**
- Create: `server/internal/awqat/client.go`, `server/internal/awqat/token.go`, `server/internal/awqat/client_test.go`

**Interfaces:**
- Consumes: `store.TokenPath()` (yalnız yol; dosyayı istemci kendisi yazar)
- Produces: `type Credentials struct{ Email, Password string }`; `New(baseURL string, creds Credentials, tokenPath string, logger *slog.Logger, opts ...Option) *Client`; `Option`'lar: `WithHTTPClient(*http.Client)`, `WithInterval(time.Duration)`, `WithBackoff(func(attempt int) time.Duration)`, `WithClock(func() time.Time)`; `(*Client).Get(ctx, path string, out any) error`, `(*Client).Post(ctx, path string, body, out any) error`; `var ErrQuotaExceeded, ErrUnauthorized error`; `type APIError struct{ Status int; Path, Message string }`; `jwtExpiry(token string) (time.Time, error)`.

Davranış (VAK.2): `Bearer` başlığı; `exp − 2 dk` → yenile; `401` → yenile, olmazsa giriş, yine `401` → `ErrUnauthorized`; `429` → `ErrQuotaExceeded` (tek deneme); `5xx`/ağ hatası → 3 deneme, backoff 2/4/8 s; `success=false` → `*APIError`; istekler arası `interval`; token dosyası `0600`; token/şifre asla loglanmaz.

- [ ] **Step 1: Failing tests**

`server/internal/awqat/client_test.go`:
```go
package awqat

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"sync/atomic"
	"testing"
	"time"
)

func fakeJWT(exp time.Time) string {
	payload, _ := json.Marshal(map[string]any{"exp": exp.Unix(), "role": "Standard"})
	enc := base64.RawURLEncoding.EncodeToString
	return enc([]byte(`{"alg":"HS256","typ":"JWT"}`)) + "." + enc(payload) + ".sig"
}

func okEnvelope(data any) string {
	b, _ := json.Marshal(map[string]any{"data": data, "success": true, "message": nil})
	return string(b)
}

type fakeDiyanet struct {
	t           *testing.T
	logins      atomic.Int32
	refreshes   atomic.Int32
	calls       atomic.Int32
	accessExp   time.Time
	onCall      func(w http.ResponseWriter, r *http.Request, n int32)
	seenAuth    []string
	rejectToken string
}

func (f *fakeDiyanet) handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("POST /Auth/Login", func(w http.ResponseWriter, r *http.Request) {
		var body struct{ Email, Password string }
		_ = json.NewDecoder(r.Body).Decode(&body)
		if body.Email != "user@example.com" || body.Password != "secret" {
			http.Error(w, "bad creds", 400)
			return
		}
		f.logins.Add(1)
		fmt.Fprint(w, okEnvelope(map[string]string{"accessToken": fakeJWT(f.accessExp), "refreshToken": "R1"}))
	})
	mux.HandleFunc("GET /Auth/RefreshToken/{token}", func(w http.ResponseWriter, r *http.Request) {
		f.refreshes.Add(1)
		if r.PathValue("token") == f.rejectToken {
			w.WriteHeader(401)
			return
		}
		fmt.Fprint(w, okEnvelope(map[string]string{"accessToken": fakeJWT(f.accessExp), "refreshToken": "R2"}))
	})
	mux.HandleFunc("/api/", func(w http.ResponseWriter, r *http.Request) {
		n := f.calls.Add(1)
		f.seenAuth = append(f.seenAuth, r.Header.Get("Authorization"))
		f.onCall(w, r, n)
	})
	return mux
}

func newClient(t *testing.T, srv *httptest.Server, opts ...Option) *Client {
	t.Helper()
	tokenPath := filepath.Join(t.TempDir(), "state", "awqat_token.json")
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	base := []Option{WithHTTPClient(srv.Client()), WithInterval(0), WithBackoff(func(int) time.Duration { return 0 })}
	return New(srv.URL, Credentials{Email: "user@example.com", Password: "secret"}, tokenPath, logger, append(base, opts...)...)
}

func okContent(w http.ResponseWriter, _ *http.Request, _ int32) {
	fmt.Fprint(w, okEnvelope(map[string]any{"id": 333, "dayOfYear": 333, "verse": "v"}))
}

func TestGet_LogsInThenSendsBearer(t *testing.T) {
	f := &fakeDiyanet{t: t, accessExp: time.Now().Add(45 * time.Minute), onCall: okContent}
	srv := httptest.NewServer(f.handler())
	defer srv.Close()
	c := newClient(t, srv)
	var out struct{ DayOfYear int `json:"dayOfYear"` }
	if err := c.Get(context.Background(), "/api/DailyContent", &out); err != nil {
		t.Fatal(err)
	}
	if out.DayOfYear != 333 || f.logins.Load() != 1 || len(f.seenAuth) != 1 || f.seenAuth[0] != "Bearer "+fakeJWT(f.accessExp) {
		t.Fatalf("out=%+v logins=%d auth=%v", out, f.logins.Load(), f.seenAuth)
	}
	info, err := os.Stat(c.tokenPath)
	if err != nil || info.Mode().Perm() != 0o600 {
		t.Fatalf("token file perm: %v %v", info, err)
	}
}

func TestGet_RefreshesPersistedTokenWhenNearExpiry(t *testing.T) {
	now := time.Date(2026, 9, 16, 10, 0, 0, 0, time.UTC)
	f := &fakeDiyanet{t: t, accessExp: now.Add(time.Hour), onCall: okContent}
	srv := httptest.NewServer(f.handler())
	defer srv.Close()
	c := newClient(t, srv, WithClock(func() time.Time { return now }))
	// Diskteki token 90 sn sonra bitiyor: 2 dk marjın içinde → giriş değil, yenileme beklenir.
	nearExpiry := now.Add(90 * time.Second)
	if err := saveTokenFile(c.tokenPath, tokenPair{AccessToken: fakeJWT(nearExpiry), RefreshToken: "R1", AccessExp: nearExpiry}); err != nil {
		t.Fatal(err)
	}
	if err := c.Get(context.Background(), "/api/DailyContent", nil); err != nil {
		t.Fatal(err)
	}
	if f.logins.Load() != 0 || f.refreshes.Load() != 1 || f.calls.Load() != 1 {
		t.Fatalf("logins=%d refreshes=%d calls=%d; expected refresh only", f.logins.Load(), f.refreshes.Load(), f.calls.Load())
	}
	if f.seenAuth[0] != "Bearer "+fakeJWT(f.accessExp) {
		t.Fatal("call must use the refreshed access token")
	}
}

func TestGet_401TriggersRefreshThenLoginFallback(t *testing.T) {
	f := &fakeDiyanet{t: t, accessExp: time.Now().Add(time.Hour), rejectToken: "R1"}
	f.onCall = func(w http.ResponseWriter, r *http.Request, n int32) {
		if n == 1 {
			w.WriteHeader(401)
			return
		}
		okContent(w, r, n)
	}
	srv := httptest.NewServer(f.handler())
	defer srv.Close()
	c := newClient(t, srv)
	if err := c.Get(context.Background(), "/api/DailyContent", nil); err != nil {
		t.Fatal(err)
	}
	if f.refreshes.Load() != 1 || f.logins.Load() != 2 || f.calls.Load() != 2 {
		t.Fatalf("refreshes=%d logins=%d calls=%d", f.refreshes.Load(), f.logins.Load(), f.calls.Load())
	}
}

func TestGet_PersistentUnauthorized(t *testing.T) {
	f := &fakeDiyanet{t: t, accessExp: time.Now().Add(time.Hour)}
	f.onCall = func(w http.ResponseWriter, _ *http.Request, _ int32) { w.WriteHeader(401) }
	srv := httptest.NewServer(f.handler())
	defer srv.Close()
	if err := newClient(t, srv).Get(context.Background(), "/api/DailyContent", nil); !errors.Is(err, ErrUnauthorized) {
		t.Fatalf("err = %v", err)
	}
}

func TestGet_QuotaExceededIsNotRetried(t *testing.T) {
	f := &fakeDiyanet{t: t, accessExp: time.Now().Add(time.Hour)}
	f.onCall = func(w http.ResponseWriter, _ *http.Request, _ int32) { w.WriteHeader(429) }
	srv := httptest.NewServer(f.handler())
	defer srv.Close()
	err := newClient(t, srv).Get(context.Background(), "/api/DailyContent", nil)
	if !errors.Is(err, ErrQuotaExceeded) || f.calls.Load() != 1 {
		t.Fatalf("err=%v calls=%d", err, f.calls.Load())
	}
}

func TestGet_ServerErrorsAreRetriedThreeTimes(t *testing.T) {
	f := &fakeDiyanet{t: t, accessExp: time.Now().Add(time.Hour)}
	f.onCall = func(w http.ResponseWriter, r *http.Request, n int32) {
		if n < 3 {
			w.WriteHeader(503)
			return
		}
		okContent(w, r, n)
	}
	srv := httptest.NewServer(f.handler())
	defer srv.Close()
	if err := newClient(t, srv).Get(context.Background(), "/api/DailyContent", nil); err != nil || f.calls.Load() != 3 {
		t.Fatalf("err=%v calls=%d", err, f.calls.Load())
	}
	f.calls.Store(0)
	f.onCall = func(w http.ResponseWriter, _ *http.Request, _ int32) { w.WriteHeader(500) }
	var apiErr *APIError
	if err := newClient(t, srv).Get(context.Background(), "/api/DailyContent", nil); !errors.As(err, &apiErr) || apiErr.Status != 500 || f.calls.Load() != 3 {
		t.Fatalf("err=%v calls=%d", err, f.calls.Load())
	}
}

func TestGet_SuccessFalseIsAPIError(t *testing.T) {
	f := &fakeDiyanet{t: t, accessExp: time.Now().Add(time.Hour)}
	f.onCall = func(w http.ResponseWriter, _ *http.Request, _ int32) {
		fmt.Fprint(w, `{"data":null,"success":false,"message":"Kota aşıldı"}`)
	}
	srv := httptest.NewServer(f.handler())
	defer srv.Close()
	var apiErr *APIError
	err := newClient(t, srv).Get(context.Background(), "/api/DailyContent", nil)
	if !errors.As(err, &apiErr) || apiErr.Message != "Kota aşıldı" || apiErr.Status != 200 {
		t.Fatalf("err = %v", err)
	}
}

func TestClient_ReusesPersistedTokenAcrossInstances(t *testing.T) {
	f := &fakeDiyanet{t: t, accessExp: time.Now().Add(time.Hour), onCall: okContent}
	srv := httptest.NewServer(f.handler())
	defer srv.Close()
	c1 := newClient(t, srv)
	_ = c1.Get(context.Background(), "/api/DailyContent", nil)
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	c2 := New(srv.URL, Credentials{Email: "user@example.com", Password: "secret"}, c1.tokenPath, logger,
		WithHTTPClient(srv.Client()), WithInterval(0))
	if err := c2.Get(context.Background(), "/api/DailyContent", nil); err != nil {
		t.Fatal(err)
	}
	if f.logins.Load() != 1 {
		t.Fatalf("second instance must reuse token file; logins=%d", f.logins.Load())
	}
}

func TestJWTExpiry(t *testing.T) {
	exp := time.Date(2026, 9, 16, 12, 0, 0, 0, time.UTC)
	got, err := jwtExpiry(fakeJWT(exp))
	if err != nil || !got.Equal(exp) {
		t.Fatalf("got %v err %v", got, err)
	}
	if _, err := jwtExpiry("not-a-jwt"); err == nil {
		t.Fatal("expected error")
	}
}
```

- [ ] **Step 2: Run, fail**

Run: `cd server && go test ./internal/awqat/`
Expected: FAIL — undefined

- [ ] **Step 3: Implement token yardımcıları**

`server/internal/awqat/token.go`:
```go
package awqat

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

type tokenPair struct {
	AccessToken  string    `json:"accessToken"`
	RefreshToken string    `json:"refreshToken"`
	AccessExp    time.Time `json:"accessExp"`
}

func (t tokenPair) empty() bool { return t.AccessToken == "" || t.RefreshToken == "" }

// jwtExpiry, imzayı doğrulamadan payload'daki exp claim'ini okur; süre yönetimi için yeter.
func jwtExpiry(token string) (time.Time, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return time.Time{}, errors.New("awqat: token is not a JWT")
	}
	payload, err := base64.RawURLEncoding.DecodeString(strings.TrimRight(parts[1], "="))
	if err != nil {
		return time.Time{}, fmt.Errorf("awqat: jwt payload: %w", err)
	}
	var claims struct {
		Exp int64 `json:"exp"`
	}
	if err := json.Unmarshal(payload, &claims); err != nil || claims.Exp == 0 {
		return time.Time{}, errors.New("awqat: jwt has no exp claim")
	}
	return time.Unix(claims.Exp, 0).UTC(), nil
}

func loadTokenFile(path string) (tokenPair, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return tokenPair{}, err
	}
	var t tokenPair
	if err := json.Unmarshal(data, &t); err != nil {
		return tokenPair{}, fmt.Errorf("awqat: token file: %w", err)
	}
	return t, nil
}

// saveTokenFile 0600 ile yazar; token sızıntısına karşı dizin izinleri de 0700.
func saveTokenFile(path string, t tokenPair) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	data, err := json.Marshal(t)
	if err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}
```

- [ ] **Step 4: Implement istemci**

`server/internal/awqat/client.go`:
```go
// Package awqat, Diyanet Awqat Salah REST servisinin istemcisidir (spec VAK.2).
// Kimlik bilgisi ve token'lar hiçbir log kaydına yazılmaz.
package awqat

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"sync"
	"time"
)

const (
	loginPath          = "/Auth/Login"
	refreshPath        = "/Auth/RefreshToken/"
	defaultTimeout     = 30 * time.Second
	defaultInterval    = 500 * time.Millisecond
	maxAttempts        = 3
	tokenRefreshMargin = 2 * time.Minute
	maxBodyBytes       = 8 << 20
)

var (
	ErrQuotaExceeded = errors.New("awqat: quota exceeded (HTTP 429)")
	ErrUnauthorized  = errors.New("awqat: unauthorized after re-authentication")
)

// APIError: HTTP 200 dışı kalıcı durumlar ya da success=false zarfı.
type APIError struct {
	Status  int
	Path    string
	Message string
}

func (e *APIError) Error() string {
	return fmt.Sprintf("awqat: %s -> %d: %s", e.Path, e.Status, e.Message)
}

type Credentials struct {
	Email    string
	Password string
}

type Client struct {
	baseURL   string
	http      *http.Client
	creds     Credentials
	tokenPath string
	interval  time.Duration
	backoff   func(attempt int) time.Duration
	now       func() time.Time
	logger    *slog.Logger

	mu       sync.Mutex
	token    tokenPair
	lastCall time.Time
}

type Option func(*Client)

func WithHTTPClient(h *http.Client) Option            { return func(c *Client) { c.http = h } }
func WithInterval(d time.Duration) Option             { return func(c *Client) { c.interval = d } }
func WithBackoff(f func(int) time.Duration) Option    { return func(c *Client) { c.backoff = f } }
func WithClock(now func() time.Time) Option           { return func(c *Client) { c.now = now } }

func defaultBackoff(attempt int) time.Duration { return time.Duration(1<<attempt) * time.Second } // 2s, 4s, 8s

func New(baseURL string, creds Credentials, tokenPath string, logger *slog.Logger, opts ...Option) *Client {
	c := &Client{
		baseURL:   baseURL,
		http:      &http.Client{Timeout: defaultTimeout},
		creds:     creds,
		tokenPath: tokenPath,
		interval:  defaultInterval,
		backoff:   defaultBackoff,
		now:       time.Now,
		logger:    logger,
	}
	for _, o := range opts {
		o(c)
	}
	return c
}

type envelope struct {
	Data    json.RawMessage `json:"data"`
	Success bool            `json:"success"`
	Message *string         `json:"message"`
}

func (c *Client) Get(ctx context.Context, path string, out any) error {
	return c.call(ctx, http.MethodGet, path, nil, out)
}

func (c *Client) Post(ctx context.Context, path string, body, out any) error {
	return c.call(ctx, http.MethodPost, path, body, out)
}

func (c *Client) call(ctx context.Context, method, path string, body, out any) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	if err := c.ensureTokenLocked(ctx); err != nil {
		return err
	}
	reauthed := false
	for attempt := 1; ; attempt++ {
		status, data, err := c.sendLocked(ctx, method, path, body, c.token.AccessToken)
		if err != nil {
			if attempt >= maxAttempts || ctx.Err() != nil {
				return fmt.Errorf("awqat: %s %s: %w", method, path, err)
			}
			c.logger.Warn("awqat transport error; retrying", "path", path, "attempt", attempt, "err", err.Error())
			if err := c.sleep(ctx, c.backoff(attempt)); err != nil {
				return err
			}
			continue
		}
		switch {
		case status == http.StatusUnauthorized && !reauthed:
			reauthed = true
			if err := c.reauthLocked(ctx); err != nil {
				return err
			}
			continue
		case status == http.StatusUnauthorized:
			return ErrUnauthorized
		case status == http.StatusTooManyRequests:
			return ErrQuotaExceeded
		case status >= 500:
			if attempt >= maxAttempts {
				return &APIError{Status: status, Path: path, Message: "server error"}
			}
			c.logger.Warn("awqat server error; retrying", "path", path, "status", status, "attempt", attempt)
			if err := c.sleep(ctx, c.backoff(attempt)); err != nil {
				return err
			}
			continue
		case status != http.StatusOK:
			return &APIError{Status: status, Path: path, Message: truncate(data, 200)}
		}
		return decodeEnvelope(data, path, out)
	}
}

// sendLocked: aralık bekler, isteği gönderir, gövdeyi sınırlı okur. Yalnız call/auth içinden çağrılır.
func (c *Client) sendLocked(ctx context.Context, method, path string, body any, bearer string) (int, []byte, error) {
	if wait := c.interval - c.now().Sub(c.lastCall); wait > 0 && !c.lastCall.IsZero() {
		if err := c.sleep(ctx, wait); err != nil {
			return 0, nil, err
		}
	}
	var reader io.Reader
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			return 0, nil, err
		}
		reader = bytes.NewReader(b)
	}
	req, err := http.NewRequestWithContext(ctx, method, c.baseURL+path, reader)
	if err != nil {
		return 0, nil, err
	}
	req.Header.Set("Accept", "application/json")
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if bearer != "" {
		req.Header.Set("Authorization", "Bearer "+bearer)
	}
	c.lastCall = c.now()
	resp, err := c.http.Do(req)
	if err != nil {
		return 0, nil, err
	}
	defer resp.Body.Close()
	data, err := io.ReadAll(io.LimitReader(resp.Body, maxBodyBytes))
	if err != nil {
		return 0, nil, err
	}
	return resp.StatusCode, data, nil
}

func (c *Client) sleep(ctx context.Context, d time.Duration) error {
	if d <= 0 {
		return nil
	}
	select {
	case <-time.After(d):
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

func decodeEnvelope(data []byte, path string, out any) error {
	var env envelope
	if err := json.Unmarshal(data, &env); err != nil {
		return &APIError{Status: http.StatusOK, Path: path, Message: "response is not a Diyanet envelope: " + truncate(data, 120)}
	}
	if !env.Success {
		msg := "success=false"
		if env.Message != nil {
			msg = *env.Message
		}
		return &APIError{Status: http.StatusOK, Path: path, Message: msg}
	}
	if out == nil || len(env.Data) == 0 || string(env.Data) == "null" {
		return nil
	}
	if err := json.Unmarshal(env.Data, out); err != nil {
		return &APIError{Status: http.StatusOK, Path: path, Message: "unexpected data shape: " + err.Error()}
	}
	return nil
}

func truncate(b []byte, n int) string {
	if len(b) <= n {
		return string(b)
	}
	return string(b[:n]) + "…"
}

// ensureTokenLocked: bellekte yoksa dosyadan yükle; yoksa giriş; süresi yaklaştıysa yenile.
func (c *Client) ensureTokenLocked(ctx context.Context) error {
	if c.token.empty() {
		if t, err := loadTokenFile(c.tokenPath); err == nil && !t.empty() {
			c.token = t
		}
	}
	if c.token.empty() {
		return c.loginLocked(ctx)
	}
	if c.now().Add(tokenRefreshMargin).After(c.token.AccessExp) {
		return c.reauthLocked(ctx)
	}
	return nil
}

// reauthLocked: önce refresh, başarısızsa giriş.
func (c *Client) reauthLocked(ctx context.Context) error {
	if c.token.RefreshToken != "" {
		if err := c.refreshLocked(ctx); err == nil {
			return nil
		} else {
			c.logger.Warn("awqat refresh failed; logging in", "err", err.Error())
		}
	}
	return c.loginLocked(ctx)
}

func (c *Client) loginLocked(ctx context.Context) error {
	status, data, err := c.sendLocked(ctx, http.MethodPost, loginPath,
		map[string]string{"email": c.creds.Email, "password": c.creds.Password}, "")
	if err != nil {
		return fmt.Errorf("awqat: login: %w", err)
	}
	if status != http.StatusOK {
		return &APIError{Status: status, Path: loginPath, Message: "login rejected"}
	}
	return c.storeTokensLocked(data, loginPath)
}

func (c *Client) refreshLocked(ctx context.Context) error {
	path := refreshPath + url.PathEscape(c.token.RefreshToken)
	status, data, err := c.sendLocked(ctx, http.MethodGet, path, nil, "")
	if err != nil {
		return err
	}
	if status != http.StatusOK {
		return &APIError{Status: status, Path: refreshPath + "…", Message: "refresh rejected"}
	}
	return c.storeTokensLocked(data, refreshPath+"…")
}

func (c *Client) storeTokensLocked(data []byte, path string) error {
	var got struct {
		AccessToken  string `json:"accessToken"`
		RefreshToken string `json:"refreshToken"`
	}
	if err := decodeEnvelope(data, path, &got); err != nil {
		return err
	}
	exp, err := jwtExpiry(got.AccessToken)
	if err != nil {
		return err
	}
	c.token = tokenPair{AccessToken: got.AccessToken, RefreshToken: got.RefreshToken, AccessExp: exp}
	if err := saveTokenFile(c.tokenPath, c.token); err != nil {
		return fmt.Errorf("awqat: persist token: %w", err)
	}
	c.logger.Info("awqat token acquired", "access_exp", exp.Format(time.RFC3339))
	return nil
}
```

- [ ] **Step 5: Run, pass**

Run: `cd server && gofmt -l . && go vet ./... && go test ./internal/awqat/`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add server/internal/awqat
git commit -m "feat(server): Awqat Salah istemci çekirdeği — JWT süre yönetimi, retry, kota

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: `internal/awqat` — tipli uçlar

**Files:**
- Create: `server/internal/awqat/endpoints.go`, `server/internal/awqat/endpoints_test.go`

**Interfaces:**
- Consumes: `Client.Get/Post` (Task 6)
- Produces:
  - `type Place struct{ ID int; Code, Name string }`; `(*Client).Countries(ctx) ([]Place, error)`, `States(ctx, countryID int)`, `Cities(ctx, stateID int)`
  - `type CityDetail struct{ ID int; Name string; GeographicQiblaAngle, QiblaAngle, DistanceToKaaba *float64; City, Country string }`; `(*Client).CityDetail(ctx, cityID int) (*CityDetail, error)`
  - `type PrayerRecord struct{ Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha, AstronomicalSunrise, AstronomicalSunset, QiblaTime, HijriDateShort, HijriDateLong, GregorianDateShort, GregorianDateLongIso8601 string; GreenwichMeanTimeZone *int }`; `(*Client).DateRange(ctx, cityID int, start, end time.Time) ([]PrayerRecord, error)`
  - `type ReligiousDayRecord struct{ ID int; Name string; IsSpecial bool; GregorianDate string; HijriDay, HijriMonth, HijriYear int; HijriMonthName string }`; `(*Client).ReligiousDaysByYear(ctx, year int) ([]ReligiousDayRecord, error)`
  - `type DailyContentRecord struct{ ID, DayOfYear int; Verse, VerseSource, Hadith, HadithSource, Pray string; PraySource *string }`; `(*Client).DailyContent(ctx) (*DailyContentRecord, error)`, `(*Client).DailyContentByDate(ctx, date time.Time) (*DailyContentRecord, error)`
  - `(*Client).QuotaMy(ctx) (json.RawMessage, error)`
  - `const DateRangeTimeLayout = "2006-01-02T00:00:00"`

Diyanet sayıları bazen string gelir (`CityDetail.id: "17885"`, `qiblaAngle: "159"`); ham tiplerde `json.Number` kullanılır — `encoding/json`, geçerli bir sayı içeren JSON string'i `json.Number`'a kabul eder.

- [ ] **Step 1: Failing tests**

`server/internal/awqat/endpoints_test.go`:
```go
package awqat

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

// Yanıtlar kılavuz PDF'indeki örneklerden (s.7–12) alınmıştır.
func endpointServer(t *testing.T) (*httptest.Server, *fakeDiyanet) {
	f := &fakeDiyanet{t: t, accessExp: time.Now().Add(time.Hour)}
	f.onCall = func(w http.ResponseWriter, r *http.Request, _ int32) {
		switch r.URL.Path {
		case "/api/Place/Countries":
			fmt.Fprint(w, `{"data":[{"id":1,"code":"NORTH CYPRUS","name":"KUZEY KIBRIS"},{"id":2,"code":"TURKEY","name":"TÜRKİYE"}],"success":true,"message":null}`)
		case "/api/Place/States/2":
			fmt.Fprint(w, `{"data":[{"id":500,"code":"ADANA","name":"ADANA"}],"success":true,"message":null}`)
		case "/api/Place/Cities/539":
			fmt.Fprint(w, `{"data":[{"id":9541,"code":"ISTANBUL","name":"İSTANBUL"}],"success":true,"message":null}`)
		case "/api/Place/CityDetail/17885":
			fmt.Fprint(w, `{"data":{"id":"17885","name":"DEVREKANİ","code":null,"geographicQiblaAngle":"164","distanceToKaaba":"2312","qiblaAngle":"159","city":"KASTAMONU","cityEn":null,"country":"TÜRKİYE","countryEn":"TÜRKİYE"},"success":true,"message":null}`)
		case "/api/PrayerTime/DateRange":
			var body map[string]any
			_ = json.NewDecoder(r.Body).Decode(&body)
			if r.Method != http.MethodPost || body["cityId"] != float64(9541) || body["startDate"] != "2026-01-01T00:00:00" || body["endDate"] != "2026-12-31T00:00:00" {
				t.Errorf("unexpected DateRange request: %s %v", r.Method, body)
			}
			fmt.Fprint(w, `{"data":[{"shapeMoonUrl":"http://x/r5.gif","fajr":"06:11","sunrise":"07:42","dhuhr":"12:38","asr":"15:01","maghrib":"17:23","isha":"18:49","astronomicalSunset":"17:16","astronomicalSunrise":"07:49","hijriDateShort":"5.5.1444","hijriDateShortIso8601":null,"hijriDateLong":"5 Cemaziyelevvel 1444","hijriDateLongIso8601":null,"qiblaTime":"11:31","gregorianDateShort":"29.11.2022","gregorianDateShortIso8601":"29.11.2022","gregorianDateLong":"29 Kasım 2022 Salı","gregorianDateLongIso8601":"2022-11-29T00:00:00.0000000+03:00","greenwichMeanTimeZone":3}],"success":true,"message":null}`)
		case "/api/IslamicReligiousDay/ByYear":
			if r.URL.Query().Get("year") != "2026" {
				t.Errorf("year query = %q", r.URL.Query().Get("year"))
			}
			fmt.Fprint(w, `{"data":[{"id":1,"religiousDayName":"Miraç Kandili","isSpecialReligiousDay":true,"gregorianDate":"2026-01-15T00:00:00","hijriDay":26,"hijriMonthName":"Recep","hijriMonth":7,"hijriYear":1447,"moonPhase":"sd5.gif","moonPhaseUrl":"https://x/sd5.gif","hijriDate":"26.7.1447","hijriDateLong":"26 Recep 1447"}],"success":true,"message":null}`)
		case "/api/DailyContent":
			fmt.Fprint(w, `{"data":{"id":333,"dayOfYear":333,"verse":"\"Gökleri...\"","verseSource":"(Şu'arâ, 42/29)","hadith":"“Küçüklerimize...”","hadithSource":"(Tirmizî, “Birr ”, 15)","pray":"\"Bizleri...\"","praySource":null},"success":true,"message":null}`)
		case "/api/DailyContent/VerseHadithAndPrayer":
			if r.URL.Query().Get("date") != "2026-09-16" {
				t.Errorf("date query = %q", r.URL.Query().Get("date"))
			}
			fmt.Fprint(w, `{"data":{"id":259,"dayOfYear":259,"verse":"v","verseSource":"vs","hadith":"h","hadithSource":"hs","pray":"p","praySource":"ps"},"success":true,"message":null}`)
		case "/api/Quota/My":
			fmt.Fprint(w, `{"data":{"daily":[{"endpoint":"DateRange","remaining":7}]},"success":true,"message":null}`)
		default:
			t.Errorf("unexpected path %s", r.URL.Path)
			w.WriteHeader(404)
		}
	}
	srv := httptest.NewServer(f.handler())
	t.Cleanup(srv.Close)
	return srv, f
}

func TestPlaces(t *testing.T) {
	srv, _ := endpointServer(t)
	c := newClient(t, srv)
	ctx := context.Background()
	countries, err := c.Countries(ctx)
	if err != nil || len(countries) != 2 || countries[1] != (Place{ID: 2, Code: "TURKEY", Name: "TÜRKİYE"}) {
		t.Fatalf("%v %v", countries, err)
	}
	states, err := c.States(ctx, 2)
	if err != nil || len(states) != 1 || states[0].ID != 500 {
		t.Fatalf("%v %v", states, err)
	}
	cities, err := c.Cities(ctx, 539)
	if err != nil || len(cities) != 1 || cities[0].Name != "İSTANBUL" {
		t.Fatalf("%v %v", cities, err)
	}
}

func TestCityDetail_ParsesStringNumbers(t *testing.T) {
	srv, _ := endpointServer(t)
	d, err := newClient(t, srv).CityDetail(context.Background(), 17885)
	if err != nil {
		t.Fatal(err)
	}
	if d.ID != 17885 || d.Name != "DEVREKANİ" || *d.GeographicQiblaAngle != 164 || *d.QiblaAngle != 159 || *d.DistanceToKaaba != 2312 || d.City != "KASTAMONU" {
		t.Fatalf("%+v", d)
	}
}

func TestDateRange(t *testing.T) {
	srv, _ := endpointServer(t)
	recs, err := newClient(t, srv).DateRange(context.Background(), 9541,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC), time.Date(2026, 12, 31, 0, 0, 0, 0, time.UTC))
	if err != nil || len(recs) != 1 {
		t.Fatalf("%v %v", recs, err)
	}
	r := recs[0]
	if r.Fajr != "06:11" || r.Isha != "18:49" || r.HijriDateLong != "5 Cemaziyelevvel 1444" || r.GregorianDateShort != "29.11.2022" ||
		r.GreenwichMeanTimeZone == nil || *r.GreenwichMeanTimeZone != 3 || r.QiblaTime != "11:31" || r.AstronomicalSunrise != "07:49" {
		t.Fatalf("%+v", r)
	}
}

func TestReligiousDaysByYear(t *testing.T) {
	srv, _ := endpointServer(t)
	days, err := newClient(t, srv).ReligiousDaysByYear(context.Background(), 2026)
	if err != nil || len(days) != 1 {
		t.Fatalf("%v %v", days, err)
	}
	d := days[0]
	if d.Name != "Miraç Kandili" || !d.IsSpecial || d.GregorianDate != "2026-01-15T00:00:00" || d.HijriDay != 26 || d.HijriMonth != 7 || d.HijriYear != 1447 || d.HijriMonthName != "Recep" {
		t.Fatalf("%+v", d)
	}
}

func TestDailyContent(t *testing.T) {
	srv, _ := endpointServer(t)
	c := newClient(t, srv)
	today, err := c.DailyContent(context.Background())
	if err != nil || today.DayOfYear != 333 || today.PraySource != nil || today.VerseSource != "(Şu'arâ, 42/29)" {
		t.Fatalf("%+v %v", today, err)
	}
	byDate, err := c.DailyContentByDate(context.Background(), time.Date(2026, 9, 16, 0, 0, 0, 0, time.UTC))
	if err != nil || byDate.DayOfYear != 259 || byDate.PraySource == nil || *byDate.PraySource != "ps" {
		t.Fatalf("%+v %v", byDate, err)
	}
}

func TestQuotaMy_ReturnsRawData(t *testing.T) {
	srv, _ := endpointServer(t)
	raw, err := newClient(t, srv).QuotaMy(context.Background())
	if err != nil || !json.Valid(raw) || len(raw) == 0 {
		t.Fatalf("%s %v", raw, err)
	}
}
```

- [ ] **Step 2: Run, fail**

Run: `cd server && go test ./internal/awqat/`
Expected: FAIL — undefined `Countries` vb.

- [ ] **Step 3: Implement**

`server/internal/awqat/endpoints.go`:
```go
package awqat

import (
	"context"
	"encoding/json"
	"fmt"
	"net/url"
	"strconv"
	"time"
)

const DateRangeTimeLayout = "2006-01-02T00:00:00"

type Place struct {
	ID   int
	Code string
	Name string
}

type rawPlace struct {
	ID   json.Number `json:"id"`
	Code string      `json:"code"`
	Name string      `json:"name"`
}

func (c *Client) places(ctx context.Context, path string) ([]Place, error) {
	var raw []rawPlace
	if err := c.Get(ctx, path, &raw); err != nil {
		return nil, err
	}
	out := make([]Place, 0, len(raw))
	for _, r := range raw {
		id, err := numberToInt(r.ID)
		if err != nil {
			return nil, fmt.Errorf("awqat: %s: id %q: %w", path, r.ID, err)
		}
		out = append(out, Place{ID: id, Code: r.Code, Name: r.Name})
	}
	return out, nil
}

func (c *Client) Countries(ctx context.Context) ([]Place, error) {
	return c.places(ctx, "/api/Place/Countries")
}

func (c *Client) States(ctx context.Context, countryID int) ([]Place, error) {
	return c.places(ctx, "/api/Place/States/"+strconv.Itoa(countryID))
}

func (c *Client) Cities(ctx context.Context, stateID int) ([]Place, error) {
	return c.places(ctx, "/api/Place/Cities/"+strconv.Itoa(stateID))
}

type CityDetail struct {
	ID                   int
	Name                 string
	GeographicQiblaAngle *float64 // gerçek kuzey
	QiblaAngle           *float64 // manyetik
	DistanceToKaaba      *float64 // km
	City                 string
	Country              string
}

func (c *Client) CityDetail(ctx context.Context, cityID int) (*CityDetail, error) {
	var raw struct {
		ID                   json.Number `json:"id"`
		Name                 string      `json:"name"`
		GeographicQiblaAngle json.Number `json:"geographicQiblaAngle"`
		QiblaAngle           json.Number `json:"qiblaAngle"`
		DistanceToKaaba      json.Number `json:"distanceToKaaba"`
		City                 string      `json:"city"`
		Country              string      `json:"country"`
	}
	path := "/api/Place/CityDetail/" + strconv.Itoa(cityID)
	if err := c.Get(ctx, path, &raw); err != nil {
		return nil, err
	}
	id, err := numberToInt(raw.ID)
	if err != nil {
		return nil, fmt.Errorf("awqat: %s: id: %w", path, err)
	}
	return &CityDetail{
		ID: id, Name: raw.Name, City: raw.City, Country: raw.Country,
		GeographicQiblaAngle: numberToFloatPtr(raw.GeographicQiblaAngle),
		QiblaAngle:           numberToFloatPtr(raw.QiblaAngle),
		DistanceToKaaba:      numberToFloatPtr(raw.DistanceToKaaba),
	}, nil
}

// PrayerRecord, Daily/DateRange kayıtlarının ham hâlidir; model dönüşümü awqatsrc'de.
type PrayerRecord struct {
	Fajr                     string `json:"fajr"`
	Sunrise                  string `json:"sunrise"`
	Dhuhr                    string `json:"dhuhr"`
	Asr                      string `json:"asr"`
	Maghrib                  string `json:"maghrib"`
	Isha                     string `json:"isha"`
	AstronomicalSunrise      string `json:"astronomicalSunrise"`
	AstronomicalSunset       string `json:"astronomicalSunset"`
	QiblaTime                string `json:"qiblaTime"`
	HijriDateShort           string `json:"hijriDateShort"`
	HijriDateLong            string `json:"hijriDateLong"`
	GregorianDateShort       string `json:"gregorianDateShort"`
	GregorianDateLongIso8601 string `json:"gregorianDateLongIso8601"`
	GreenwichMeanTimeZone    *int   `json:"greenwichMeanTimeZone"`
}

func (c *Client) DateRange(ctx context.Context, cityID int, start, end time.Time) ([]PrayerRecord, error) {
	body := map[string]any{
		"cityId":    cityID,
		"startDate": start.Format(DateRangeTimeLayout),
		"endDate":   end.Format(DateRangeTimeLayout),
	}
	var out []PrayerRecord
	if err := c.Post(ctx, "/api/PrayerTime/DateRange", body, &out); err != nil {
		return nil, err
	}
	return out, nil
}

type ReligiousDayRecord struct {
	ID             int    `json:"id"`
	Name           string `json:"religiousDayName"`
	IsSpecial      bool   `json:"isSpecialReligiousDay"`
	GregorianDate  string `json:"gregorianDate"`
	HijriDay       int    `json:"hijriDay"`
	HijriMonth     int    `json:"hijriMonth"`
	HijriYear      int    `json:"hijriYear"`
	HijriMonthName string `json:"hijriMonthName"`
}

func (c *Client) ReligiousDaysByYear(ctx context.Context, year int) ([]ReligiousDayRecord, error) {
	var out []ReligiousDayRecord
	if err := c.Get(ctx, "/api/IslamicReligiousDay/ByYear?year="+strconv.Itoa(year), &out); err != nil {
		return nil, err
	}
	return out, nil
}

type DailyContentRecord struct {
	ID           int     `json:"id"`
	DayOfYear    int     `json:"dayOfYear"`
	Verse        string  `json:"verse"`
	VerseSource  string  `json:"verseSource"`
	Hadith       string  `json:"hadith"`
	HadithSource string  `json:"hadithSource"`
	Pray         string  `json:"pray"`
	PraySource   *string `json:"praySource"`
}

func (c *Client) DailyContent(ctx context.Context) (*DailyContentRecord, error) {
	var out DailyContentRecord
	if err := c.Get(ctx, "/api/DailyContent", &out); err != nil {
		return nil, err
	}
	return &out, nil
}

func (c *Client) DailyContentByDate(ctx context.Context, date time.Time) (*DailyContentRecord, error) {
	q := url.Values{"date": {date.Format("2006-01-02")}}
	var out DailyContentRecord
	if err := c.Get(ctx, "/api/DailyContent/VerseHadithAndPrayer?"+q.Encode(), &out); err != nil {
		return nil, err
	}
	return &out, nil
}

// QuotaMy şekli belgelenmemiş; ham JSON döner, çağıran loglar/yazdırır.
func (c *Client) QuotaMy(ctx context.Context) (json.RawMessage, error) {
	var out json.RawMessage
	if err := c.Get(ctx, "/api/Quota/My?includeUnused=true", &out); err != nil {
		return nil, err
	}
	return out, nil
}

func numberToInt(n json.Number) (int, error) {
	if n == "" {
		return 0, fmt.Errorf("empty number")
	}
	v, err := n.Int64()
	if err != nil {
		return 0, err
	}
	return int(v), nil
}

func numberToFloatPtr(n json.Number) *float64 {
	if n == "" {
		return nil
	}
	v, err := n.Float64()
	if err != nil {
		return nil
	}
	return &v
}
```

- [ ] **Step 4: Run, pass**

Run: `cd server && gofmt -l . && go vet ./... && go test ./internal/awqat/`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/internal/awqat
git commit -m "feat(server): Awqat Salah tipli uçlar — yer, DateRange, dini gün, günlük içerik, kota

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 8: `internal/source` arayüzü ve `awqatsrc` adaptörü

**Files:**
- Create: `server/internal/source/source.go`, `server/internal/source/awqatsrc/awqatsrc.go`, `server/internal/source/awqatsrc/awqatsrc_test.go`

**Interfaces:**
- Consumes: `awqat.Client` uçları (Task 7), `model.*` (Task 2)
- Produces:
```go
package source
var ErrUnsupported = errors.New("source: operation not supported by this source")
var ErrQuotaExceeded = errors.New("source: quota exceeded")
type Source interface {
	Name() string
	Countries(ctx context.Context) ([]model.Country, error)
	States(ctx context.Context, countryID int) ([]model.State, error)
	Cities(ctx context.Context, stateID int) ([]model.City, error)
	CityDetail(ctx context.Context, cityID int) (*model.CityDetail, error)
	PrayerTimes(ctx context.Context, cityID, year int) ([]model.Day, error)
	ReligiousDays(ctx context.Context, year int) ([]model.ReligiousDay, error)
	DailyContent(ctx context.Context, date time.Time) (*model.DailyContent, error)
}
```
  `awqatsrc.New(c *awqat.Client) source.Source`; `awqatsrc.MapPrayerRecord(r awqat.PrayerRecord) (model.Day, error)` (test edilebilir saf dönüşüm).

- [ ] **Step 1: Failing tests**

`server/internal/source/awqatsrc/awqatsrc_test.go`:
```go
package awqatsrc

import (
	"testing"

	"vakit/internal/awqat"
)

func TestMapPrayerRecord_FullRecord(t *testing.T) {
	tz := 3
	r := awqat.PrayerRecord{Fajr: "06:11", Sunrise: "07:42", Dhuhr: "12:38", Asr: "15:01", Maghrib: "17:23", Isha: "18:49",
		AstronomicalSunrise: "07:49", AstronomicalSunset: "17:16", QiblaTime: "11:31",
		HijriDateShort: "5.5.1444", HijriDateLong: "5 Cemaziyelevvel 1444",
		GregorianDateShort: "29.11.2022", GreenwichMeanTimeZone: &tz}
	d, err := MapPrayerRecord(r)
	if err != nil {
		t.Fatal(err)
	}
	if d.Date != "2022-11-29" || d.Fajr != "06:11" || d.Isha != "18:49" || d.Hijri.Day != 5 || d.Hijri.Month != 5 ||
		d.Hijri.Year != 1444 || d.Hijri.MonthName != "Cemaziyelevvel" || *d.AstronomicalSunrise != "07:49" ||
		*d.AstronomicalSunset != "17:16" || *d.QiblaTime != "11:31" || *d.GMTOffset != 3 {
		t.Fatalf("%+v", d)
	}
}

func TestMapPrayerRecord_NormalisesSecondsAndFallsBackToShortHijri(t *testing.T) {
	r := awqat.PrayerRecord{Fajr: "06:11:00", Sunrise: "07:42:00", Dhuhr: "12:38:00", Asr: "15:01:00", Maghrib: "17:23:00", Isha: "18:49:00",
		HijriDateShort: "5.5.1444", GregorianDateLongIso8601: "2022-11-29T00:00:00.0000000+03:00"}
	d, err := MapPrayerRecord(r)
	if err != nil {
		t.Fatal(err)
	}
	if d.Date != "2022-11-29" || d.Fajr != "06:11" || d.Hijri.MonthName != "Cemaziyelevvel" || d.AstronomicalSunrise != nil || d.GMTOffset != nil {
		t.Fatalf("%+v", d)
	}
}

func TestMapPrayerRecord_Errors(t *testing.T) {
	base := awqat.PrayerRecord{Fajr: "06:11", Sunrise: "07:42", Dhuhr: "12:38", Asr: "15:01", Maghrib: "17:23", Isha: "18:49",
		HijriDateLong: "5 Cemaziyelevvel 1444", GregorianDateShort: "29.11.2022"}
	noDate := base
	noDate.GregorianDateShort = ""
	if _, err := MapPrayerRecord(noDate); err == nil {
		t.Error("missing date must fail")
	}
	noHijri := base
	noHijri.HijriDateLong = ""
	if _, err := MapPrayerRecord(noHijri); err == nil {
		t.Error("missing hijri must fail")
	}
	badClock := base
	badClock.Asr = "x"
	if _, err := MapPrayerRecord(badClock); err == nil {
		t.Error("bad clock must fail")
	}
}
```

- [ ] **Step 2: Run, fail**

Run: `cd server && go test ./internal/source/...`
Expected: FAIL — undefined

- [ ] **Step 3: Implement**

`server/internal/source/source.go`:
```go
// Package source, veri kaynaklarının (resmî API, web sayfası) ortak arayüzüdür.
// Sync işleri yalnız bu arayüzü görür; kaynak env ile seçilir (K4).
package source

import (
	"context"
	"errors"
	"time"

	"vakit/internal/model"
)

var (
	ErrUnsupported   = errors.New("source: operation not supported by this source")
	ErrQuotaExceeded = errors.New("source: quota exceeded")
)

type Source interface {
	Name() string
	Countries(ctx context.Context) ([]model.Country, error)
	States(ctx context.Context, countryID int) ([]model.State, error)
	Cities(ctx context.Context, stateID int) ([]model.City, error)
	CityDetail(ctx context.Context, cityID int) (*model.CityDetail, error)
	PrayerTimes(ctx context.Context, cityID, year int) ([]model.Day, error)
	ReligiousDays(ctx context.Context, year int) ([]model.ReligiousDay, error)
	DailyContent(ctx context.Context, date time.Time) (*model.DailyContent, error)
}
```

`server/internal/source/awqatsrc/awqatsrc.go`:
```go
// Package awqatsrc, awqat istemcisini source.Source'a uyarlar.
package awqatsrc

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"vakit/internal/awqat"
	"vakit/internal/model"
	"vakit/internal/source"
)

type Source struct {
	c *awqat.Client
}

func New(c *awqat.Client) *Source { return &Source{c: c} }

func (s *Source) Name() string { return "awqat" }

// wrap, kota hatasını kaynak-bağımsız hataya çevirir; diğerlerini olduğu gibi geçirir.
func wrap(err error) error {
	if errors.Is(err, awqat.ErrQuotaExceeded) {
		return fmt.Errorf("%w: %v", source.ErrQuotaExceeded, err)
	}
	return err
}

func (s *Source) Countries(ctx context.Context) ([]model.Country, error) {
	places, err := s.c.Countries(ctx)
	if err != nil {
		return nil, wrap(err)
	}
	out := make([]model.Country, 0, len(places))
	for _, p := range places {
		out = append(out, model.Country{ID: p.ID, Name: p.Name, NameEn: p.Code})
	}
	return out, nil
}

func (s *Source) States(ctx context.Context, countryID int) ([]model.State, error) {
	places, err := s.c.States(ctx, countryID)
	if err != nil {
		return nil, wrap(err)
	}
	out := make([]model.State, 0, len(places))
	for _, p := range places {
		out = append(out, model.State{ID: p.ID, Name: p.Name, CountryID: countryID})
	}
	return out, nil
}

func (s *Source) Cities(ctx context.Context, stateID int) ([]model.City, error) {
	places, err := s.c.Cities(ctx, stateID)
	if err != nil {
		return nil, wrap(err)
	}
	out := make([]model.City, 0, len(places))
	for _, p := range places {
		out = append(out, model.City{ID: p.ID, Name: p.Name, StateID: stateID})
	}
	return out, nil
}

func (s *Source) CityDetail(ctx context.Context, cityID int) (*model.CityDetail, error) {
	d, err := s.c.CityDetail(ctx, cityID)
	if err != nil {
		return nil, wrap(err)
	}
	return &model.CityDetail{CityID: d.ID, QiblaAngle: d.GeographicQiblaAngle, QiblaAngleMagnetic: d.QiblaAngle,
		DistanceToKaaba: d.DistanceToKaaba}, nil
}

func (s *Source) PrayerTimes(ctx context.Context, cityID, year int) ([]model.Day, error) {
	start := time.Date(year, 1, 1, 0, 0, 0, 0, time.UTC)
	end := time.Date(year, 12, 31, 0, 0, 0, 0, time.UTC)
	recs, err := s.c.DateRange(ctx, cityID, start, end)
	if err != nil {
		return nil, wrap(err)
	}
	days := make([]model.Day, 0, len(recs))
	for i, r := range recs {
		d, err := MapPrayerRecord(r)
		if err != nil {
			return nil, fmt.Errorf("awqatsrc: city %d year %d record %d: %w", cityID, year, i, err)
		}
		days = append(days, d)
	}
	return days, nil
}

func (s *Source) ReligiousDays(ctx context.Context, year int) ([]model.ReligiousDay, error) {
	recs, err := s.c.ReligiousDaysByYear(ctx, year)
	if err != nil {
		return nil, wrap(err)
	}
	out := make([]model.ReligiousDay, 0, len(recs))
	for _, r := range recs {
		date, err := time.Parse("2006-01-02T15:04:05", r.GregorianDate)
		if err != nil {
			return nil, fmt.Errorf("awqatsrc: religious day %d date %q: %w", r.ID, r.GregorianDate, err)
		}
		monthName := r.HijriMonthName
		if n, ok := model.HijriMonthNumber(monthName); ok {
			monthName = model.HijriMonths[n-1]
		}
		out = append(out, model.ReligiousDay{ID: r.ID, Date: date.Format(model.DateLayout), Name: r.Name, IsSpecial: r.IsSpecial,
			Hijri: model.Hijri{Day: r.HijriDay, Month: r.HijriMonth, Year: r.HijriYear, MonthName: monthName}})
	}
	return out, nil
}

func (s *Source) DailyContent(ctx context.Context, date time.Time) (*model.DailyContent, error) {
	rec, err := s.c.DailyContentByDate(ctx, date)
	if err != nil {
		return nil, wrap(err)
	}
	return &model.DailyContent{Date: date.Format(model.DateLayout), DayOfYear: rec.DayOfYear, Verse: rec.Verse,
		VerseSource: rec.VerseSource, Hadith: rec.Hadith, HadithSource: rec.HadithSource, Prayer: rec.Pray,
		PrayerSource: rec.PraySource}, nil
}

// MapPrayerRecord, Diyanet kaydını yayın gününe çevirir. Tarih için gregorianDateShort
// ("29.11.2022"), yoksa ISO alanının ilk 10 karakteri; Hicri için long, yoksa short.
func MapPrayerRecord(r awqat.PrayerRecord) (model.Day, error) {
	date, err := parseGregorian(r)
	if err != nil {
		return model.Day{}, err
	}
	hijri, err := parseHijri(r)
	if err != nil {
		return model.Day{}, err
	}
	clocks := [6]string{r.Fajr, r.Sunrise, r.Dhuhr, r.Asr, r.Maghrib, r.Isha}
	for i := range clocks {
		norm, err := model.NormalizeClock(clocks[i])
		if err != nil {
			return model.Day{}, fmt.Errorf("%s: %w", model.ClockNames[i], err)
		}
		clocks[i] = norm
	}
	return model.Day{
		Date: date, Hijri: hijri,
		Fajr: clocks[0], Sunrise: clocks[1], Dhuhr: clocks[2], Asr: clocks[3], Maghrib: clocks[4], Isha: clocks[5],
		AstronomicalSunrise: optionalClock(r.AstronomicalSunrise),
		AstronomicalSunset:  optionalClock(r.AstronomicalSunset),
		QiblaTime:           optionalClock(r.QiblaTime),
		GMTOffset:           r.GreenwichMeanTimeZone,
	}, nil
}

func parseGregorian(r awqat.PrayerRecord) (string, error) {
	if s := strings.TrimSpace(r.GregorianDateShort); s != "" {
		t, err := time.Parse("02.01.2006", s)
		if err != nil {
			return "", fmt.Errorf("gregorianDateShort %q: %w", s, err)
		}
		return t.Format(model.DateLayout), nil
	}
	if s := r.GregorianDateLongIso8601; len(s) >= 10 {
		t, err := time.Parse(model.DateLayout, s[:10])
		if err != nil {
			return "", fmt.Errorf("gregorianDateLongIso8601 %q: %w", s, err)
		}
		return t.Format(model.DateLayout), nil
	}
	return "", errors.New("record has no gregorian date")
}

func parseHijri(r awqat.PrayerRecord) (model.Hijri, error) {
	if r.HijriDateLong != "" {
		return model.ParseHijriLong(r.HijriDateLong)
	}
	if r.HijriDateShort != "" {
		return model.ParseHijriShort(r.HijriDateShort)
	}
	return model.Hijri{}, errors.New("record has no hijri date")
}

func optionalClock(s string) *string {
	norm, err := model.NormalizeClock(s)
	if err != nil {
		return nil
	}
	return &norm
}
```

- [ ] **Step 4: Run, pass**

Run: `cd server && gofmt -l . && go vet ./... && go test ./internal/source/...`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/internal/source
git commit -m "feat(server): Source arayüzü ve Awqat Salah adaptörü

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 9: `internal/source/web` — ilçe sayfası ve GetRegList kaynağı

**Files:**
- Create: `server/internal/source/web/web.go`, `server/internal/source/web/parse.go`, `server/internal/source/web/web_test.go`
- Mevcut fixture'lar: `server/internal/source/web/testdata/istanbul_9541.html` (15 Eyl 2026 anlık görüntüsü: aylık tablo 15 Eyl–15 Eki 2026, yıllık tablo 1 Oca–31 Ara 2027, 209 ülke seçeneği), `testdata/getreglist_country_2.json` (81 il), `testdata/getreglist_state_539.json` (İstanbul 19 ilçe)

**Interfaces:**
- Consumes: `source.Source`, `source.ErrUnsupported`, `model.ParseTurkishDate`, `model.ParseHijriLong`, `model.NormalizeClock`
- Produces: `web.New(baseURL string, opts ...web.Option) *web.Source` (`WithHTTPClient`, `WithInterval`); `web.DefaultBaseURL`; `var web.ErrUnexpectedTable`; `Name()` → `"web"`.

- [ ] **Step 1: Bağımlılık**

```bash
cd server && go get golang.org/x/net/html@latest && go mod tidy && git diff --stat go.mod go.sum
```

- [ ] **Step 2: Failing tests**

`server/internal/source/web/web_test.go`:
```go
package web

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"vakit/internal/source"
)

func fixtureServer(t *testing.T) (*httptest.Server, *[]string) {
	t.Helper()
	var agents []string
	mux := http.NewServeMux()
	mux.HandleFunc("/tr-TR/9541", func(w http.ResponseWriter, r *http.Request) {
		agents = append(agents, r.UserAgent())
		http.Redirect(w, r, "/tr-TR/9541/istanbul-icin-namaz-vakti", http.StatusFound) // gerçek site gibi
	})
	mux.HandleFunc("/tr-TR/9541/istanbul-icin-namaz-vakti", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "testdata/istanbul_9541.html")
	})
	mux.HandleFunc("/tr-TR/1", func(w http.ResponseWriter, r *http.Request) { // bozuk başlık senaryosu
		raw, _ := os.ReadFile("testdata/istanbul_9541.html")
		_, _ = w.Write([]byte(strings.Replace(string(raw), "Hicri Tarih", "Hicri", 1)))
	})
	mux.HandleFunc("/tr-TR/home/GetRegList", func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Query().Get("ChangeType") {
		case "country":
			if r.URL.Query().Get("CountryId") != "2" {
				http.NotFound(w, r)
				return
			}
			http.ServeFile(w, r, "testdata/getreglist_country_2.json")
		case "state":
			if r.URL.Query().Get("StateId") != "539" {
				http.NotFound(w, r)
				return
			}
			http.ServeFile(w, r, "testdata/getreglist_state_539.json")
		default:
			http.NotFound(w, r)
		}
	})
	srv := httptest.NewServer(mux)
	t.Cleanup(srv.Close)
	return srv, &agents
}

func newSource(t *testing.T) (*Source, *[]string) {
	srv, agents := fixtureServer(t)
	return New(srv.URL, WithHTTPClient(srv.Client()), WithInterval(0)), agents
}

func TestCountries_FromPageSelect(t *testing.T) {
	s, agents := newSource(t)
	countries, err := s.Countries(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if len(countries) != 209 {
		t.Fatalf("countries = %d", len(countries))
	}
	var found bool
	for _, c := range countries {
		if c.ID == 2 && c.Name == "TÜRKİYE" && !c.Enabled {
			found = true
		}
	}
	if !found {
		t.Fatal("TÜRKİYE id=2 not found")
	}
	if len(*agents) == 0 || !strings.HasPrefix((*agents)[0], "Mozilla/5.0") {
		t.Fatalf("browser user agent required, got %v", *agents)
	}
}

func TestStatesAndCities_FromGetRegList(t *testing.T) {
	s, _ := newSource(t)
	states, err := s.States(context.Background(), 2)
	if err != nil || len(states) != 81 {
		t.Fatalf("states=%d err=%v", len(states), err)
	}
	if states[0].ID != 500 || states[0].Name != "ADANA" || states[0].CountryID != 2 {
		t.Fatalf("%+v", states[0])
	}
	cities, err := s.Cities(context.Background(), 539)
	if err != nil || len(cities) != 19 {
		t.Fatalf("cities=%d err=%v", len(cities), err)
	}
	var ok bool
	for _, c := range cities {
		if c.ID == 9541 && c.Name == "İSTANBUL" && c.StateID == 539 {
			ok = true
		}
	}
	if !ok {
		t.Fatalf("İSTANBUL 9541 missing in %+v", cities)
	}
}

func TestPrayerTimes_CurrentYearComesFromMonthlyTable(t *testing.T) {
	s, _ := newSource(t)
	days, err := s.PrayerTimes(context.Background(), 9541, 2026)
	if err != nil {
		t.Fatal(err)
	}
	if len(days) != 31 || days[0].Date != "2026-09-15" || days[30].Date != "2026-10-15" {
		t.Fatalf("len=%d first=%s last=%s", len(days), days[0].Date, days[len(days)-1].Date)
	}
	d := days[0]
	if d.Fajr != "05:11" || d.Sunrise != "06:37" || d.Dhuhr != "13:04" || d.Asr != "16:35" || d.Maghrib != "19:22" || d.Isha != "20:43" {
		t.Fatalf("%+v", d)
	}
	if d.Hijri.Day != 4 || d.Hijri.Month != 4 || d.Hijri.Year != 1448 || d.Hijri.MonthName != "Rebiulahir" {
		t.Fatalf("%+v", d.Hijri)
	}
	if d.AstronomicalSunrise != nil || d.QiblaTime != nil || d.GMTOffset != nil {
		t.Fatal("web source must leave API-only fields nil")
	}
}

func TestPrayerTimes_NextYearComesFromYearlyTable(t *testing.T) {
	s, _ := newSource(t)
	days, err := s.PrayerTimes(context.Background(), 9541, 2027)
	if err != nil {
		t.Fatal(err)
	}
	if len(days) != 365 || days[0].Date != "2027-01-01" || days[364].Date != "2027-12-31" {
		t.Fatalf("len=%d", len(days))
	}
	first, last := days[0], days[364]
	if first.Fajr != "06:50" || first.Isha != "19:19" || first.Hijri.Day != 23 || first.Hijri.MonthName != "Recep" || first.Hijri.Year != 1448 {
		t.Fatalf("%+v", first)
	}
	if last.Asr != "15:31" || last.Hijri.Day != 3 || last.Hijri.MonthName != "Şaban" || last.Hijri.Year != 1449 {
		t.Fatalf("%+v", last)
	}
}

func TestPrayerTimes_YearNotOnPageIsEmptyNotError(t *testing.T) {
	s, _ := newSource(t)
	days, err := s.PrayerTimes(context.Background(), 9541, 2025)
	if err != nil || len(days) != 0 {
		t.Fatalf("len=%d err=%v", len(days), err)
	}
}

func TestPrayerTimes_HeaderChangeIsDetected(t *testing.T) {
	s, _ := newSource(t)
	_, err := s.PrayerTimes(context.Background(), 1, 2027)
	if !errors.Is(err, ErrUnexpectedTable) {
		t.Fatalf("err = %v", err)
	}
}

func TestUnsupportedOperations(t *testing.T) {
	s, _ := newSource(t)
	ctx := context.Background()
	if _, err := s.CityDetail(ctx, 9541); !errors.Is(err, source.ErrUnsupported) {
		t.Fatal(err)
	}
	if _, err := s.ReligiousDays(ctx, 2026); !errors.Is(err, source.ErrUnsupported) {
		t.Fatal(err)
	}
	if _, err := s.DailyContent(ctx, time.Now()); !errors.Is(err, source.ErrUnsupported) {
		t.Fatal(err)
	}
	if s.Name() != "web" {
		t.Fatal(s.Name())
	}
}
```

- [ ] **Step 3: Run, fail**

Run: `cd server && go test ./internal/source/web/`
Expected: FAIL — undefined

- [ ] **Step 4: Implement**

`server/internal/source/web/web.go`:
```go
// Package web, namazvakitleri.diyanet.gov.tr ilçe sayfasından ve GetRegList JSON
// uçlarından veri okur (spec VAK.3). API onayı öncesi birincil, sonra fallback kaynak.
package web

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"sort"
	"strconv"
	"sync"
	"time"

	"golang.org/x/net/html"

	"vakit/internal/model"
	"vakit/internal/source"
)

const (
	DefaultBaseURL = "https://namazvakitleri.diyanet.gov.tr"
	// Ülke listesi her ilçe sayfasında aynıdır; İstanbul (9541) sabit referans.
	countryListPagePath = "/tr-TR/9541"
	regListPath         = "/tr-TR/home/GetRegList"
	// Site tarayıcı dışı istemcileri reddedebiliyor; kimliğimizi de belirtiyoruz.
	userAgent       = "Mozilla/5.0 (compatible; vakit-api/1.0)"
	defaultTimeout  = 30 * time.Second
	defaultInterval = time.Second
	maxBodyBytes    = 4 << 20
)

var ErrUnexpectedTable = errors.New("web: prayer table header differs from expected layout")

type Source struct {
	baseURL  string
	http     *http.Client
	interval time.Duration

	mu       sync.Mutex
	lastCall time.Time
}

type Option func(*Source)

func WithHTTPClient(h *http.Client) Option { return func(s *Source) { s.http = h } }
func WithInterval(d time.Duration) Option  { return func(s *Source) { s.interval = d } }

func New(baseURL string, opts ...Option) *Source {
	s := &Source{baseURL: baseURL, http: &http.Client{Timeout: defaultTimeout}, interval: defaultInterval}
	for _, o := range opts {
		o(s)
	}
	return s
}

func (s *Source) Name() string { return model.ViaWeb }

func (s *Source) fetch(ctx context.Context, path string) ([]byte, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if wait := s.interval - time.Since(s.lastCall); wait > 0 && !s.lastCall.IsZero() {
		select {
		case <-time.After(wait):
		case <-ctx.Done():
			return nil, ctx.Err()
		}
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, s.baseURL+path, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", userAgent)
	req.Header.Set("Accept-Language", "tr-TR,tr;q=0.9")
	s.lastCall = time.Now()
	resp, err := s.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("web: GET %s: %w", path, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("web: GET %s: HTTP %d", path, resp.StatusCode)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, maxBodyBytes))
	if err != nil {
		return nil, fmt.Errorf("web: GET %s: read: %w", path, err)
	}
	return body, nil
}

func (s *Source) Countries(ctx context.Context) ([]model.Country, error) {
	body, err := s.fetch(ctx, countryListPagePath)
	if err != nil {
		return nil, err
	}
	doc, err := html.Parse(bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("web: parse country page: %w", err)
	}
	return parseCountryOptions(doc)
}

type regListResponse struct {
	StateList []struct {
		SehirAdi   string      `json:"SehirAdi"`
		SehirAdiEn string      `json:"SehirAdiEn"`
		SehirID    json.Number `json:"SehirID"`
	} `json:"StateList"`
	StateRegionList []struct {
		IlceAdi   string      `json:"IlceAdi"`
		IlceAdiEn string      `json:"IlceAdiEn"`
		IlceID    json.Number `json:"IlceID"`
	} `json:"StateRegionList"`
}

func (s *Source) regList(ctx context.Context, q url.Values) (*regListResponse, error) {
	q.Set("Culture", "tr-TR")
	body, err := s.fetch(ctx, regListPath+"?"+q.Encode())
	if err != nil {
		return nil, err
	}
	var out regListResponse
	if err := json.Unmarshal(body, &out); err != nil {
		return nil, fmt.Errorf("web: GetRegList decode: %w", err)
	}
	return &out, nil
}

func (s *Source) States(ctx context.Context, countryID int) ([]model.State, error) {
	resp, err := s.regList(ctx, url.Values{"ChangeType": {"country"}, "CountryId": {strconv.Itoa(countryID)}})
	if err != nil {
		return nil, err
	}
	out := make([]model.State, 0, len(resp.StateList))
	for _, st := range resp.StateList {
		id, err := st.SehirID.Int64()
		if err != nil {
			return nil, fmt.Errorf("web: state id %q: %w", st.SehirID, err)
		}
		out = append(out, model.State{ID: int(id), Name: st.SehirAdi, CountryID: countryID})
	}
	return out, nil
}

func (s *Source) Cities(ctx context.Context, stateID int) ([]model.City, error) {
	resp, err := s.regList(ctx, url.Values{"ChangeType": {"state"}, "StateId": {strconv.Itoa(stateID)}})
	if err != nil {
		return nil, err
	}
	out := make([]model.City, 0, len(resp.StateRegionList))
	for _, c := range resp.StateRegionList {
		id, err := c.IlceID.Int64()
		if err != nil {
			return nil, fmt.Errorf("web: city id %q: %w", c.IlceID, err)
		}
		out = append(out, model.City{ID: int(id), Name: c.IlceAdi, StateID: stateID})
	}
	return out, nil
}

func (s *Source) CityDetail(context.Context, int) (*model.CityDetail, error) {
	return nil, source.ErrUnsupported
}

func (s *Source) ReligiousDays(context.Context, int) ([]model.ReligiousDay, error) {
	return nil, source.ErrUnsupported
}

func (s *Source) DailyContent(context.Context, time.Time) (*model.DailyContent, error) {
	return nil, source.ErrUnsupported
}

// PrayerTimes, aylık ve yıllık tablolardaki istenen yıla ait günleri tarih sırasıyla döner;
// aynı tarih iki tabloda varsa tek kayıt kalır. Yıl sayfada yoksa boş liste.
func (s *Source) PrayerTimes(ctx context.Context, cityID, year int) ([]model.Day, error) {
	body, err := s.fetch(ctx, "/tr-TR/"+strconv.Itoa(cityID))
	if err != nil {
		return nil, err
	}
	doc, err := html.Parse(bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("web: parse city page %d: %w", cityID, err)
	}
	all, err := parsePrayerTables(doc)
	if err != nil {
		return nil, fmt.Errorf("web: city %d: %w", cityID, err)
	}
	byDate := make(map[string]model.Day)
	for _, d := range all {
		if d.Date[:4] == strconv.Itoa(year) {
			byDate[d.Date] = d
		}
	}
	out := make([]model.Day, 0, len(byDate))
	for _, d := range byDate {
		out = append(out, d)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Date < out[j].Date })
	return out, nil
}
```

`server/internal/source/web/parse.go`:
```go
package web

import (
	"errors"
	"fmt"
	"strconv"
	"strings"

	"golang.org/x/net/html"

	"vakit/internal/model"
)

var expectedHeader = []string{"Miladi Tarih", "Hicri Tarih", "İmsak", "Güneş", "Öğle", "İkindi", "Akşam", "Yatsı"}

func isElement(name string) func(*html.Node) bool {
	return func(n *html.Node) bool { return n.Type == html.ElementNode && n.Data == name }
}

func attr(n *html.Node, key string) string {
	for _, a := range n.Attr {
		if a.Key == key {
			return a.Val
		}
	}
	return ""
}

func hasClass(n *html.Node, class string) bool {
	for _, c := range strings.Fields(attr(n, "class")) {
		if c == class {
			return true
		}
	}
	return false
}

func findAll(n *html.Node, pred func(*html.Node) bool) []*html.Node {
	var out []*html.Node
	var walk func(*html.Node)
	walk = func(x *html.Node) {
		if pred(x) {
			out = append(out, x)
		}
		for c := x.FirstChild; c != nil; c = c.NextSibling {
			walk(c)
		}
	}
	walk(n)
	return out
}

func text(n *html.Node) string {
	var b strings.Builder
	var walk func(*html.Node)
	walk = func(x *html.Node) {
		if x.Type == html.TextNode {
			b.WriteString(x.Data)
		}
		for c := x.FirstChild; c != nil; c = c.NextSibling {
			walk(c)
		}
	}
	walk(n)
	return strings.Join(strings.Fields(b.String()), " ")
}

func parseCountryOptions(doc *html.Node) ([]model.Country, error) {
	selects := findAll(doc, func(n *html.Node) bool { return isElement("select")(n) && hasClass(n, "country-select") })
	if len(selects) == 0 {
		return nil, errors.New("web: country select not found on page")
	}
	var out []model.Country
	for _, opt := range findAll(selects[0], isElement("option")) {
		id, err := strconv.Atoi(strings.TrimSpace(attr(opt, "value")))
		if err != nil {
			continue // "Ülke seçin" gibi yer tutucu seçenekler
		}
		name := text(opt)
		out = append(out, model.Country{ID: id, Name: name, NameEn: name})
	}
	if len(out) == 0 {
		return nil, errors.New("web: country select has no numeric options")
	}
	return out, nil
}

func isPrayerTable(n *html.Node) bool {
	return isElement("table")(n) && (attr(n, "aria-describedby") == "table-caption-monthly" || attr(n, "id") == "yourTable")
}

func tableRows(t *html.Node) [][]string {
	var rows [][]string
	for _, tr := range findAll(t, isElement("tr")) {
		var cells []string
		for c := tr.FirstChild; c != nil; c = c.NextSibling {
			if c.Type == html.ElementNode && (c.Data == "td" || c.Data == "th") {
				cells = append(cells, text(c))
			}
		}
		if len(cells) > 0 {
			rows = append(rows, cells)
		}
	}
	return rows
}

// parsePrayerTables aylık + yıllık tabloları okur; başlık beklenenden farklıysa ErrUnexpectedTable.
func parsePrayerTables(doc *html.Node) ([]model.Day, error) {
	tables := findAll(doc, isPrayerTable)
	if len(tables) == 0 {
		return nil, fmt.Errorf("%w: no monthly/yearly table found", ErrUnexpectedTable)
	}
	var out []model.Day
	for _, t := range tables {
		rows := tableRows(t)
		if len(rows) == 0 || !equalStrings(rows[0], expectedHeader) {
			var got []string
			if len(rows) > 0 {
				got = rows[0]
			}
			return nil, fmt.Errorf("%w: got %q", ErrUnexpectedTable, got)
		}
		for i, cells := range rows[1:] {
			day, err := rowToDay(cells)
			if err != nil {
				return nil, fmt.Errorf("row %d: %w", i+1, err)
			}
			out = append(out, day)
		}
	}
	return out, nil
}

func equalStrings(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

func rowToDay(cells []string) (model.Day, error) {
	if len(cells) != len(expectedHeader) {
		return model.Day{}, fmt.Errorf("%w: row has %d cells", ErrUnexpectedTable, len(cells))
	}
	date, err := model.ParseTurkishDate(cells[0])
	if err != nil {
		return model.Day{}, err
	}
	hijri, err := model.ParseHijriLong(cells[1])
	if err != nil {
		return model.Day{}, err
	}
	var clocks [6]string
	for i := range clocks {
		c, err := model.NormalizeClock(cells[2+i])
		if err != nil {
			return model.Day{}, fmt.Errorf("%s: %w", model.ClockNames[i], err)
		}
		clocks[i] = c
	}
	return model.Day{Date: date.Format(model.DateLayout), Hijri: hijri,
		Fajr: clocks[0], Sunrise: clocks[1], Dhuhr: clocks[2], Asr: clocks[3], Maghrib: clocks[4], Isha: clocks[5]}, nil
}
```

- [ ] **Step 5: Run, pass**

Run: `cd server && gofmt -l . && go vet ./... && go test ./internal/source/...`
Expected: PASS (fixture'da aylık tablonun `aria-describedby="table-caption-monthly"`, yıllığın `id="yourTable"` olduğu doğrulandı).

- [ ] **Step 6: Canlı duman testi (ağ)**

Ağ erişimli hızlı kontrol için geçici bir main kullan (commit'e girmez):
```bash
cd server && mkdir -p /tmp/webprobe && cat > /tmp/webprobe/main.go <<'EOF'
package main

import (
	"context"
	"fmt"

	"vakit/internal/source/web"
)

func main() {
	s := web.New(web.DefaultBaseURL)
	ctx := context.Background()
	c, err := s.Countries(ctx)
	fmt.Println("countries", len(c), err)
	st, err := s.States(ctx, 2)
	fmt.Println("states", len(st), err)
	d, err := s.PrayerTimes(ctx, 9541, 2027)
	fmt.Println("2027 days", len(d), err)
	if len(d) > 0 {
		fmt.Printf("%+v\n", d[0])
	}
}
EOF
cp -r /tmp/webprobe ./cmd/webprobe && go run ./cmd/webprobe; rm -rf ./cmd/webprobe
```
Expected: `countries 209`, `states 81`, `2027 days 365`, ilk gün `2027-01-01`. (Geçici komut dizini silinir, commit'e girmez.)

- [ ] **Step 7: Commit**

```bash
git add server/go.mod server/go.sum server/internal/source/web
git commit -m "feat(server): web kaynağı — ilçe sayfası tabloları ve GetRegList yer listeleri

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 10: `internal/geo`, `assets` embed ve `sync places`

**Files:**
- Create: `server/internal/geo/geo.go`, `server/internal/geo/geo_test.go`, `server/assets/assets.go`, `server/assets/tr_cities_geo.json` (boş iskelet), `server/internal/jobs/sync.go`, `server/internal/jobs/places.go`, `server/internal/jobs/fake_source_test.go`, `server/internal/jobs/places_test.go`

**Interfaces:**
- Consumes: `source.Source`, `store.Store`, `store.SyncState`, `model.*`
- Produces:
  - `geo.Point{Latitude, Longitude float64}`, `geo.Index map[int]geo.Point`, `geo.File{Source, GeneratedAt string; Cities []geo.Entry}`, `geo.Entry{CityID int; Name, StateName string; Latitude, Longitude float64; DisplayName string; Review bool}`, `geo.Parse(data []byte) (geo.Index, error)`, `geo.Load() (geo.Index, error)` (gömülü asset'ten)
  - `assets.TRCitiesGeo []byte`
  - `jobs.Deps{Source source.Source; Store *store.Store; State *store.SyncState; Logger *slog.Logger; Now func() time.Time; Geo geo.Index}`; `jobs.Result{Fetched, Written, Rejected, Skipped, Errors int; Stopped string}`; `jobs.Places(ctx, d Deps, enabled []int) (Result, error)`; `jobs.EnabledCityIDs(st *store.Store, enabled []int) ([]int, error)`
- Kural: `CityDetail` yalnız mevcut ilçe dosyasında kıble bilgisi **olmayan** ilçeler için çağrılır; `ErrUnsupported` sessizce atlanır; `source.ErrQuotaExceeded` çalıştırmayı durdurur, o ana kadarki dosyalar yazılmış kalır.

- [ ] **Step 1: geo — failing test**

`server/internal/geo/geo_test.go`:
```go
package geo

import "testing"

func TestParse_BuildsIndexAndSkipsReviewFlaggedEntries(t *testing.T) {
	data := []byte(`{"source":"OSM","generatedAt":"2026-09-16","cities":[
	  {"cityId":9541,"name":"İSTANBUL","stateName":"İSTANBUL","latitude":41.0082,"longitude":28.9784,"displayName":"İstanbul","review":false},
	  {"cityId":9547,"name":"ŞİLE","stateName":"İSTANBUL","latitude":0,"longitude":0,"displayName":"","review":true}]}`)
	idx, err := Parse(data)
	if err != nil {
		t.Fatal(err)
	}
	if p, ok := idx[9541]; !ok || p.Latitude != 41.0082 || p.Longitude != 28.9784 {
		t.Fatalf("%+v", idx)
	}
	if _, ok := idx[9547]; ok {
		t.Fatal("review-flagged entries must not enter the index")
	}
}

func TestParse_RejectsInvalidCoordinates(t *testing.T) {
	if _, err := Parse([]byte(`{"cities":[{"cityId":1,"latitude":91,"longitude":0}]}`)); err == nil {
		t.Fatal("latitude 91 must fail")
	}
	if _, err := Parse([]byte(`not json`)); err == nil {
		t.Fatal("invalid json must fail")
	}
}

func TestLoad_EmbeddedAssetParses(t *testing.T) {
	if _, err := Load(); err != nil {
		t.Fatal(err)
	}
}
```

- [ ] **Step 2: geo + assets — implement**

`server/assets/tr_cities_geo.json` (Task 14 dolduracak):
```json
{"source":"OpenStreetMap Nominatim (ODbL) — henüz üretilmedi","generatedAt":"","cities":[]}
```

`server/assets/assets.go`:
```go
// Package assets, binary'ye gömülen statik verileri taşır.
package assets

import _ "embed"

// TRCitiesGeo: Türkiye ilçe merkezlerinin koordinatları (cmd/geocode-tr üretir, ODbL).
//
//go:embed tr_cities_geo.json
var TRCitiesGeo []byte
```

`server/internal/geo/geo.go`:
```go
// Package geo, ilçe koordinat dosyasını (K7) okur.
package geo

import (
	"encoding/json"
	"fmt"

	"vakit/assets"
)

type Point struct {
	Latitude  float64
	Longitude float64
}

type Index map[int]Point

type Entry struct {
	CityID      int     `json:"cityId"`
	Name        string  `json:"name"`
	StateName   string  `json:"stateName"`
	Latitude    float64 `json:"latitude"`
	Longitude   float64 `json:"longitude"`
	DisplayName string  `json:"displayName"`
	Review      bool    `json:"review"` // elle doğrulanmadı → yayına girmez
}

type File struct {
	Source      string  `json:"source"`
	GeneratedAt string  `json:"generatedAt"`
	Cities      []Entry `json:"cities"`
}

func Parse(data []byte) (Index, error) {
	var f File
	if err := json.Unmarshal(data, &f); err != nil {
		return nil, fmt.Errorf("geo: decode: %w", err)
	}
	idx := make(Index, len(f.Cities))
	for _, e := range f.Cities {
		if e.Review {
			continue
		}
		if e.Latitude < -90 || e.Latitude > 90 || e.Longitude < -180 || e.Longitude > 180 {
			return nil, fmt.Errorf("geo: city %d has invalid coordinates %v,%v", e.CityID, e.Latitude, e.Longitude)
		}
		idx[e.CityID] = Point{Latitude: e.Latitude, Longitude: e.Longitude}
	}
	return idx, nil
}

func Load() (Index, error) { return Parse(assets.TRCitiesGeo) }
```

Run: `cd server && go test ./internal/geo/` → PASS

- [ ] **Step 3: sync places — failing test**

`server/internal/jobs/fake_source_test.go`:
```go
package jobs

import (
	"context"
	"time"

	"vakit/internal/model"
	"vakit/internal/source"
	"vakit/internal/store"
)

// fakeSource, testlerde kaynak davranışını programlar; çağrı sayılarını tutar.
type fakeSource struct {
	name          string
	countries     []model.Country
	states        map[int][]model.State
	cities        map[int][]model.City
	details       map[int]*model.CityDetail
	prayerTimes   map[string][]model.Day // "city/year"
	religiousDays map[int][]model.ReligiousDay
	daily         map[string]*model.DailyContent
	failWith      error // nil değilse veri uçları bu hatayı döner
	unsupported   bool  // CityDetail/ReligiousDays/DailyContent → ErrUnsupported
	calls         map[string]int
}

func newFake() *fakeSource {
	return &fakeSource{name: "fake", states: map[int][]model.State{}, cities: map[int][]model.City{},
		details: map[int]*model.CityDetail{}, prayerTimes: map[string][]model.Day{},
		religiousDays: map[int][]model.ReligiousDay{}, daily: map[string]*model.DailyContent{}, calls: map[string]int{}}
}

func (f *fakeSource) Name() string { return f.name }

func (f *fakeSource) Countries(context.Context) ([]model.Country, error) {
	f.calls["countries"]++
	return f.countries, f.failWith
}

func (f *fakeSource) States(_ context.Context, countryID int) ([]model.State, error) {
	f.calls["states"]++
	return f.states[countryID], f.failWith
}

func (f *fakeSource) Cities(_ context.Context, stateID int) ([]model.City, error) {
	f.calls["cities"]++
	return f.cities[stateID], f.failWith
}

func (f *fakeSource) CityDetail(_ context.Context, cityID int) (*model.CityDetail, error) {
	f.calls["detail"]++
	if f.unsupported {
		return nil, source.ErrUnsupported
	}
	if f.failWith != nil {
		return nil, f.failWith
	}
	return f.details[cityID], nil
}

func (f *fakeSource) PrayerTimes(_ context.Context, cityID, year int) ([]model.Day, error) {
	f.calls["prayer"]++
	if f.failWith != nil {
		return nil, f.failWith
	}
	return f.prayerTimes[store.CityYearKey(cityID, year)], nil
}

func (f *fakeSource) ReligiousDays(_ context.Context, year int) ([]model.ReligiousDay, error) {
	f.calls["religious"]++
	if f.unsupported {
		return nil, source.ErrUnsupported
	}
	return f.religiousDays[year], f.failWith
}

func (f *fakeSource) DailyContent(_ context.Context, date time.Time) (*model.DailyContent, error) {
	f.calls["daily"]++
	if f.unsupported {
		return nil, source.ErrUnsupported
	}
	if f.failWith != nil {
		return nil, f.failWith
	}
	return f.daily[date.Format(model.DateLayout)], nil
}

```

`server/internal/jobs/places_test.go`:
```go
package jobs

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"testing"
	"time"

	"vakit/internal/geo"
	"vakit/internal/model"
	"vakit/internal/source"
	"vakit/internal/store"
)

func f64(v float64) *float64 { return &v }

func testDeps(t *testing.T, src source.Source) Deps {
	t.Helper()
	st := store.New(t.TempDir())
	state, err := st.LoadState()
	if err != nil {
		t.Fatal(err)
	}
	return Deps{Source: src, Store: st, State: state, Logger: slog.New(slog.NewTextHandler(io.Discard, nil)),
		Now: func() time.Time { return time.Date(2026, 9, 16, 3, 0, 0, 0, time.UTC) }, Geo: geo.Index{9541: {41.0082, 28.9784}}}
}

func placesFake() *fakeSource {
	f := newFake()
	f.countries = []model.Country{{ID: 1, Name: "KUZEY KIBRIS", NameEn: "NORTH CYPRUS"}, {ID: 2, Name: "TÜRKİYE", NameEn: "TURKEY"}}
	f.states[2] = []model.State{{ID: 539, Name: "İSTANBUL", CountryID: 2}}
	f.cities[539] = []model.City{{ID: 9541, Name: "İSTANBUL", StateID: 539}, {ID: 9547, Name: "ŞİLE", StateID: 539}}
	f.details[9541] = &model.CityDetail{CityID: 9541, QiblaAngle: f64(151), QiblaAngleMagnetic: f64(146), DistanceToKaaba: f64(2400)}
	f.details[9547] = &model.CityDetail{CityID: 9547, QiblaAngle: f64(150)}
	return f
}

func TestPlaces_WritesHierarchyWithGeoAndQibla(t *testing.T) {
	f := placesFake()
	d := testDeps(t, f)
	res, err := Places(context.Background(), d, []int{2})
	if err != nil {
		t.Fatal(err)
	}
	var countries []model.Country
	if err := d.Store.ReadJSON(store.CountriesPath(), &countries); err != nil || len(countries) != 2 || !countries[1].Enabled || countries[0].Enabled {
		t.Fatalf("%v %v", countries, err)
	}
	var states []model.State
	if err := d.Store.ReadJSON(store.StatesPath(2), &states); err != nil || len(states) != 1 {
		t.Fatalf("%v %v", states, err)
	}
	var cities []model.City
	if err := d.Store.ReadJSON(store.CitiesPath(539), &cities); err != nil || len(cities) != 2 {
		t.Fatalf("%v %v", cities, err)
	}
	ist := cities[0]
	if ist.CountryID != 2 || *ist.Latitude != 41.0082 || *ist.QiblaAngle != 151 || *ist.QiblaAngleMagnetic != 146 || *ist.DistanceToKaaba != 2400 {
		t.Fatalf("%+v", ist)
	}
	if cities[1].Latitude != nil || *cities[1].QiblaAngle != 150 {
		t.Fatalf("şile: %+v", cities[1])
	}
	var tr []model.CityWithState
	if err := d.Store.ReadJSON(store.TRCitiesPath(), &tr); err != nil || len(tr) != 2 || tr[0].StateName != "İSTANBUL" {
		t.Fatalf("%v %v", tr, err)
	}
	if d.State.Places.Cities != 2 || d.State.Places.Countries != 2 || d.State.Places.UpdatedAt.IsZero() {
		t.Fatalf("%+v", d.State.Places)
	}
	if res.Written != 4 || f.calls["detail"] != 2 { // countries, states, cities, tr → 4 dosya
		t.Fatalf("%+v detail=%d", res, f.calls["detail"])
	}
}

func TestPlaces_SecondRunSkipsCityDetailForKnownQibla(t *testing.T) {
	f := placesFake()
	d := testDeps(t, f)
	if _, err := Places(context.Background(), d, []int{2}); err != nil {
		t.Fatal(err)
	}
	if _, err := Places(context.Background(), d, []int{2}); err != nil {
		t.Fatal(err)
	}
	if f.calls["detail"] != 2 {
		t.Fatalf("CityDetail must not be re-fetched when qibla is known; calls=%d", f.calls["detail"])
	}
}

func TestPlaces_UnsupportedDetailIsSkipped(t *testing.T) {
	f := placesFake()
	f.unsupported = true
	d := testDeps(t, f)
	if _, err := Places(context.Background(), d, []int{2}); err != nil {
		t.Fatal(err)
	}
	var cities []model.City
	_ = d.Store.ReadJSON(store.CitiesPath(539), &cities)
	if cities[0].QiblaAngle != nil || *cities[0].Latitude != 41.0082 {
		t.Fatalf("%+v", cities[0])
	}
}

func TestPlaces_QuotaStopsRunButKeepsWrittenFiles(t *testing.T) {
	f := placesFake()
	d := testDeps(t, f)
	f.failWith = nil
	// Countries yazılsın, States'te kota bitsin.
	orig := f.states
	f.states = map[int][]model.State{}
	fq := &quotaAfterCountries{fakeSource: f, inner: orig}
	res, err := Places(context.Background(), Deps{Source: fq, Store: d.Store, State: d.State, Logger: d.Logger, Now: d.Now, Geo: d.Geo}, []int{2})
	if !errors.Is(err, source.ErrQuotaExceeded) || res.Stopped == "" {
		t.Fatalf("err=%v res=%+v", err, res)
	}
	if !d.Store.Exists(store.CountriesPath()) || d.Store.Exists(store.StatesPath(2)) {
		t.Fatal("countries must be written, states must not")
	}
}

type quotaAfterCountries struct {
	*fakeSource
	inner map[int][]model.State
}

func (q *quotaAfterCountries) States(context.Context, int) ([]model.State, error) {
	return nil, source.ErrQuotaExceeded
}

func TestEnabledCityIDs_ReadsCitiesOfEnabledCountries(t *testing.T) {
	f := placesFake()
	d := testDeps(t, f)
	if _, err := Places(context.Background(), d, []int{2}); err != nil {
		t.Fatal(err)
	}
	ids, err := EnabledCityIDs(d.Store, []int{2})
	if err != nil || len(ids) != 2 || ids[0] != 9541 || ids[1] != 9547 {
		t.Fatalf("%v %v", ids, err)
	}
}
```

- [ ] **Step 4: Run, fail**

Run: `cd server && go test ./internal/jobs/`
Expected: FAIL — undefined `Deps`, `Places`, `EnabledCityIDs`

- [ ] **Step 5: Implement**

`server/internal/jobs/sync.go`:
```go
// Package jobs, Diyanet kaynağından veri çekip doğrulayarak store'a yazan işleri içerir (VAK.4).
// Her iş idempotent; ilerleme Deps.State üzerinden tutulur ve çağıran SaveState yapar.
package jobs

import (
	"errors"
	"fmt"
	"log/slog"
	"time"

	"vakit/internal/geo"
	"vakit/internal/source"
	"vakit/internal/store"
)

type Deps struct {
	Source source.Source
	Store  *store.Store
	State  *store.SyncState
	Logger *slog.Logger
	Now    func() time.Time
	Geo    geo.Index
}

type Result struct {
	Fetched  int
	Written  int
	Rejected int
	Skipped  int
	Errors   int
	Stopped  string // boş değilse çalıştırma erken bitti (kota, ardışık hata)
}

func (r Result) String() string {
	return fmt.Sprintf("fetched=%d written=%d rejected=%d skipped=%d errors=%d stopped=%q",
		r.Fetched, r.Written, r.Rejected, r.Skipped, r.Errors, r.Stopped)
}

// stopOnQuota: kota hatasında çalıştırma biter; ertesi cron devam eder.
func stopOnQuota(err error, res *Result) bool {
	if errors.Is(err, source.ErrQuotaExceeded) {
		res.Stopped = "quota"
		return true
	}
	return false
}
```

`server/internal/jobs/places.go`:
```go
package jobs

import (
	"context"
	"errors"
	"fmt"
	"io/fs"

	"vakit/internal/model"
	"vakit/internal/source"
	"vakit/internal/store"
)

const turkeyCountryID = 2

// Places: ülkeler → enabled ülkelerin illeri → ilçeler (+ eksikse kıble detayı, + koordinat) → dosyalar.
func Places(ctx context.Context, d Deps, enabled []int) (Result, error) {
	var res Result
	enabledSet := make(map[int]bool, len(enabled))
	for _, id := range enabled {
		enabledSet[id] = true
	}
	countries, err := d.Source.Countries(ctx)
	if err != nil {
		stopOnQuota(err, &res)
		return res, fmt.Errorf("places: countries: %w", err)
	}
	res.Fetched++
	for i := range countries {
		countries[i].Enabled = enabledSet[countries[i].ID]
	}
	if err := d.Store.WriteJSON(store.CountriesPath(), countries); err != nil {
		return res, err
	}
	res.Written++

	totalCities := 0
	var trCities []model.CityWithState
	for _, countryID := range enabled {
		states, err := d.Source.States(ctx, countryID)
		if err != nil {
			stopOnQuota(err, &res)
			return res, fmt.Errorf("places: states of %d: %w", countryID, err)
		}
		res.Fetched++
		if err := d.Store.WriteJSON(store.StatesPath(countryID), states); err != nil {
			return res, err
		}
		res.Written++
		for _, st := range states {
			cities, err := d.Source.Cities(ctx, st.ID)
			if err != nil {
				stopOnQuota(err, &res)
				return res, fmt.Errorf("places: cities of state %d: %w", st.ID, err)
			}
			res.Fetched++
			known := existingQibla(d.Store, st.ID)
			for i := range cities {
				c := &cities[i]
				c.StateID, c.CountryID = st.ID, countryID
				if p, ok := d.Geo[c.ID]; ok {
					lat, lon := p.Latitude, p.Longitude
					c.Latitude, c.Longitude = &lat, &lon
				}
				if err := fillQibla(ctx, d, c, known, &res); err != nil {
					return res, err
				}
				if countryID == turkeyCountryID {
					trCities = append(trCities, model.CityWithState{City: *c, StateName: st.Name})
				}
			}
			if err := d.Store.WriteJSON(store.CitiesPath(st.ID), cities); err != nil {
				return res, err
			}
			res.Written++
			totalCities += len(cities)
		}
	}
	if enabledSet[turkeyCountryID] {
		if err := d.Store.WriteJSON(store.TRCitiesPath(), trCities); err != nil {
			return res, err
		}
		res.Written++
	}
	d.State.Places = store.PlacesState{UpdatedAt: d.Now(), Countries: len(countries), Cities: totalCities, EnabledCountries: enabled}
	d.Logger.Info("sync places done", "countries", len(countries), "cities", totalCities, "result", res.String())
	return res, nil
}

// existingQibla, önceki çalıştırmada yazılmış ilçe dosyasındaki kıble bilgisini döner;
// böylece CityDetail yalnız eksik ilçeler için çağrılır.
func existingQibla(st *store.Store, stateID int) map[int]model.City {
	var prev []model.City
	if err := st.ReadJSON(store.CitiesPath(stateID), &prev); err != nil {
		return nil
	}
	out := make(map[int]model.City, len(prev))
	for _, c := range prev {
		if c.QiblaAngle != nil {
			out[c.ID] = c
		}
	}
	return out
}

func fillQibla(ctx context.Context, d Deps, c *model.City, known map[int]model.City, res *Result) error {
	if prev, ok := known[c.ID]; ok {
		c.QiblaAngle, c.QiblaAngleMagnetic, c.DistanceToKaaba = prev.QiblaAngle, prev.QiblaAngleMagnetic, prev.DistanceToKaaba
		res.Skipped++
		return nil
	}
	detail, err := d.Source.CityDetail(ctx, c.ID)
	switch {
	case errors.Is(err, source.ErrUnsupported):
		return nil
	case err != nil:
		if stopOnQuota(err, res) {
			return fmt.Errorf("places: city detail %d: %w", c.ID, err)
		}
		res.Errors++
		d.Logger.Warn("city detail failed; continuing without qibla", "city", c.ID, "err", err.Error())
		return nil
	}
	res.Fetched++
	c.QiblaAngle, c.QiblaAngleMagnetic, c.DistanceToKaaba = detail.QiblaAngle, detail.QiblaAngleMagnetic, detail.DistanceToKaaba
	return nil
}

// EnabledCityIDs, yazılmış yer dosyalarından enabled ülkelerin tüm ilçe kimliklerini toplar.
func EnabledCityIDs(st *store.Store, enabled []int) ([]int, error) {
	var ids []int
	for _, countryID := range enabled {
		var states []model.State
		if err := st.ReadJSON(store.StatesPath(countryID), &states); err != nil {
			if errors.Is(err, fs.ErrNotExist) {
				return nil, fmt.Errorf("sync: places for country %d not synced yet; run 'vakit sync places' first", countryID)
			}
			return nil, err
		}
		for _, s := range states {
			var cities []model.City
			if err := st.ReadJSON(store.CitiesPath(s.ID), &cities); err != nil {
				return nil, err
			}
			for _, c := range cities {
				ids = append(ids, c.ID)
			}
		}
	}
	return ids, nil
}
```

- [ ] **Step 6: Run, pass**

Run: `cd server && gofmt -l . && go vet ./... && go test ./internal/jobs/ ./internal/geo/`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add server/assets server/internal/geo server/internal/jobs
git commit -m "feat(server): yer listesi senkronu, kıble detayı ve gömülü ilçe koordinat indeksi

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 11: `sync prayer-times` — birikimli birleştirme, doğrulama, batch ve kota

**Files:**
- Create: `server/internal/jobs/prayertimes.go`, `server/internal/jobs/prayertimes_test.go`

**Interfaces:**
- Consumes: `Deps`, `Result`, `stopOnQuota` (Task 10), `validate.YearTimes/IsComplete` (Task 4), `store.PrayerTimesPath/CityYearKey/CityYearState`
- Produces: `jobs.PrayerTimes(ctx, d Deps, cityIDs []int, years []int, batch int) (Result, error)`; `const RefetchIncompleteAfter = 7 * 24 * time.Hour`; `const MaxConsecutiveErrors = 3`; `mergeDays(existing, fetched []model.Day) []model.Day` (tarih bazında birleştirir, çekilen kazanır, sıralı); `needsFetch(st store.CityYearState, now time.Time) bool`.
- Kurallar (VAK.4): eksik = hiç denenmemiş **veya** (`complete=false` **ve** son deneme ≥ 7 gün önce; "no data" denemeleri de sayılır — DateRange yer bazında ayda 10 istek). `--batch N` çekim denemesinden sonra dur. `source.ErrQuotaExceeded` → dur. Kaynak boş liste dönerse dosya yazılmaz, state'e `note:"no data"`. Doğrulama reddederse dosya değişmez, `State.Rejected++`. Ardışık 3 kaynak hatası → dur (`Stopped="errors"`).

- [ ] **Step 1: Failing tests**

`server/internal/jobs/prayertimes_test.go`:
```go
package jobs

import (
	"context"
	"errors"
	"testing"
	"time"

	"vakit/internal/model"
	"vakit/internal/source"
	"vakit/internal/store"
)

// hijriFor, takvim gününden deterministik ve ardışık-tutarlı sahte Hicri tarih üretir
// (30 günlük aylar; yıl içinde 13. ay bir sonraki Hicri yılın 1. ayına devrilir).
func hijriFor(t time.Time) model.Hijri {
	idx := t.YearDay() - 1
	month, year := idx/30+1, 1448
	if month > 12 {
		month, year = month-12, year+1
	}
	return model.Hijri{Day: idx%30 + 1, Month: month, Year: year, MonthName: model.HijriMonths[month-1]}
}

func mkDays(year int, month time.Month, day, n int) []model.Day {
	start := time.Date(year, month, day, 0, 0, 0, 0, time.UTC)
	var out []model.Day
	for i := 0; i < n; i++ {
		t := start.AddDate(0, 0, i)
		out = append(out, model.Day{Date: t.Format(model.DateLayout), Hijri: hijriFor(t),
			Fajr: "05:00", Sunrise: "06:30", Dhuhr: "13:00", Asr: "16:30", Maghrib: "19:20", Isha: "20:40"})
	}
	return out
}

func readYear(t *testing.T, st *store.Store, city, year int) model.YearTimes {
	t.Helper()
	var yt model.YearTimes
	if err := st.ReadJSON(store.PrayerTimesPath(city, year), &yt); err != nil {
		t.Fatalf("read %d/%d: %v", city, year, err)
	}
	return yt
}

func TestPrayerTimes_WritesPartialYearAndState(t *testing.T) {
	f := newFake()
	f.prayerTimes[store.CityYearKey(9541, 2026)] = mkDays(2026, 9, 15, 31)
	d := testDeps(t, f)
	res, err := PrayerTimes(context.Background(), d, []int{9541}, []int{2026}, 10)
	if err != nil {
		t.Fatal(err)
	}
	yt := readYear(t, d.Store, 9541, 2026)
	if yt.Complete || len(yt.Days) != 31 || yt.Source != "diyanet" || yt.Via != "" || yt.CityID != 9541 || yt.SchemaVersion != 1 {
		t.Fatalf("%+v", yt)
	}
	st := d.State.PrayerTimes[store.CityYearKey(9541, 2026)]
	if st.Days != 31 || st.Horizon != "2026-10-15" || st.Complete || st.LastFetchedAt != d.Now() {
		t.Fatalf("%+v", st)
	}
	if res.Fetched != 1 || res.Written != 1 {
		t.Fatalf("%+v", res)
	}
}

func TestPrayerTimes_WebSourceMarksVia(t *testing.T) {
	f := newFake()
	f.name = "web"
	f.prayerTimes[store.CityYearKey(9541, 2027)] = mkDays(2027, 1, 1, 365)
	d := testDeps(t, f)
	if _, err := PrayerTimes(context.Background(), d, []int{9541}, []int{2027}, 10); err != nil {
		t.Fatal(err)
	}
	yt := readYear(t, d.Store, 9541, 2027)
	if yt.Via != "web" || !yt.Complete {
		t.Fatalf("%+v", yt)
	}
}

func TestPrayerTimes_MergesRollingWindowIntoExistingFile(t *testing.T) {
	f := newFake()
	f.prayerTimes[store.CityYearKey(9541, 2026)] = mkDays(2026, 9, 15, 31)
	d := testDeps(t, f)
	if _, err := PrayerTimes(context.Background(), d, []int{9541}, []int{2026}, 10); err != nil {
		t.Fatal(err)
	}
	// 8 gün sonra pencere kaydı: 23 Eyl – 23 Eki; 15 Eki'nin akşamı değişti (çekilen kazanır)
	later := mkDays(2026, 9, 23, 31)
	later[22].Maghrib = "19:21"
	f.prayerTimes[store.CityYearKey(9541, 2026)] = later
	d.Now = func() time.Time { return time.Date(2026, 9, 24, 3, 0, 0, 0, time.UTC) }
	if _, err := PrayerTimes(context.Background(), d, []int{9541}, []int{2026}, 10); err != nil {
		t.Fatal(err)
	}
	yt := readYear(t, d.Store, 9541, 2026)
	if len(yt.Days) != 39 || yt.Days[0].Date != "2026-09-15" || yt.Days[38].Date != "2026-10-23" {
		t.Fatalf("len=%d first=%s last=%s", len(yt.Days), yt.Days[0].Date, yt.Days[len(yt.Days)-1].Date)
	}
	for _, day := range yt.Days {
		if day.Date == "2026-10-15" && day.Maghrib != "19:21" {
			t.Fatalf("fetched value must win: %+v", day)
		}
	}
}

func TestPrayerTimes_SkipsCompleteAndRecentIncomplete(t *testing.T) {
	f := newFake()
	f.prayerTimes[store.CityYearKey(1, 2027)] = mkDays(2027, 1, 1, 365)
	f.prayerTimes[store.CityYearKey(2, 2026)] = mkDays(2026, 9, 15, 31)
	d := testDeps(t, f)
	if _, err := PrayerTimes(context.Background(), d, []int{1, 2}, []int{2026, 2027}, 10); err != nil {
		t.Fatal(err)
	}
	f.calls["prayer"] = 0
	d.Now = func() time.Time { return time.Date(2026, 9, 18, 3, 0, 0, 0, time.UTC) } // 2 gün sonra
	res, err := PrayerTimes(context.Background(), d, []int{1, 2}, []int{2026, 2027}, 10)
	if err != nil {
		t.Fatal(err)
	}
	// 1/2027 complete → atla; 2/2026 incomplete ama 7 gün dolmadı → atla;
	// 1/2026 ve 2/2027 "no data" denemesi 2 gün önce → 7 gün dolmadı, atla.
	if f.calls["prayer"] != 0 || res.Skipped != 4 {
		t.Fatalf("calls=%d res=%+v", f.calls["prayer"], res)
	}
}

func TestPrayerTimes_RefetchesIncompleteAfterSevenDays(t *testing.T) {
	f := newFake()
	f.prayerTimes[store.CityYearKey(2, 2026)] = mkDays(2026, 9, 15, 31)
	d := testDeps(t, f)
	_, _ = PrayerTimes(context.Background(), d, []int{2}, []int{2026}, 10)
	f.calls["prayer"] = 0
	d.Now = func() time.Time { return time.Date(2026, 9, 23, 3, 0, 0, 0, time.UTC) } // 7 gün sonra
	if _, err := PrayerTimes(context.Background(), d, []int{2}, []int{2026}, 10); err != nil || f.calls["prayer"] != 1 {
		t.Fatalf("calls=%d err=%v", f.calls["prayer"], err)
	}
}

func TestPrayerTimes_BatchLimitsFetches(t *testing.T) {
	f := newFake()
	for _, id := range []int{1, 2, 3, 4, 5} {
		f.prayerTimes[store.CityYearKey(id, 2027)] = mkDays(2027, 1, 1, 365)
	}
	d := testDeps(t, f)
	res, err := PrayerTimes(context.Background(), d, []int{1, 2, 3, 4, 5}, []int{2027}, 2)
	if err != nil || res.Fetched != 2 || res.Written != 2 || res.Stopped != "batch" {
		t.Fatalf("%+v %v", res, err)
	}
}

func TestPrayerTimes_QuotaStopsRun(t *testing.T) {
	f := newFake()
	f.failWith = source.ErrQuotaExceeded
	d := testDeps(t, f)
	res, err := PrayerTimes(context.Background(), d, []int{1, 2}, []int{2027}, 10)
	if !errors.Is(err, source.ErrQuotaExceeded) || res.Stopped != "quota" || f.calls["prayer"] != 1 {
		t.Fatalf("%+v %v calls=%d", res, err, f.calls["prayer"])
	}
}

func TestPrayerTimes_ValidationRejectKeepsOldFile(t *testing.T) {
	f := newFake()
	good := mkDays(2026, 9, 15, 31)
	f.prayerTimes[store.CityYearKey(9541, 2026)] = good
	d := testDeps(t, f)
	_, _ = PrayerTimes(context.Background(), d, []int{9541}, []int{2026}, 10)
	bad := mkDays(2026, 9, 15, 31)
	bad[3].Asr = "12:00" // sıra ihlali
	f.prayerTimes[store.CityYearKey(9541, 2026)] = bad
	d.Now = func() time.Time { return time.Date(2026, 9, 30, 3, 0, 0, 0, time.UTC) }
	res, err := PrayerTimes(context.Background(), d, []int{9541}, []int{2026}, 10)
	if err != nil || res.Rejected != 1 || d.State.Rejected != 1 {
		t.Fatalf("%+v %v state=%d", res, err, d.State.Rejected)
	}
	yt := readYear(t, d.Store, 9541, 2026)
	if yt.Days[3].Asr != "16:30" {
		t.Fatal("rejected fetch must not modify the published file")
	}
}

func TestPrayerTimes_EmptyResultLeavesNoteNoFile(t *testing.T) {
	f := newFake()
	d := testDeps(t, f)
	res, err := PrayerTimes(context.Background(), d, []int{9541}, []int{2028}, 10)
	if err != nil || res.Written != 0 || d.Store.Exists(store.PrayerTimesPath(9541, 2028)) {
		t.Fatalf("%+v %v", res, err)
	}
	if d.State.PrayerTimes[store.CityYearKey(9541, 2028)].Note != "no data" {
		t.Fatalf("%+v", d.State.PrayerTimes)
	}
}

func TestPrayerTimes_ThreeConsecutiveErrorsStopRun(t *testing.T) {
	f := newFake()
	f.failWith = errors.New("boom")
	d := testDeps(t, f)
	res, err := PrayerTimes(context.Background(), d, []int{1, 2, 3, 4}, []int{2027}, 10)
	if err == nil || res.Errors != 3 || res.Stopped != "errors" || f.calls["prayer"] != 3 {
		t.Fatalf("%+v %v calls=%d", res, err, f.calls["prayer"])
	}
}

func TestMergeDays(t *testing.T) {
	a := mkDays(2026, 9, 15, 3)
	b := mkDays(2026, 9, 16, 3)
	b[0].Isha = "20:41"
	m := mergeDays(a, b)
	if len(m) != 4 || m[0].Date != "2026-09-15" || m[3].Date != "2026-09-18" || m[1].Isha != "20:41" {
		t.Fatalf("%+v", m)
	}
}
```

- [ ] **Step 2: Run, fail**

Run: `cd server && go test ./internal/jobs/`
Expected: FAIL — undefined `PrayerTimes`, `mergeDays`

- [ ] **Step 3: Implement**

`server/internal/jobs/prayertimes.go`:
```go
package jobs

import (
	"context"
	"errors"
	"fmt"
	"io/fs"
	"sort"
	"time"

	"vakit/internal/model"
	"vakit/internal/store"
	"vakit/internal/validate"
)

const (
	// Tamamlanmamış yıl (web modunda kayan pencere, API modunda henüz yayınlanmamış günler)
	// en erken bir hafta sonra yeniden çekilir: DateRange yer bazında ayda 10 istekle sınırlı.
	RefetchIncompleteAfter = 7 * 24 * time.Hour
	MaxConsecutiveErrors   = 3
)

// PrayerTimes: enabled ilçeler × yıllar için eksik veriyi çeker, mevcut dosyayla birleştirir,
// doğrular ve yazar. batch kadar çekimden sonra durur.
func PrayerTimes(ctx context.Context, d Deps, cityIDs []int, years []int, batch int) (Result, error) {
	var res Result
	consecutiveErrors := 0
	for _, year := range years {
		for _, cityID := range cityIDs {
			if res.Fetched >= batch {
				res.Stopped = "batch"
				d.Logger.Info("sync prayer-times batch limit reached", "batch", batch)
				return res, nil
			}
			key := store.CityYearKey(cityID, year)
			existing, _, err := readExisting(d.Store, cityID, year)
			if err != nil {
				return res, err
			}
			if !needsFetch(d.State.PrayerTimes[key], d.Now()) {
				res.Skipped++
				continue
			}
			res.Fetched++
			fetched, err := d.Source.PrayerTimes(ctx, cityID, year)
			if err != nil {
				if stopOnQuota(err, &res) {
					return res, fmt.Errorf("prayer-times %s: %w", key, err)
				}
				res.Errors++
				consecutiveErrors++
				d.Logger.Warn("prayer-times fetch failed", "city", cityID, "year", year, "err", err.Error())
				if consecutiveErrors >= MaxConsecutiveErrors {
					res.Stopped = "errors"
					return res, fmt.Errorf("prayer-times: %d consecutive source errors, last: %w", consecutiveErrors, err)
				}
				continue
			}
			consecutiveErrors = 0
			if len(fetched) == 0 {
				st := d.State.PrayerTimes[key]
				st.LastFetchedAt, st.Note = d.Now(), "no data"
				d.State.PrayerTimes[key] = st
				d.Logger.Info("prayer-times: source has no data yet", "city", cityID, "year", year)
				continue
			}
			merged := mergeDays(existing.Days, fetched)
			prev, _, err := readExisting(d.Store, cityID, year-1)
			if err != nil {
				return res, err
			}
			if verr := validate.YearTimes(merged, year, prev.Days); verr != nil {
				res.Rejected++
				d.State.Rejected++
				d.Logger.Warn("prayer-times rejected by validation", "city", cityID, "year", year, "problem", verr.Error())
				continue
			}
			yt := model.YearTimes{
				SchemaVersion: model.SchemaVersion, Source: model.SourceDiyanet, GeneratedAt: d.Now(),
				CityID: cityID, Year: year, Complete: validate.IsComplete(merged, year), Days: merged,
			}
			if d.Source.Name() == model.ViaWeb {
				yt.Via = model.ViaWeb
			}
			if err := d.Store.WriteJSON(store.PrayerTimesPath(cityID, year), yt); err != nil {
				return res, err
			}
			res.Written++
			d.State.PrayerTimes[key] = store.CityYearState{LastFetchedAt: d.Now(), Horizon: merged[len(merged)-1].Date,
				Complete: yt.Complete, Days: len(merged)}
		}
	}
	d.Logger.Info("sync prayer-times done", "result", res.String())
	return res, nil
}

func readExisting(st *store.Store, cityID, year int) (model.YearTimes, bool, error) {
	var yt model.YearTimes
	err := st.ReadJSON(store.PrayerTimesPath(cityID, year), &yt)
	if errors.Is(err, fs.ErrNotExist) {
		return model.YearTimes{}, false, nil
	}
	if err != nil {
		return model.YearTimes{}, false, fmt.Errorf("prayer-times: read %d/%d: %w", cityID, year, err)
	}
	return yt, true, nil
}

// needsFetch: tamamsa hayır; hiç denenmemişse evet; değilse son denemeden 7 gün geçtiyse evet
// ("no data" denemeleri de sayılır — yayınlanmamış yıl her gün sorgulanmaz).
func needsFetch(st store.CityYearState, now time.Time) bool {
	if st.Complete {
		return false
	}
	if st.LastFetchedAt.IsZero() {
		return true
	}
	return !now.Before(st.LastFetchedAt.Add(RefetchIncompleteAfter))
}

// mergeDays tarih bazında birleştirir; çekilen gün mevcut günün üstüne yazar; çıktı sıralı.
func mergeDays(existing, fetched []model.Day) []model.Day {
	byDate := make(map[string]model.Day, len(existing)+len(fetched))
	for _, d := range existing {
		byDate[d.Date] = d
	}
	for _, d := range fetched {
		byDate[d.Date] = d
	}
	out := make([]model.Day, 0, len(byDate))
	for _, d := range byDate {
		out = append(out, d)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Date < out[j].Date })
	return out
}
```

- [ ] **Step 4: Run, pass**

Run: `cd server && gofmt -l . && go vet ./... && go test ./internal/jobs/`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/internal/jobs
git commit -m "feat(server): ilçe bazlı yıllık vakit senkronu — birleştirme, doğrulama, batch ve kota

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 12: `sync religious-days`, `sync daily-content`, `sync verify`

**Files:**
- Create: `server/internal/jobs/religiousdays.go`, `server/internal/jobs/dailycontent.go`, `server/internal/jobs/verify.go`, `server/internal/jobs/other_test.go`

**Interfaces:**
- Produces: `jobs.ReligiousDays(ctx, d Deps, years []int) (Result, error)`; `jobs.DailyContent(ctx, d Deps, ahead int) (Result, error)`; `jobs.Verify(st *store.Store, logger *slog.Logger) (problems int, err error)`.
- Kurallar: `source.ErrUnsupported` → `Skipped`, uyarı logu, hata yok. Dinî günler doğrulamadan geçmezse dosya yazılmaz. Günlük içerik: bugün + `ahead` gün; dosyası olan gün atlanır; `date` alanı dosyanın gününü taşır.

- [ ] **Step 1: Failing tests**

`server/internal/jobs/other_test.go`:
```go
package jobs

import (
	"context"
	"errors"
	"testing"
	"time"

	"vakit/internal/model"
	"vakit/internal/source"
	"vakit/internal/store"
)

func TestReligiousDays_WritesValidatedYear(t *testing.T) {
	f := newFake()
	f.religiousDays[2026] = []model.ReligiousDay{
		{ID: 1, Date: "2026-01-15", Name: "Miraç Kandili", IsSpecial: true, Hijri: model.Hijri{26, 7, 1447, "Recep"}},
		{ID: 2, Date: "2026-02-19", Name: "Ramazan Başlangıcı", Hijri: model.Hijri{1, 9, 1447, "Ramazan"}},
	}
	d := testDeps(t, f)
	res, err := ReligiousDays(context.Background(), d, []int{2026})
	if err != nil || res.Written != 1 {
		t.Fatalf("%+v %v", res, err)
	}
	var got []model.ReligiousDay
	if err := d.Store.ReadJSON(store.ReligiousDaysPath(2026), &got); err != nil || len(got) != 2 {
		t.Fatalf("%v %v", got, err)
	}
	if d.State.ReligiousDays["2026"] != d.Now() {
		t.Fatalf("%+v", d.State.ReligiousDays)
	}
}

func TestReligiousDays_InvalidIsRejected(t *testing.T) {
	f := newFake()
	f.religiousDays[2026] = []model.ReligiousDay{{ID: 1, Date: "2025-12-31", Name: "x", Hijri: model.Hijri{1, 1, 1447, "Muharrem"}}}
	d := testDeps(t, f)
	res, err := ReligiousDays(context.Background(), d, []int{2026})
	if err != nil || res.Rejected != 1 || d.Store.Exists(store.ReligiousDaysPath(2026)) {
		t.Fatalf("%+v %v", res, err)
	}
}

func TestReligiousDays_UnsupportedSourceIsSkipped(t *testing.T) {
	f := newFake()
	f.unsupported = true
	d := testDeps(t, f)
	res, err := ReligiousDays(context.Background(), d, []int{2026, 2027})
	if err != nil || res.Skipped != 2 {
		t.Fatalf("%+v %v", res, err)
	}
}

func TestReligiousDays_QuotaStops(t *testing.T) {
	f := newFake()
	f.failWith = source.ErrQuotaExceeded
	d := testDeps(t, f)
	if _, err := ReligiousDays(context.Background(), d, []int{2026}); !errors.Is(err, source.ErrQuotaExceeded) {
		t.Fatal(err)
	}
}

func TestDailyContent_FetchesTodayAndAheadSkippingExisting(t *testing.T) {
	f := newFake()
	for i := 0; i < 3; i++ {
		day := time.Date(2026, 9, 16+i, 0, 0, 0, 0, time.UTC)
		f.daily[day.Format(model.DateLayout)] = &model.DailyContent{Date: day.Format(model.DateLayout), DayOfYear: day.YearDay(), Verse: "v"}
	}
	d := testDeps(t, f)
	res, err := DailyContent(context.Background(), d, 2)
	if err != nil || res.Written != 3 || res.Fetched != 3 {
		t.Fatalf("%+v %v", res, err)
	}
	var got model.DailyContent
	if err := d.Store.ReadJSON(store.DailyContentPath(time.Date(2026, 9, 17, 0, 0, 0, 0, time.UTC)), &got); err != nil || got.Date != "2026-09-17" {
		t.Fatalf("%+v %v", got, err)
	}
	f.calls["daily"] = 0
	res, err = DailyContent(context.Background(), d, 2)
	if err != nil || res.Skipped != 3 || f.calls["daily"] != 0 {
		t.Fatalf("second run must skip existing: %+v calls=%d", res, f.calls["daily"])
	}
	if d.State.DailyContent.Days != 3 {
		t.Fatalf("%+v", d.State.DailyContent)
	}
}

func TestDailyContent_UnsupportedSkips(t *testing.T) {
	f := newFake()
	f.unsupported = true
	d := testDeps(t, f)
	res, err := DailyContent(context.Background(), d, 7)
	if err != nil || res.Skipped != 8 || res.Fetched != 0 {
		t.Fatalf("%+v %v", res, err)
	}
}

func TestVerify_ReportsBrokenPublishedFiles(t *testing.T) {
	d := testDeps(t, newFake())
	good := model.YearTimes{SchemaVersion: 1, Source: "diyanet", CityID: 1, Year: 2027, Days: mkDays(2027, 1, 1, 10)}
	_ = d.Store.WriteJSON(store.PrayerTimesPath(1, 2027), good)
	bad := good
	bad.CityID = 2
	bad.Days = mkDays(2027, 1, 1, 10)
	bad.Days[5].Fajr = "23:00"
	_ = d.Store.WriteJSON(store.PrayerTimesPath(2, 2027), bad)
	_ = d.Store.WriteJSON(store.ReligiousDaysPath(2026), []model.ReligiousDay{{ID: 1, Date: "2026-01-15", Name: "x", Hijri: model.Hijri{26, 7, 1447, "Recep"}}})
	problems, err := Verify(d.Store, d.Logger)
	if err != nil || problems != 1 {
		t.Fatalf("problems=%d err=%v", problems, err)
	}
}
```

- [ ] **Step 2: Run, fail**

Run: `cd server && go test ./internal/jobs/`
Expected: FAIL — undefined

- [ ] **Step 3: Implement**

`server/internal/jobs/religiousdays.go`:
```go
package jobs

import (
	"context"
	"errors"
	"fmt"
	"strconv"

	"vakit/internal/source"
	"vakit/internal/store"
	"vakit/internal/validate"
)

func ReligiousDays(ctx context.Context, d Deps, years []int) (Result, error) {
	var res Result
	for _, year := range years {
		list, err := d.Source.ReligiousDays(ctx, year)
		if errors.Is(err, source.ErrUnsupported) {
			res.Skipped++
			d.Logger.Warn("religious-days: source does not provide religious days; skipping", "source", d.Source.Name(), "year", year)
			continue
		}
		if err != nil {
			if stopOnQuota(err, &res) {
				return res, fmt.Errorf("religious-days %d: %w", year, err)
			}
			res.Errors++
			d.Logger.Warn("religious-days fetch failed", "year", year, "err", err.Error())
			continue
		}
		res.Fetched++
		if verr := validate.ReligiousDays(list, year); verr != nil {
			res.Rejected++
			d.State.Rejected++
			d.Logger.Warn("religious-days rejected by validation", "year", year, "problem", verr.Error())
			continue
		}
		if err := d.Store.WriteJSON(store.ReligiousDaysPath(year), list); err != nil {
			return res, err
		}
		res.Written++
		d.State.ReligiousDays[strconv.Itoa(year)] = d.Now()
	}
	d.Logger.Info("sync religious-days done", "result", res.String())
	return res, nil
}
```

`server/internal/jobs/dailycontent.go`:
```go
package jobs

import (
	"context"
	"errors"
	"fmt"
	"time"

	"vakit/internal/model"
	"vakit/internal/source"
	"vakit/internal/store"
)

// DailyContent bugün + ahead gün için günün ayet/hadis/duasını çeker; var olan günü atlar.
func DailyContent(ctx context.Context, d Deps, ahead int) (Result, error) {
	var res Result
	today := d.Now().UTC().Truncate(24 * time.Hour)
	for i := 0; i <= ahead; i++ {
		day := today.AddDate(0, 0, i)
		path := store.DailyContentPath(day)
		if d.Store.Exists(path) {
			res.Skipped++
			continue
		}
		content, err := d.Source.DailyContent(ctx, day)
		if errors.Is(err, source.ErrUnsupported) {
			res.Skipped++
			continue
		}
		if err != nil {
			if stopOnQuota(err, &res) {
				return res, fmt.Errorf("daily-content %s: %w", day.Format(model.DateLayout), err)
			}
			res.Errors++
			d.Logger.Warn("daily-content fetch failed", "date", day.Format(model.DateLayout), "err", err.Error())
			continue
		}
		res.Fetched++
		if content == nil || content.Verse == "" {
			d.Logger.Warn("daily-content empty; not written", "date", day.Format(model.DateLayout))
			continue
		}
		content.Date = day.Format(model.DateLayout)
		if err := d.Store.WriteJSON(path, content); err != nil {
			return res, err
		}
		res.Written++
	}
	if res.Written > 0 {
		d.State.DailyContent.UpdatedAt = d.Now()
	}
	d.State.DailyContent.Days += res.Written
	d.Logger.Info("sync daily-content done", "result", res.String())
	return res, nil
}
```

`server/internal/jobs/verify.go`:
```go
package jobs

import (
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"vakit/internal/model"
	"vakit/internal/store"
	"vakit/internal/validate"
)

// Verify, yayınlanmış vakit ve dinî gün dosyalarını ağ kullanmadan yeniden doğrular;
// sorun sayısını döner (cron çıkış kodu için).
func Verify(st *store.Store, logger *slog.Logger) (int, error) {
	problems := 0
	root := filepath.Join(st.Root, "prayer-times")
	err := filepath.WalkDir(root, func(path string, entry os.DirEntry, err error) error {
		if err != nil {
			if os.IsNotExist(err) {
				return nil
			}
			return err
		}
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".json") {
			return nil
		}
		rel, _ := filepath.Rel(st.Root, path)
		var yt model.YearTimes
		if err := st.ReadJSON(filepath.ToSlash(rel), &yt); err != nil {
			problems++
			logger.Error("verify: unreadable", "file", rel, "err", err.Error())
			return nil
		}
		if verr := validate.YearTimes(yt.Days, yt.Year, nil); verr != nil {
			problems++
			logger.Error("verify: invalid prayer times", "file", rel, "problem", verr.Error())
		}
		return nil
	})
	if err != nil {
		return problems, fmt.Errorf("verify: walk: %w", err)
	}
	entries, err := os.ReadDir(filepath.Join(st.Root, "religious-days"))
	if err != nil && !os.IsNotExist(err) {
		return problems, err
	}
	for _, e := range entries {
		year, convErr := strconv.Atoi(strings.TrimSuffix(e.Name(), ".json"))
		if convErr != nil {
			continue
		}
		var list []model.ReligiousDay
		rel := "religious-days/" + e.Name()
		if err := st.ReadJSON(rel, &list); err != nil {
			problems++
			logger.Error("verify: unreadable", "file", rel, "err", err.Error())
			continue
		}
		if verr := validate.ReligiousDays(list, year); verr != nil {
			problems++
			logger.Error("verify: invalid religious days", "file", rel, "problem", verr.Error())
		}
	}
	logger.Info("verify done", "problems", problems)
	return problems, nil
}
```

- [ ] **Step 4: Run, pass**

Run: `cd server && gofmt -l . && go vet ./... && go test ./internal/jobs/`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/internal/jobs
git commit -m "feat(server): dinî gün ve günlük içerik senkronu, yayın doğrulama komutu

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 13: `vakit sync <iş>` CLI — kaynak seçimi, flag'ler, çıkış kodları

**Files:**
- Create: `server/cmd/vakit/sync.go`, `server/cmd/vakit/sync_test.go`
- Modify: `server/cmd/vakit/main.go` (switch'e `sync` dalı)

**Interfaces:**
- Consumes: `config.FromEnv`, `store.New/LoadState/SaveState/TokenPath`, `awqat.New`, `awqatsrc.New`, `web.New`, `geo.Load`, `sync.*`, `httpapi.NewLogger`
- Produces: `runSync(args []string, stdout, stderr io.Writer) int`; `buildSource(cfg config.Config, st *store.Store, logger *slog.Logger) (source.Source, *awqat.Client)`; `type intList []int` (`flag.Value`, tekrarlanabilir `--year`); `defaultYears(now time.Time) []int` → `{yıl, yıl+1}`.
- Çıkış kodları: `0` başarı (kota/batch nedeniyle erken bitiş de başarı, log'da `stopped` görünür); `1` iş hatası (kaynak hatası, doğrulama dışı I/O, `verify` sorun bulursa); `2` kullanım hatası.
- `quota` işi yalnız `awqat` kaynağında çalışır; web kaynağında `2` ile "kota bilgisi yalnız resmî API'de" mesajı.

- [ ] **Step 1: Failing tests**

`server/cmd/vakit/sync_test.go`:
```go
package main

import (
	"bytes"
	"flag"
	"strings"
	"testing"
	"time"
)

func TestIntList_ParsesRepeatedAndCommaSeparated(t *testing.T) {
	var years intList
	fs := flag.NewFlagSet("x", flag.ContinueOnError)
	fs.Var(&years, "year", "")
	if err := fs.Parse([]string{"--year", "2026", "--year", "2027,2028"}); err != nil {
		t.Fatal(err)
	}
	if len(years) != 3 || years[2] != 2028 {
		t.Fatalf("%v", years)
	}
	if err := fs.Parse([]string{"--year", "abc"}); err == nil {
		t.Fatal("expected parse error")
	}
}

func TestDefaultYears_CurrentAndNext(t *testing.T) {
	got := defaultYears(time.Date(2026, 9, 16, 0, 0, 0, 0, time.UTC))
	if len(got) != 2 || got[0] != 2026 || got[1] != 2027 {
		t.Fatalf("%v", got)
	}
}

func TestRunSync_UnknownJobIsUsageError(t *testing.T) {
	var out, errOut bytes.Buffer
	if code := runSync([]string{"bogus"}, &out, &errOut); code != 2 || !strings.Contains(errOut.String(), "bilinmeyen iş") {
		t.Fatalf("code=%d stderr=%s", code, errOut.String())
	}
	if code := runSync(nil, &out, &errOut); code != 2 {
		t.Fatalf("code=%d", code)
	}
}

func TestRunSync_VerifyOnEmptyDataDirSucceeds(t *testing.T) {
	t.Setenv("VAKIT_DATA_DIR", t.TempDir())
	var out, errOut bytes.Buffer
	if code := runSync([]string{"verify"}, &out, &errOut); code != 0 {
		t.Fatalf("code=%d stderr=%s stdout=%s", code, errOut.String(), out.String())
	}
}

func TestRunSync_QuotaRequiresAwqatSource(t *testing.T) {
	t.Setenv("VAKIT_DATA_DIR", t.TempDir())
	t.Setenv("VAKIT_SOURCE", "web")
	var out, errOut bytes.Buffer
	if code := runSync([]string{"quota"}, &out, &errOut); code != 2 || !strings.Contains(errOut.String(), "resmî API") {
		t.Fatalf("code=%d stderr=%s", code, errOut.String())
	}
}
```

- [ ] **Step 2: Run, fail**

Run: `cd server && go test ./cmd/vakit/`
Expected: FAIL — undefined `intList`, `defaultYears`, `runSync`

- [ ] **Step 3: Implement**

`server/cmd/vakit/sync.go`:
```go
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log/slog"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

	"vakit/internal/awqat"
	"vakit/internal/config"
	"vakit/internal/geo"
	"vakit/internal/httpapi"
	"vakit/internal/source"
	"vakit/internal/source/awqatsrc"
	"vakit/internal/source/web"
	"vakit/internal/store"
	"vakit/internal/jobs"
)

const syncUsage = `vakit sync <iş> [flags]

İşler:
  places                         ülke/il/ilçe listeleri (+ kıble, koordinat)
  prayer-times [--year Y]... [--batch N]   ilçe bazlı yıllık vakitler (varsayılan: bu yıl ve gelecek yıl)
  religious-days [--year Y]...   dinî günler
  daily-content [--ahead N]      günün ayet/hadis/duası (varsayılan 7 gün ileri)
  quota                          Diyanet kota durumunu yazdırır (yalnız awqat kaynağı)
  verify                         yayınlanmış dosyaları yeniden doğrular (ağ yok)
`

// intList: tekrarlanabilir ve virgülle ayrılabilir tam sayı flag'i (--year 2026 --year 2027,2028).
type intList []int

func (l *intList) String() string {
	parts := make([]string, len(*l))
	for i, v := range *l {
		parts[i] = strconv.Itoa(v)
	}
	return strings.Join(parts, ",")
}

func (l *intList) Set(v string) error {
	for _, part := range strings.Split(v, ",") {
		n, err := strconv.Atoi(strings.TrimSpace(part))
		if err != nil {
			return fmt.Errorf("%q is not an integer", part)
		}
		*l = append(*l, n)
	}
	return nil
}

func defaultYears(now time.Time) []int { return []int{now.Year(), now.Year() + 1} }

func runSync(args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		fmt.Fprint(stderr, syncUsage)
		return 2
	}
	job, rest := args[0], args[1:]
	cfg, err := config.FromEnv(os.Getenv)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 2
	}
	logger := httpapi.NewLogger(stdout, cfg.LogLevel)
	st := store.New(cfg.DataDir)

	if job == "verify" {
		problems, err := jobs.Verify(st, logger)
		if err != nil {
			fmt.Fprintln(stderr, err)
			return 1
		}
		if problems > 0 {
			return 1
		}
		return 0
	}

	src, client := buildSource(cfg, st, logger)
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	if job == "quota" {
		if client == nil {
			fmt.Fprintln(stderr, "kota bilgisi yalnız resmî API (VAKIT_SOURCE=awqat) kaynağında alınabilir")
			return 2
		}
		raw, err := client.QuotaMy(ctx)
		if err != nil {
			fmt.Fprintln(stderr, err)
			return 1
		}
		var pretty bytes.Buffer
		if err := json.Indent(&pretty, raw, "", "  "); err != nil {
			pretty.Write(raw)
		}
		fmt.Fprintln(stdout, pretty.String())
		return 0
	}

	state, err := st.LoadState()
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 1
	}
	geoIndex, err := geo.Load()
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 1
	}
	deps := jobs.Deps{Source: src, Store: st, State: state, Logger: logger, Now: time.Now, Geo: geoIndex}
	logger.Info("sync start", "job", job, "source", src.Name(), "data_dir", cfg.DataDir)

	var res jobs.Result
	var jobErr error
	switch job {
	case "places":
		res, jobErr = jobs.Places(ctx, deps, cfg.EnabledCountries)
	case "prayer-times":
		fs := flag.NewFlagSet("prayer-times", flag.ContinueOnError)
		fs.SetOutput(stderr)
		var years intList
		fs.Var(&years, "year", "yıl (tekrarlanabilir)")
		batch := fs.Int("batch", cfg.SyncBatch, "çalıştırma başına en çok çekim")
		if err := fs.Parse(rest); err != nil {
			return 2
		}
		if len(years) == 0 {
			years = defaultYears(time.Now())
		}
		cityIDs, err := jobs.EnabledCityIDs(st, cfg.EnabledCountries)
		if err != nil {
			fmt.Fprintln(stderr, err)
			return 1
		}
		res, jobErr = jobs.PrayerTimes(ctx, deps, cityIDs, years, *batch)
	case "religious-days":
		fs := flag.NewFlagSet("religious-days", flag.ContinueOnError)
		fs.SetOutput(stderr)
		var years intList
		fs.Var(&years, "year", "yıl (tekrarlanabilir)")
		if err := fs.Parse(rest); err != nil {
			return 2
		}
		if len(years) == 0 {
			years = defaultYears(time.Now())
		}
		res, jobErr = jobs.ReligiousDays(ctx, deps, years)
	case "daily-content":
		fs := flag.NewFlagSet("daily-content", flag.ContinueOnError)
		fs.SetOutput(stderr)
		ahead := fs.Int("ahead", 7, "kaç gün ileri")
		if err := fs.Parse(rest); err != nil {
			return 2
		}
		res, jobErr = jobs.DailyContent(ctx, deps, *ahead)
	default:
		fmt.Fprintf(stderr, "bilinmeyen iş: %q\n\n%s", job, syncUsage)
		return 2
	}

	if saveErr := st.SaveState(state); saveErr != nil {
		logger.Error("sync state could not be saved", "err", saveErr.Error())
		if jobErr == nil {
			jobErr = saveErr
		}
	}
	logger.Info("sync end", "job", job, "result", res.String())
	if jobErr != nil {
		if errors.Is(jobErr, source.ErrQuotaExceeded) {
			logger.Warn("sync stopped: quota exhausted; next run continues", "job", job)
			return 0
		}
		fmt.Fprintln(stderr, jobErr)
		return 1
	}
	return 0
}

// buildSource, config'e göre kaynağı kurar; awqat seçildiyse istemciyi de döner (quota için).
func buildSource(cfg config.Config, st *store.Store, logger *slog.Logger) (source.Source, *awqat.Client) {
	if cfg.Source == config.SourceAwqat {
		client := awqat.New(cfg.AwqatBaseURL, awqat.Credentials{Email: cfg.AwqatEmail, Password: cfg.AwqatPassword},
			filepath.Join(st.Root, filepath.FromSlash(store.TokenPath())), logger, awqat.WithInterval(cfg.SyncInterval))
		return awqatsrc.New(client), client
	}
	if cfg.AwqatEmail == "" {
		logger.Warn("AWQAT_EMAIL not set; using web source (namazvakitleri.diyanet.gov.tr)")
	}
	return web.New(web.DefaultBaseURL, web.WithInterval(maxDuration(cfg.SyncInterval, time.Second))), nil
}

func maxDuration(a, b time.Duration) time.Duration {
	if a > b {
		return a
	}
	return b
}
```

`server/cmd/vakit/main.go` switch'e ekle:
```go
	case "sync":
		return runSync(args[1:], stdout, stderr)
```

- [ ] **Step 4: Run, pass**

Run: `cd server && gofmt -l . && go vet ./... && go test ./...`
Expected: PASS

- [ ] **Step 5: Uçtan uca duman testi (ağ, web kaynağı)**

```bash
cd server && export VAKIT_DATA_DIR=$(mktemp -d) VAKIT_SYNC_INTERVAL=1s
go run ./cmd/vakit sync places            # ~83 istek (ülke sayfası + 81 il + ...): ~2 dk
go run ./cmd/vakit sync prayer-times --year 2027 --batch 2
go run ./cmd/vakit sync verify
ls $VAKIT_DATA_DIR/places/tr $VAKIT_DATA_DIR/prayer-times/*
go run ./cmd/vakit serve & sleep 1
curl -s http://127.0.0.1:8080/v1/health | head -c 600; echo
curl -s http://127.0.0.1:8080/v1/places/tr/cities | head -c 300; echo
curl -s -D - -o /dev/null http://127.0.0.1:8080/v1/prayer-times/9541/2027 | grep -i "etag\|cache-control\|HTTP/"
kill %1
```
Expected: `places/tr/cities.json` 900+ ilçe (koordinat henüz null); iki ilçe için `2027.json` `complete:true`, 365 gün; `verify` 0 sorun; health `prayerTimes.2027.cities=2`; 200 + ETag + `max-age=86400`.

- [ ] **Step 6: Commit**

```bash
git add server/cmd/vakit
git commit -m "feat(server): vakit sync komutları — kaynak seçimi, flag'ler, kota/batch çıkış kodları

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 14: `cmd/geocode-tr` — ilçe koordinatları (Nominatim, tek seferlik)

**Files:**
- Create: `server/cmd/geocode-tr/main.go`, `server/cmd/geocode-tr/pick.go`, `server/cmd/geocode-tr/pick_test.go`
- Modify: `server/assets/tr_cities_geo.json` (üretilen veri)

**Interfaces:**
- Consumes: `model.CityWithState` (`places/tr/cities.json`), `geo.File/Entry`
- Produces: `pickResult(results []nominatimResult, stateName string) (nominatimResult, bool /*review*/)`; `foldTR(s string) string`; `buildQuery(city model.CityWithState) url.Values`.
- Nominatim kullanım politikası: **en fazla 1 istek/sn**, tanımlayıcı `User-Agent` + iletişim e-postası, sonuç ODbL → atıf. Araç `--contact` zorunlu, 1100 ms aralık, `--limit N` ile deneme, mevcut çıktı dosyasındaki ilçeleri atlar (resumable).

- [ ] **Step 1: Failing tests**

`server/cmd/geocode-tr/pick_test.go`:
```go
package main

import (
	"testing"

	"vakit/internal/model"
)

func TestFoldTR(t *testing.T) {
	if foldTR("İSTANBUL") != "istanbul" || foldTR("IĞDIR") != "ığdır" || foldTR("Şile") != "şile" {
		t.Fatalf("%q %q %q", foldTR("İSTANBUL"), foldTR("IĞDIR"), foldTR("Şile"))
	}
}

func TestPickResult_PrefersMatchWithinState(t *testing.T) {
	results := []nominatimResult{
		{Lat: "40.0", Lon: "29.0", DisplayName: "Merkez, Bursa, Türkiye", AddressType: "town"},
		{Lat: "41.17", Lon: "29.61", DisplayName: "Şile, İstanbul, Marmara Bölgesi, Türkiye", AddressType: "town"},
	}
	got, review := pickResult(results, "İSTANBUL")
	if review || got.Lat != "41.17" {
		t.Fatalf("%+v review=%v", got, review)
	}
}

func TestPickResult_FlagsReviewWhenNoStateMatch(t *testing.T) {
	results := []nominatimResult{{Lat: "1", Lon: "2", DisplayName: "Somewhere, Ankara, Türkiye", AddressType: "village"}}
	got, review := pickResult(results, "İZMİR")
	if !review || got.Lat != "1" {
		t.Fatalf("%+v review=%v", got, review)
	}
	if _, review := pickResult(nil, "İZMİR"); !review {
		t.Fatal("empty results must be flagged")
	}
}

func TestBuildQuery(t *testing.T) {
	q := buildQuery(model.CityWithState{City: model.City{Name: "ŞİLE"}, StateName: "İSTANBUL"})
	if q.Get("q") != "ŞİLE, İSTANBUL, Türkiye" || q.Get("countrycodes") != "tr" || q.Get("format") != "jsonv2" || q.Get("limit") != "5" {
		t.Fatalf("%v", q)
	}
}
```

- [ ] **Step 2: Run, fail**

Run: `cd server && go test ./cmd/geocode-tr/`
Expected: FAIL — undefined

- [ ] **Step 3: Implement**

`server/cmd/geocode-tr/pick.go`:
```go
package main

import (
	"net/url"
	"strings"

	"vakit/internal/model"
)

type nominatimResult struct {
	Lat         string  `json:"lat"`
	Lon         string  `json:"lon"`
	DisplayName string  `json:"display_name"`
	AddressType string  `json:"addresstype"`
	Importance  float64 `json:"importance"`
}

// foldTR: Türkçe büyük İ/I kurallarıyla küçük harfe indirir (strings.ToLower I→i yapar, yanlış).
func foldTR(s string) string {
	s = strings.NewReplacer("İ", "i", "I", "ı").Replace(s)
	return strings.ToLower(s)
}

func buildQuery(city model.CityWithState) url.Values {
	return url.Values{
		"q":            {city.Name + ", " + city.StateName + ", Türkiye"},
		"format":       {"jsonv2"},
		"limit":        {"5"},
		"countrycodes": {"tr"},
	}
}

// pickResult: display_name içinde il adı geçen ilk sonucu seçer; yoksa ilk sonucu
// review=true ile döner (elle bakılacak). Hiç sonuç yoksa boş + review.
func pickResult(results []nominatimResult, stateName string) (nominatimResult, bool) {
	if len(results) == 0 {
		return nominatimResult{}, true
	}
	want := foldTR(stateName)
	for _, r := range results {
		if strings.Contains(foldTR(r.DisplayName), want) {
			return r, false
		}
	}
	return results[0], true
}
```

`server/cmd/geocode-tr/main.go`:
```go
// Command geocode-tr, places/tr/cities.json'daki ilçeleri Nominatim ile koordinata
// çevirir ve assets/tr_cities_geo.json üretir. Tek seferlik araç; çıktı elle gözden
// geçirilip commit'lenir. Nominatim politikası: ≤ 1 istek/sn, tanımlayıcı User-Agent.
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"
	"time"

	"vakit/internal/geo"
	"vakit/internal/model"
)

const (
	nominatimURL    = "https://nominatim.openstreetmap.org/search"
	requestInterval = 1100 * time.Millisecond
	requestTimeout  = 30 * time.Second
)

func main() {
	in := flag.String("in", "data/places/tr/cities.json", "vakit sync places çıktısı")
	out := flag.String("out", "assets/tr_cities_geo.json", "üretilecek dosya (varsa üstüne devam eder)")
	contact := flag.String("contact", "", "Nominatim User-Agent için iletişim e-postası (zorunlu)")
	limit := flag.Int("limit", 0, "en çok N ilçe (0 = hepsi)")
	flag.Parse()
	if *contact == "" {
		fmt.Fprintln(os.Stderr, "--contact zorunlu (Nominatim kullanım politikası)")
		os.Exit(2)
	}
	if err := run(*in, *out, *contact, *limit); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run(inPath, outPath, contact string, limit int) error {
	raw, err := os.ReadFile(inPath)
	if err != nil {
		return fmt.Errorf("önce 'vakit sync places' çalıştır: %w", err)
	}
	var cities []model.CityWithState
	if err := json.Unmarshal(raw, &cities); err != nil {
		return err
	}
	file := geo.File{Source: "OpenStreetMap Nominatim (ODbL) — © OpenStreetMap contributors"}
	if existing, err := os.ReadFile(outPath); err == nil {
		_ = json.Unmarshal(existing, &file)
	}
	done := make(map[int]bool, len(file.Cities))
	for _, e := range file.Cities {
		done[e.CityID] = true
	}
	client := &http.Client{Timeout: requestTimeout}
	processed := 0
	for _, city := range cities {
		if done[city.ID] {
			continue
		}
		if limit > 0 && processed >= limit {
			break
		}
		entry, err := geocode(client, contact, city)
		if err != nil {
			return fmt.Errorf("%s/%s: %w", city.StateName, city.Name, err)
		}
		file.Cities = append(file.Cities, entry)
		processed++
		fmt.Printf("%4d/%d %-28s %-16s %8.4f %8.4f review=%v\n", len(file.Cities), len(cities), city.Name, city.StateName, entry.Latitude, entry.Longitude, entry.Review)
		file.GeneratedAt = time.Now().UTC().Format(time.RFC3339)
		if err := writeFile(outPath, file); err != nil { // her adımda yaz: kesilirse kaldığı yerden devam eder
			return err
		}
		time.Sleep(requestInterval)
	}
	review := 0
	for _, e := range file.Cities {
		if e.Review {
			review++
		}
	}
	fmt.Printf("bitti: %d ilçe, %d elle gözden geçirilecek (review=true)\n", len(file.Cities), review)
	return nil
}

func geocode(client *http.Client, contact string, city model.CityWithState) (geo.Entry, error) {
	req, err := http.NewRequest(http.MethodGet, nominatimURL+"?"+buildQuery(city).Encode(), nil)
	if err != nil {
		return geo.Entry{}, err
	}
	req.Header.Set("User-Agent", "vakit-api geocode-tr/1.0 ("+contact+")")
	resp, err := client.Do(req)
	if err != nil {
		return geo.Entry{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return geo.Entry{}, fmt.Errorf("nominatim HTTP %d", resp.StatusCode)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return geo.Entry{}, err
	}
	var results []nominatimResult
	if err := json.Unmarshal(body, &results); err != nil {
		return geo.Entry{}, err
	}
	picked, review := pickResult(results, city.StateName)
	entry := geo.Entry{CityID: city.ID, Name: city.Name, StateName: city.StateName, DisplayName: picked.DisplayName, Review: review}
	if picked.Lat != "" {
		entry.Latitude, _ = strconv.ParseFloat(picked.Lat, 64)
		entry.Longitude, _ = strconv.ParseFloat(picked.Lon, 64)
	}
	return entry, nil
}

func writeFile(path string, file geo.File) error {
	data, err := json.MarshalIndent(file, "", " ")
	if err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}
```

- [ ] **Step 4: Run, pass**

Run: `cd server && gofmt -l . && go vet ./... && go test ./cmd/geocode-tr/`
Expected: PASS

- [ ] **Step 5: Üret (ağ, ~20 dk)**

```bash
cd server && export VAKIT_DATA_DIR=./data && go run ./cmd/vakit sync places
go run ./cmd/geocode-tr --contact <iletişim-e-postası> --limit 5      # deneme
go run ./cmd/geocode-tr --contact <iletişim-e-postası>                # hepsi (~970 × 1,1 s)
grep -c '"review": true' assets/tr_cities_geo.json
```
`review: true` kayıtları elle incele: `displayName` yanlış ilçeyse koordinatı düzelt ya da `review` bırak (yayına girmez → o ilçe koordinatsız kalır, uygulama listeden seçtirir). Düzelttiklerinde `review` alanını `false` yap.

- [ ] **Step 6: Gömülü asset testi ve places yeniden**

Run: `cd server && go test ./internal/geo/ && go run ./cmd/vakit sync places && python3 -c "import json;c=json.load(open('data/places/tr/cities.json'));print(sum(1 for x in c if x['latitude'] is not None),'/',len(c),'koordinatlı')"`
Expected: koordinatlı ilçe sayısı ≈ toplam − review.

- [ ] **Step 7: Commit**

```bash
git add server/cmd/geocode-tr server/assets/tr_cities_geo.json
git commit -m "feat(server): Türkiye ilçe koordinatları (OSM Nominatim) ve geocode-tr aracı

Koordinatlar © OpenStreetMap contributors, ODbL.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 15: Docker, compose, cloudflared örneği, Makefile, README

**Files:**
- Create: `server/deploy/Dockerfile`, `server/deploy/compose.yml`, `server/deploy/.env.example`, `server/deploy/cloudflared.example.yml`, `server/Makefile`, `server/README.md`

**Interfaces:**
- Consumes: `vakit` binary (Task 13), env değişkenleri (Task 5)
- Produces: `docker compose -f server/deploy/compose.yml up -d` ile çalışan `serve`; `docker compose run --rm vakit sync ...` ile cron çağrıları; `make build|test|vet|smoke`.

- [ ] **Step 1: Dockerfile**

`server/deploy/Dockerfile`:
```dockerfile
# syntax=docker/dockerfile:1
FROM golang:1.24-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
ARG VERSION=dev
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w -X main.version=${VERSION}" -o /out/vakit ./cmd/vakit

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/vakit /vakit
VOLUME ["/data"]
ENV VAKIT_DATA_DIR=/data VAKIT_ADDR=0.0.0.0:8080
EXPOSE 8080
ENTRYPOINT ["/vakit"]
CMD ["serve"]
```
Not: konteyner içinde `0.0.0.0:8080`; host'a yalnız `127.0.0.1:8080` yayınlanır (compose) → dışarıdan erişim yok, tünel host loopback'e bağlanır.

- [ ] **Step 2: compose ve env örneği**

`server/deploy/compose.yml`:
```yaml
services:
  vakit:
    build:
      context: ..
      dockerfile: deploy/Dockerfile
      args:
        VERSION: ${VAKIT_VERSION:-dev}
    image: vakit-api:local
    restart: unless-stopped
    ports:
      - "127.0.0.1:8080:8080"
    env_file:
      - .env
    environment:
      VAKIT_DATA_DIR: /data
      VAKIT_ADDR: 0.0.0.0:8080
    volumes:
      - ./data:/data
    command: ["serve"]
```

`server/deploy/.env.example`:
```
# Diyanet Awqat Salah hesabı (onay sonrası). Boşsa kaynak otomatik web olur.
AWQAT_EMAIL=
AWQAT_PASSWORD=
# awqat | web (boş: kimlik varsa awqat)
VAKIT_SOURCE=
VAKIT_ENABLED_COUNTRIES=2
VAKIT_SYNC_BATCH=150
VAKIT_SYNC_INTERVAL=500ms
VAKIT_LOG_LEVEL=info
```

`server/deploy/cloudflared.example.yml` (mevcut tünel config'ine eklenecek ingress satırı):
```yaml
ingress:
  - hostname: api.<domain>
    service: http://127.0.0.1:8080
  - service: http_status:404
```

- [ ] **Step 3: Makefile**

`server/Makefile`:
```makefile
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)

.PHONY: build test vet fmt smoke docker

build:
	CGO_ENABLED=0 go build -trimpath -ldflags="-s -w -X main.version=$(VERSION)" -o vakit ./cmd/vakit

test:
	go test ./...

vet:
	gofmt -l . && go vet ./...

fmt:
	gofmt -w .

docker:
	docker build -f deploy/Dockerfile --build-arg VERSION=$(VERSION) -t vakit-api:$(VERSION) .

# Ağ gerektirir: web kaynağıyla tek ilçe uçtan uca (sync → serve → curl).
smoke: build
	@set -e; export VAKIT_DATA_DIR=$$(mktemp -d) VAKIT_SOURCE=web VAKIT_SYNC_INTERVAL=1s; \
	./vakit sync places; \
	./vakit sync prayer-times --year $$(date +%Y) --year $$(( $$(date +%Y) + 1 )) --batch 1; \
	./vakit sync verify; \
	./vakit serve & PID=$$!; sleep 1; \
	curl -fsS http://127.0.0.1:8080/v1/health | head -c 400; echo; \
	curl -fsS -o /dev/null -w "tr/cities %{http_code} %{size_download}B\n" http://127.0.0.1:8080/v1/places/tr/cities; \
	kill $$PID; echo smoke ok
```

- [ ] **Step 4: README**

`server/README.md` içeriği (başlıklar ve gerekli komutlar):
```markdown
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
| AWQAT_EMAIL / AWQAT_PASSWORD | — | Diyanet hesabı; yalnız sunucuda |
| AWQAT_BASE_URL | https://awqatsalah.diyanet.gov.tr | |
| VAKIT_SOURCE | awqat (kimlik yoksa web) | awqat \| web |
| VAKIT_DATA_DIR | ./data | yayın dosyaları |
| VAKIT_ADDR | 127.0.0.1:8080 | |
| VAKIT_ENABLED_COUNTRIES | 2 | Diyanet ülke id'leri |
| VAKIT_SYNC_BATCH | 150 | çalıştırma başına en çok çekim |
| VAKIT_SYNC_INTERVAL | 500ms | istekler arası bekleme |
| VAKIT_LOG_LEVEL | info | debug\|info\|warn\|error |

## Sunucuya kurulum
    git clone … && cd ezanvakti/server/deploy
    cp .env.example .env && chmod 600 .env    # kimlik bilgilerini doldur (onay sonrası)
    docker compose up -d --build
    docker compose run --rm vakit sync places
    docker compose run --rm vakit sync prayer-times --batch 150
    docker compose run --rm vakit sync religious-days
    docker compose run --rm vakit sync daily-content --ahead 7
    curl -s http://127.0.0.1:8080/v1/health

### Cron (host)
    0 3 * * *   cd /srv/ezanvakti/server/deploy && docker compose run --rm vakit sync prayer-times --batch 150 >> /var/log/vakit-sync.log 2>&1
    0 4 * * 1   cd /srv/ezanvakti/server/deploy && docker compose run --rm vakit sync places >> /var/log/vakit-sync.log 2>&1
    0 4 1 * *   cd /srv/ezanvakti/server/deploy && docker compose run --rm vakit sync religious-days >> /var/log/vakit-sync.log 2>&1
    15 0 * * *  cd /srv/ezanvakti/server/deploy && docker compose run --rm vakit sync daily-content --ahead 7 >> /var/log/vakit-sync.log 2>&1
    30 5 * * 0  cd /srv/ezanvakti/server/deploy && docker compose run --rm vakit sync verify >> /var/log/vakit-sync.log 2>&1

### Cloudflare Tunnel
`cloudflared` ingress: `api.<domain>` → `http://127.0.0.1:8080` (bkz. `deploy/cloudflared.example.yml`).
Cloudflare panelinde: Cache Rule `hostname eq "api.<domain>" and starts_with(http.request.uri.path, "/v1/")`
→ Eligible for cache, origin Cache-Control'e uy; Rate limiting rule `/v1/*` IP başına 60 istek / 10 sn.
Doğrulama: `curl -I https://api.<domain>/v1/health` → 200; ikinci istekte vakit ucunda `cf-cache-status: HIT`.

## Komutlar
    vakit serve
    vakit sync places | prayer-times [--year Y]... [--batch N] | religious-days [--year Y]... | daily-content [--ahead N] | quota | verify
    vakit version

## Veri lisansı
İlçe koordinatları © OpenStreetMap contributors (ODbL). Vakit verisi: T.C. Diyanet İşleri Başkanlığı.
```

- [ ] **Step 5: Doğrula**

```bash
cd server && make vet test && make docker && docker run --rm vakit-api:$(git describe --tags --always --dirty) version
make smoke
```
Expected: imaj derlenir, `version` çıktısı git describe; smoke `smoke ok`.

- [ ] **Step 6: Commit**

```bash
git add server/deploy server/Makefile server/README.md
git commit -m "build(server): Docker imajı, compose, cloudflared örneği, Makefile ve kurulum belgesi

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 16: GitHub Actions — `server-ci`

**Files:**
- Create: `.github/workflows/server-ci.yml`

- [ ] **Step 1: Workflow**

```yaml
name: server-ci

on:
  push:
    branches: ["dev", "main", "feature/**"]
    paths: ["server/**", ".github/workflows/server-ci.yml"]
  pull_request:
    paths: ["server/**", ".github/workflows/server-ci.yml"]

jobs:
  test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: server
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version-file: server/go.mod
          cache-dependency-path: server/go.sum
      - name: Format check
        run: test -z "$(gofmt -l .)" || (gofmt -l . && exit 1)
      - name: Vet
        run: go vet ./...
      - name: Test
        run: go test -race ./...
      - name: Docker build
        run: docker build -f deploy/Dockerfile -t vakit-api:ci .
```

- [ ] **Step 2: Yerelde eşdeğerini çalıştır**

Run: `cd server && test -z "$(gofmt -l .)" && go vet ./... && go test -race ./... && docker build -f deploy/Dockerfile -t vakit-api:ci .`
Expected: hepsi geçer.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/server-ci.yml
git commit -m "ci(server): Go vet/test/race ve Docker build iş akışı

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 17: Doküman senkronu

**Files:**
- Modify: `docs/superpowers/specs/2026-09-15-vakit-api-sunucu-design.md` (durum satırı + VAK.7 `internal/jobs`), `docs/ROADMAP.md` ("Diyanet birebir vakit" teknik borç satırı), `docs/ARCHITECTURE.md` (sunucu bileşenine kısa işaret), `docs/DEVELOPMENT.md` (`server/` geliştirme notu)

- [ ] **Step 1: Spec**

Durum satırı: `**Durum:** taslak, kullanıcı incelemesinde` → `**Durum:** kabul edildi; implementasyon planı docs/superpowers/plans/2026-09-16-vakit-api-sunucu.md`. VAK.7 ağacında `internal/sync/` → `internal/jobs/` (Go stdlib `sync` ile ad çakışmasını önlemek için).

- [ ] **Step 2: ROADMAP**

`docs/ROADMAP.md` satır 40 civarındaki `- **Diyanet birebir vakit:** …` maddesini şu şekle getir:
```
- **Diyanet birebir vakit:** Aladhan method=13 yaklaşık hesaptır. Karar (2026-09-15): tek kaynak Diyanet; veri kendi sunucumuzda (`server/`, Go, `/v1`) barındırılır, uygulama il/ilçe seçer. Spec A: `docs/superpowers/specs/2026-09-15-vakit-api-sunucu-design.md`; uygulama tarafı Spec B (yazılacak). API onayına kadar web kaynağı.
```

- [ ] **Step 3: ARCHITECTURE ve DEVELOPMENT**

`docs/ARCHITECTURE.md` "Provider soyutlaması" bölümünün sonuna bir paragraf:
```
> **Sunucu (2026-09):** `server/` altındaki Go servisi Diyanet verisini `/v1` sözleşmesiyle sunar
> (bkz. spec A). Uygulama tarafındaki `DiyanetProvider` bu sözleşmeyi tüketir; Aladhan yalnız geçiş
> süresince kalır. Ayrıntı: `server/README.md`.
```
`docs/DEVELOPMENT.md` sonuna "Sunucu (`server/`)" başlığı: `brew install go`, `cd server && make vet test`, `make smoke`, deploy için `server/README.md`.

- [ ] **Step 4: Kontrol ve commit**

Run: `git diff --check`

```bash
git add docs/superpowers/specs/2026-09-15-vakit-api-sunucu-design.md docs/ROADMAP.md docs/ARCHITECTURE.md docs/DEVELOPMENT.md
git commit -m "docs: vakit-api sunucusu için spec durumu, yol haritası ve geliştirme notları

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Plan sonu — teslim kontrolü

- Spec kapsamı: VAK.1 (Task 5), VAK.2 (Task 6–7), VAK.3 (Task 9), VAK.4 (Task 10–13), VAK.5 (Task 4), VAK.6 (Task 5), VAK.7 (Task 1, 10, 15), VAK.8 (Task 5), VAK.9 (Task 15), VAK.10 (Task 5, 13), VAK.11 (her task'ın testleri + Task 16 CI). K7 (Task 14).
- Spec'ten sapmalar (bilinçli): ETag sidecar yok, okurken hesaplanır (spec güncellendi); paket adı `internal/jobs` (stdlib `sync` çakışması); Place uçları v1.
- Uygulama tarafı (Spec B) bu planın kapsamı dışında; `/v1` sözleşmesi Task 5 testleriyle sabitlenmiştir.
- Sunucuya kurulum ve Cloudflare kuralları kullanıcının elinde (Task 15 README adımları); API onayı gelince `.env` doldurulur, `vakit sync quota` ile kota ölçülür, `VAKIT_SYNC_BATCH` ayarlanır.
