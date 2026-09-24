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
	var out struct {
		DayOfYear int `json:"dayOfYear"`
	}
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
