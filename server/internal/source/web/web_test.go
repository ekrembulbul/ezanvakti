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

func TestPrayerTimes_SameCityTwoYearsDownloadsPageOnce(t *testing.T) {
	s, agents := newSource(t)
	if _, err := s.PrayerTimes(context.Background(), 9541, 2026); err != nil {
		t.Fatal(err)
	}
	if _, err := s.PrayerTimes(context.Background(), 9541, 2027); err != nil {
		t.Fatal(err)
	}
	if len(*agents) != 1 {
		t.Fatalf("expected a single page download, got %d", len(*agents))
	}
}
