package httpapi

import (
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"vakit/internal/db"
	"vakit/internal/model"
	"vakit/internal/store"
)

func newTestHandler(t *testing.T) (http.Handler, *store.Store) {
	t.Helper()
	st := store.New(t.TempDir())
	yt := model.YearTimes{SchemaVersion: 1, Source: "diyanet", CityID: 9541, Year: 2026, Days: []model.Day{
		{Date: "2026-09-15", Hijri: model.Hijri{Day: 4, Month: 4, Year: 1448, MonthName: "Rebiulahir"}, Fajr: "05:11", Sunrise: "06:37",
			Dhuhr: "13:04", Asr: "16:35", Maghrib: "19:22", Isha: "20:43"}}}
	if err := st.WriteJSON(store.PrayerTimesPath(9541, 2026), yt); err != nil {
		t.Fatal(err)
	}
	_ = st.WriteJSON(store.CountriesPath(), []model.Country{{ID: 2, Name: "TÜRKİYE", NameEn: "TURKEY", Enabled: true}})
	database, err := db.Open(filepath.Join(st.Root, store.DBPath()))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = database.Close() })
	state := store.NewSyncState()
	state.PrayerTimes[store.CityYearKey(9541, 2026)] = store.CityYearState{Days: 1, Horizon: "2026-09-15",
		LastFetchedAt: time.Date(2026, 9, 15, 20, 0, 0, 0, time.UTC)}
	state.PrayerTimes[store.CityYearKey(9547, 2026)] = store.CityYearState{Days: 365, Complete: true,
		LastFetchedAt: time.Date(2026, 9, 16, 3, 0, 0, 0, time.UTC)}
	if err := database.SaveSyncState(state); err != nil {
		t.Fatal(err)
	}
	logger := NewLogger(io.Discard, slog.LevelDebug)
	return NewHandler(st, database, Options{Version: "test", StartedAt: time.Now()}, logger), st
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
