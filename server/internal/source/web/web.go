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
	// Aynı ilçe sayfası art arda farklı yıllar için istenir; son sayfa bir kez indirilir.
	lastPageCity int
	lastPageDays []model.Day
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
	all, err := s.cityPageDays(ctx, cityID)
	if err != nil {
		return nil, err
	}
	byDate := make(map[string]model.Day)
	yearPrefix := strconv.Itoa(year)
	for _, d := range all {
		if len(d.Date) >= 4 && d.Date[:4] == yearPrefix {
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

// cityPageDays ilçe sayfasındaki tüm tablo günlerini döner; son ilçe hafızadan gelir.
func (s *Source) cityPageDays(ctx context.Context, cityID int) ([]model.Day, error) {
	s.mu.Lock()
	if s.lastPageCity == cityID && s.lastPageDays != nil {
		days := s.lastPageDays
		s.mu.Unlock()
		return days, nil
	}
	s.mu.Unlock()
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
	s.mu.Lock()
	s.lastPageCity, s.lastPageDays = cityID, all
	s.mu.Unlock()
	return all, nil
}
