package sermon

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"
)

const (
	DefaultDiyanetHaberURL  = "https://www.diyanethaber.com.tr"
	DefaultDinHizmetleriURL = "https://dinhizmetleri.diyanet.gov.tr"
	feedPath                = "/rss/hutbeler"
	// Din Hizmetleri'ne kim olduğumuzu ve nereden ulaşılacağını söyleriz.
	userAgent       = "vakit-api/1.0 (+https://ezanvakti.ekrembulbul.me)"
	defaultTimeout  = 30 * time.Second
	defaultInterval = time.Second
	maxBodyBytes    = 4 << 20
	// robots.txt (Din Hizmetleri) /kategoriler/'i kapatıyor; hiç istenmez.
	disallowedPath = "/kategoriler"
)

var ErrDisallowed = errors.New("sermon: url is not allowed")

// Client, Diyanet Haber ve Din Hizmetleri sitelerine sıralı, aralıklı GET atar. Yalnız
// yapılandırılmış iki siteye istek atar; sayfalardaki bağlantılar bu sitelere taşınarak çekilir.
type Client struct {
	http          *http.Client
	interval      time.Duration
	diyanetHaber  string
	dinHizmetleri string

	mu       sync.Mutex
	lastCall time.Time
}

type Option func(*Client)

func WithHTTPClient(h *http.Client) Option { return func(c *Client) { c.http = h } }
func WithInterval(d time.Duration) Option  { return func(c *Client) { c.interval = d } }
func WithBaseURLs(diyanetHaber, dinHizmetleri string) Option {
	return func(c *Client) {
		c.diyanetHaber = strings.TrimRight(diyanetHaber, "/")
		c.dinHizmetleri = strings.TrimRight(dinHizmetleri, "/")
	}
}

func NewClient(opts ...Option) *Client {
	c := &Client{
		http: &http.Client{Timeout: defaultTimeout, CheckRedirect: func(req *http.Request, via []*http.Request) error {
			if len(via) >= 10 {
				return errors.New("sermon: too many redirects")
			}
			if isDisallowedPath(req.URL.Path) {
				return fmt.Errorf("%w: redirect to %s", ErrDisallowed, req.URL.Path)
			}
			return nil
		}},
		interval:      defaultInterval,
		diyanetHaber:  DefaultDiyanetHaberURL,
		dinHizmetleri: DefaultDinHizmetleriURL,
	}
	for _, o := range opts {
		o(c)
	}
	return c
}

func (c *Client) FeedURL() string           { return c.diyanetHaber + feedPath }
func (c *Client) HomeURL() string           { return c.dinHizmetleri + "/" }
func (c *Client) DinHizmetleriBase() string { return c.dinHizmetleri }

// ArticleURL, RSS'teki hutbe bağlantısının yolunu Diyanet Haber sitesine taşır.
func (c *Client) ArticleURL(link string) (string, error) {
	u, err := url.Parse(strings.TrimSpace(link))
	if err != nil || (u.Scheme != "" && u.Scheme != "http" && u.Scheme != "https") || u.Path == "" || u.Path == "/" {
		return "", fmt.Errorf("sermon: bad article link %q", link)
	}
	out := c.diyanetHaber + u.EscapedPath()
	if u.RawQuery != "" {
		out += "?" + u.RawQuery
	}
	return out, nil
}

// DetailURL, Din Hizmetleri ana sayfasındaki /Detay/{id}/{slug} bağlantısını kodlanmış
// yoluyla Din Hizmetleri sitesine taşır.
func (c *Client) DetailURL(link string) (string, error) {
	m := detailLinkPattern.FindStringSubmatch(link)
	if m == nil || isDisallowedPath(link) {
		return "", fmt.Errorf("sermon: bad detail link %q", link)
	}
	return c.dinHizmetleri + "/Detay/" + m[1] + "/" + url.PathEscape(unescapePath(m[2])), nil
}

// Get, rawURL'i çeker: User-Agent kimliği, istekler arası en az interval bekleme, 30 sn
// zaman aşımı, 4 MB gövde sınırı; 200 dışı yanıt hatadır. Yapılandırılmış iki site dışındaki
// ve /kategoriler/ altındaki adresler istek atılmadan reddedilir.
func (c *Client) Get(ctx context.Context, rawURL string) ([]byte, error) {
	if err := c.allowed(rawURL); err != nil {
		return nil, err
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if wait := c.interval - time.Since(c.lastCall); wait > 0 && !c.lastCall.IsZero() {
		select {
		case <-time.After(wait):
		case <-ctx.Done():
			return nil, ctx.Err()
		}
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, rawURL, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", userAgent)
	req.Header.Set("Accept-Language", "tr-TR,tr;q=0.9")
	c.lastCall = time.Now()
	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("sermon: GET %s: %w", rawURL, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("sermon: GET %s: HTTP %d", rawURL, resp.StatusCode)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, maxBodyBytes+1))
	if err != nil {
		return nil, fmt.Errorf("sermon: GET %s: read: %w", rawURL, err)
	}
	if len(body) > maxBodyBytes {
		return nil, fmt.Errorf("sermon: GET %s: body exceeds %d bytes", rawURL, maxBodyBytes)
	}
	return body, nil
}

func (c *Client) allowed(rawURL string) error {
	u, err := url.Parse(rawURL)
	if err != nil {
		return fmt.Errorf("%w: %q", ErrDisallowed, rawURL)
	}
	if isDisallowedPath(u.Path) {
		return fmt.Errorf("%w: %s (robots.txt)", ErrDisallowed, u.Path)
	}
	for _, base := range []string{c.diyanetHaber, c.dinHizmetleri} {
		if rawURL == base || strings.HasPrefix(rawURL, base+"/") || strings.HasPrefix(rawURL, base+"?") {
			return nil
		}
	}
	return fmt.Errorf("%w: %s is not a configured site", ErrDisallowed, rawURL)
}

func isDisallowedPath(p string) bool {
	return strings.Contains(strings.ToLower(unescapePath(p)), disallowedPath)
}
