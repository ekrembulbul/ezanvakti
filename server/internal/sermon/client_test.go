package sermon

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func testClient(t *testing.T, h http.HandlerFunc, opts ...Option) (*Client, *httptest.Server, *atomic.Int32) {
	t.Helper()
	var hits atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		hits.Add(1)
		h(w, r)
	}))
	t.Cleanup(srv.Close)
	all := append([]Option{WithHTTPClient(srv.Client()), WithInterval(0), WithBaseURLs(srv.URL, srv.URL)}, opts...)
	return NewClient(all...), srv, &hits
}

func TestClient_GetSendsUserAgent(t *testing.T) {
	var agent string
	c, srv, _ := testClient(t, func(w http.ResponseWriter, r *http.Request) {
		agent = r.UserAgent()
		_, _ = w.Write([]byte("ok"))
	})
	body, err := c.Get(context.Background(), srv.URL+"/rss/hutbeler")
	if err != nil || string(body) != "ok" {
		t.Fatalf("body=%q err=%v", body, err)
	}
	if agent != "vakit-api/1.0 (+https://ezanvakti.ekrembulbul.me)" {
		t.Fatalf("User-Agent = %q", agent)
	}
}

func TestClient_Non200IsError(t *testing.T) {
	c, srv, _ := testClient(t, func(w http.ResponseWriter, r *http.Request) { http.NotFound(w, r) })
	if _, err := c.Get(context.Background(), srv.URL+"/yok"); err == nil || !strings.Contains(err.Error(), "404") {
		t.Fatalf("err = %v", err)
	}
}

func TestClient_RefusesDisallowedURLsWithoutRequest(t *testing.T) {
	c, srv, hits := testClient(t, func(w http.ResponseWriter, r *http.Request) { _, _ = w.Write([]byte("ok")) })
	for _, u := range []string{srv.URL + "/kategoriler/x", srv.URL + "/Kategoriler/Hutbeler", "http://example.invalid/x"} {
		if _, err := c.Get(context.Background(), u); err == nil {
			t.Errorf("%s: expected error", u)
		}
	}
	if hits.Load() != 0 {
		t.Fatalf("server hit %d times", hits.Load())
	}
}

func TestClient_BodyLimit(t *testing.T) {
	c, srv, _ := testClient(t, func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(strings.Repeat("a", maxBodyBytes+1)))
	})
	if _, err := c.Get(context.Background(), srv.URL+"/buyuk"); err == nil {
		t.Fatal("expected size error")
	}
}

func TestClient_WaitsBetweenRequests(t *testing.T) {
	c, srv, _ := testClient(t, func(w http.ResponseWriter, r *http.Request) { _, _ = w.Write([]byte("ok")) },
		WithInterval(60*time.Millisecond))
	start := time.Now()
	for range 3 {
		if _, err := c.Get(context.Background(), srv.URL+"/x"); err != nil {
			t.Fatal(err)
		}
	}
	if elapsed := time.Since(start); elapsed < 120*time.Millisecond {
		t.Fatalf("3 requests took %v; interval not applied", elapsed)
	}
}

func TestClient_RebasesLinksOntoConfiguredSites(t *testing.T) {
	c := NewClient(WithBaseURLs("http://dh.test/", "http://din.test"))
	if c.FeedURL() != "http://dh.test/rss/hutbeler" || c.HomeURL() != "http://din.test/" || c.DinHizmetleriBase() != "http://din.test" {
		t.Fatalf("feed=%q home=%q base=%q", c.FeedURL(), c.HomeURL(), c.DinHizmetleriBase())
	}
	got, err := c.ArticleURL("https://www.diyanethaber.com.tr/25-eylul-2026-cuma-hutbesi")
	if err != nil || got != "http://dh.test/25-eylul-2026-cuma-hutbesi" {
		t.Fatalf("article = %q err=%v", got, err)
	}
	got, err = c.DetailURL("https://dinhizmetleri.diyanet.gov.tr/Detay/1318/25092026-cuma-hutbesi-tebliğ-(türkçe)")
	if err != nil || got != "http://din.test/Detay/1318/25092026-cuma-hutbesi-tebli%C4%9F-%28t%C3%BCrk%C3%A7e%29" {
		t.Fatalf("detail = %q err=%v", got, err)
	}
	for _, bad := range []string{"", "mailto:x@y", "https://dinhizmetleri.diyanet.gov.tr/kategoriler/x"} {
		if _, err := c.DetailURL(bad); err == nil {
			t.Errorf("DetailURL(%q) should fail", bad)
		}
	}
	if _, err := c.ArticleURL("javascript:alert(1)"); err == nil {
		t.Error("ArticleURL should reject non-http link")
	}
}
