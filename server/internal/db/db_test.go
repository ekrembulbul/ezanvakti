package db

import (
	"path/filepath"
	"testing"
	"time"

	"vakit/internal/store"
)

func openTemp(t *testing.T) *DB {
	t.Helper()
	d, err := Open(filepath.Join(t.TempDir(), "state", "vakit.db"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = d.Close() })
	return d
}

func TestOpen_CreatesDirectoryAppliesMigrationsIdempotently(t *testing.T) {
	d := openTemp(t)
	v, err := d.SchemaVersion()
	if err != nil || v < 1 {
		t.Fatalf("version=%d err=%v", v, err)
	}
	if err := d.Migrate(); err != nil { // ikinci uygulama hata vermez, sürüm değişmez
		t.Fatal(err)
	}
	again, _ := d.SchemaVersion()
	if again != v {
		t.Fatalf("version changed on re-migrate: %d → %d", v, again)
	}
	var mode string
	if err := d.sql.QueryRow("PRAGMA journal_mode").Scan(&mode); err != nil || mode != "wal" {
		t.Fatalf("journal_mode=%q err=%v", mode, err)
	}
}

func TestSyncState_RoundTripAndEmptyDefault(t *testing.T) {
	d := openTemp(t)
	s, err := d.LoadSyncState()
	if err != nil || s == nil || s.PrayerTimes == nil || s.ReligiousDays == nil {
		t.Fatalf("empty state must load with maps initialised: %+v %v", s, err)
	}
	now := time.Date(2026, 9, 17, 3, 0, 0, 0, time.UTC)
	s.Places = store.PlacesState{UpdatedAt: now, Countries: 209, Cities: 869, EnabledCountries: []int{2, 1}}
	s.PrayerTimes[store.CityYearKey(9541, 2026)] = store.CityYearState{LastFetchedAt: now, Horizon: "2026-10-16", Days: 31}
	s.PrayerTimes[store.CityYearKey(9541, 2027)] = store.CityYearState{LastFetchedAt: now, Horizon: "2027-12-31", Days: 365, Complete: true}
	s.PrayerTimes[store.CityYearKey(1, 2028)] = store.CityYearState{LastFetchedAt: now, Note: "no data"}
	s.ReligiousDays["2026"] = now
	s.DailyContent = store.DailyContentState{UpdatedAt: now, Days: 8}
	s.Rejected = 3
	if err := d.SaveSyncState(s); err != nil {
		t.Fatal(err)
	}
	got, err := d.LoadSyncState()
	if err != nil {
		t.Fatal(err)
	}
	if got.Places.Cities != 869 || len(got.Places.EnabledCountries) != 2 || got.Places.EnabledCountries[1] != 1 || !got.Places.UpdatedAt.Equal(now) {
		t.Fatalf("places: %+v", got.Places)
	}
	if len(got.PrayerTimes) != 3 || !got.PrayerTimes["9541/2027"].Complete || got.PrayerTimes["9541/2026"].Horizon != "2026-10-16" ||
		got.PrayerTimes["1/2028"].Note != "no data" || !got.PrayerTimes["9541/2026"].LastFetchedAt.Equal(now) {
		t.Fatalf("prayer times: %+v", got.PrayerTimes)
	}
	if !got.ReligiousDays["2026"].Equal(now) || got.DailyContent.Days != 8 || got.Rejected != 3 {
		t.Fatalf("%+v %+v %d", got.ReligiousDays, got.DailyContent, got.Rejected)
	}
}

func TestSyncState_SaveOverwritesAndRemovesStaleRows(t *testing.T) {
	d := openTemp(t)
	s, _ := d.LoadSyncState()
	s.PrayerTimes["1/2026"] = store.CityYearState{Days: 1}
	s.PrayerTimes["2/2026"] = store.CityYearState{Days: 2}
	_ = d.SaveSyncState(s)
	delete(s.PrayerTimes, "2/2026")
	s.PrayerTimes["1/2026"] = store.CityYearState{Days: 10, Complete: true}
	if err := d.SaveSyncState(s); err != nil {
		t.Fatal(err)
	}
	got, _ := d.LoadSyncState()
	if len(got.PrayerTimes) != 1 || got.PrayerTimes["1/2026"].Days != 10 || !got.PrayerTimes["1/2026"].Complete {
		t.Fatalf("%+v", got.PrayerTimes)
	}
}

func TestOpen_RejectsUnwritableLocation(t *testing.T) {
	if _, err := Open("/proc/nonexistent/vakit.db"); err == nil {
		t.Fatal("expected error")
	}
}
