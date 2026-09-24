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

func WithHTTPClient(h *http.Client) Option         { return func(c *Client) { c.http = h } }
func WithInterval(d time.Duration) Option          { return func(c *Client) { c.interval = d } }
func WithBackoff(f func(int) time.Duration) Option { return func(c *Client) { c.backoff = f } }
func WithClock(now func() time.Time) Option        { return func(c *Client) { c.now = now } }

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
		err := c.refreshLocked(ctx)
		if err == nil {
			return nil
		}
		c.logger.Warn("awqat refresh failed; logging in", "err", err.Error())
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
