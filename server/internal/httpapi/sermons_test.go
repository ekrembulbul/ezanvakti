package httpapi

import (
	"encoding/json"
	"testing"
	"time"

	"vakit/internal/sermon"
	"vakit/internal/store"
)

func seedSermons(t *testing.T, st *store.Store) {
	t.Helper()
	idx := sermon.Index{SchemaVersion: 1, UpdatedAt: time.Date(2026, 10, 1, 19, 0, 4, 0, time.UTC), Sermons: []sermon.Summary{{
		ID: "2026-09-25-cuma", Date: "2026-09-25", Kind: sermon.KindCuma, Title: "Tebliğ Sorumluluğumuz",
		SourceURL: "https://www.diyanethaber.com.tr/25-eylul-2026-cuma-hutbesi", ModifiedAt: "2026-09-25T11:28:09+03:00",
		PDFs: map[string]sermon.PDF{},
	}}}
	if err := st.WriteJSON(store.SermonIndexPath(), idx); err != nil {
		t.Fatal(err)
	}
	text := sermon.Text{ID: "2026-09-25-cuma", Date: "2026-09-25", Kind: sermon.KindCuma, Title: "Tebliğ Sorumluluğumuz",
		Heading: "TEBLİĞ SORUMLULUĞUMUZ", Paragraphs: []string{"Muhterem Müslümanlar!"}, Footnotes: []sermon.Footnote{{N: 1, Text: "Nahl, 16/125."}},
		Signature: "Din Hizmetleri Genel Müdürlüğü", SourceURL: idx.Sermons[0].SourceURL, ModifiedAt: idx.Sermons[0].ModifiedAt}
	if err := st.WriteJSON(store.SermonTextPath(text.ID), text); err != nil {
		t.Fatal(err)
	}
}

func TestSermons_IndexAndTextWithCacheHeaders(t *testing.T) {
	h, st := newTestHandler(t)
	seedSermons(t, st)
	rec := get(t, h, "GET", "/v1/sermons", nil)
	if rec.Code != 200 || rec.Header().Get("Cache-Control") != "public, max-age=900" || rec.Header().Get("ETag") == "" {
		t.Fatalf("%d %q %s", rec.Code, rec.Header().Get("Cache-Control"), rec.Body.String())
	}
	var idx sermon.Index
	if err := json.Unmarshal(rec.Body.Bytes(), &idx); err != nil || len(idx.Sermons) != 1 || idx.Sermons[0].ID != "2026-09-25-cuma" {
		t.Fatalf("%v %s", err, rec.Body.String())
	}
	rec = get(t, h, "GET", "/v1/sermons/2026-09-25-cuma", nil)
	if rec.Code != 200 || rec.Header().Get("Cache-Control") != "public, max-age=3600" {
		t.Fatalf("%d %q %s", rec.Code, rec.Header().Get("Cache-Control"), rec.Body.String())
	}
	var text sermon.Text
	if err := json.Unmarshal(rec.Body.Bytes(), &text); err != nil || text.Heading != "TEBLİĞ SORUMLULUĞUMUZ" {
		t.Fatalf("%v %s", err, rec.Body.String())
	}
	etag := rec.Header().Get("ETag")
	if again := get(t, h, "GET", "/v1/sermons/2026-09-25-cuma", map[string]string{"If-None-Match": etag}); again.Code != 304 {
		t.Fatalf("304 expected, got %d", again.Code)
	}
}

func TestSermons_UnknownOrMalformedIDIs404NoStore(t *testing.T) {
	h, st := newTestHandler(t)
	seedSermons(t, st)
	for _, target := range []string{"/v1/sermons/2026-09-18-cuma", "/v1/sermons/..%2Fx", "/v1/sermons/..%2F..%2Fstate%2Fvakit.db",
		"/v1/sermons/index", "/v1/sermons/2026-09-25-cuma.json", "/v1/sermons/2026-09-25-kandil", "/v1/sermons/2026-09-25-cuma/x"} {
		rec := get(t, h, "GET", target, nil)
		if rec.Code != 404 || errorCode(t, rec.Body.String()) != "NOT_FOUND" || rec.Header().Get("Cache-Control") != "no-store" {
			t.Errorf("%s: %d %q %s", target, rec.Code, rec.Header().Get("Cache-Control"), rec.Body.String())
		}
	}
	// Ham "..": ServeMux yolu temizleyip /v1/x'e yönlendirir; hutbe dosyası asla sunulmaz.
	if rec := get(t, h, "GET", "/v1/sermons/../x", nil); rec.Code == 200 {
		t.Fatalf("dot-dot path served: %d %s", rec.Code, rec.Body.String())
	}
}

func TestSermons_NotSyncedYetIs404(t *testing.T) {
	h, _ := newTestHandler(t)
	if rec := get(t, h, "GET", "/v1/sermons", nil); rec.Code != 404 || errorCode(t, rec.Body.String()) != "NOT_FOUND" {
		t.Fatalf("%d %s", rec.Code, rec.Body.String())
	}
}

func TestHealth_SermonsSummaryFromIndex(t *testing.T) {
	h, st := newTestHandler(t)
	var body struct {
		Datasets struct {
			Sermons struct {
				UpdatedAt time.Time `json:"updatedAt"`
				Count     int       `json:"count"`
			} `json:"sermons"`
		} `json:"datasets"`
	}
	rec := get(t, h, "GET", "/v1/health", nil)
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil || rec.Code != 200 || body.Datasets.Sermons.Count != 0 {
		t.Fatalf("%v %d %s", err, rec.Code, rec.Body.String())
	}
	seedSermons(t, st)
	rec = get(t, h, "GET", "/v1/health", nil)
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil || body.Datasets.Sermons.Count != 1 ||
		!body.Datasets.Sermons.UpdatedAt.Equal(time.Date(2026, 10, 1, 19, 0, 4, 0, time.UTC)) {
		t.Fatalf("%v %s", err, rec.Body.String())
	}
}
