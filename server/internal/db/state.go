package db

import (
	"database/sql"
	"fmt"
	"strconv"
	"strings"
	"time"

	"vakit/internal/store"
)

const timeLayout = time.RFC3339Nano

func formatTime(t time.Time) string {
	if t.IsZero() {
		return ""
	}
	return t.UTC().Format(timeLayout)
}

func parseTime(s string) time.Time {
	if s == "" {
		return time.Time{}
	}
	t, err := time.Parse(timeLayout, s)
	if err != nil {
		return time.Time{}
	}
	return t
}

// LoadSyncState tabloları store.SyncState'e okur; boş veritabanı boş durum döner.
func (d *DB) LoadSyncState() (*store.SyncState, error) {
	st := store.NewSyncState()
	rows, err := d.sql.Query(`SELECT city_id, year, last_fetched_at, horizon, complete, days, note FROM sync_city_year`)
	if err != nil {
		return nil, fmt.Errorf("db: load city years: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var cityID, year, complete, days int
		var fetched, horizon, note string
		if err := rows.Scan(&cityID, &year, &fetched, &horizon, &complete, &days, &note); err != nil {
			return nil, err
		}
		st.PrayerTimes[store.CityYearKey(cityID, year)] = store.CityYearState{
			LastFetchedAt: parseTime(fetched), Horizon: horizon, Complete: complete == 1, Days: days, Note: note}
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	var updated, enabled string
	err = d.sql.QueryRow(`SELECT updated_at, countries, cities, enabled_countries FROM sync_places WHERE id = 1`).
		Scan(&updated, &st.Places.Countries, &st.Places.Cities, &enabled)
	if err != nil && err != sql.ErrNoRows {
		return nil, fmt.Errorf("db: load places: %w", err)
	}
	st.Places.UpdatedAt = parseTime(updated)
	st.Places.EnabledCountries = parseIntList(enabled)
	rdRows, err := d.sql.Query(`SELECT year, updated_at FROM sync_religious_days`)
	if err != nil {
		return nil, fmt.Errorf("db: load religious days: %w", err)
	}
	defer rdRows.Close()
	for rdRows.Next() {
		var year int
		var at string
		if err := rdRows.Scan(&year, &at); err != nil {
			return nil, err
		}
		st.ReligiousDays[strconv.Itoa(year)] = parseTime(at)
	}
	var dcUpdated string
	err = d.sql.QueryRow(`SELECT updated_at, days FROM sync_daily_content WHERE id = 1`).Scan(&dcUpdated, &st.DailyContent.Days)
	if err != nil && err != sql.ErrNoRows {
		return nil, fmt.Errorf("db: load daily content: %w", err)
	}
	st.DailyContent.UpdatedAt = parseTime(dcUpdated)
	err = d.sql.QueryRow(`SELECT value FROM sync_counters WHERE name = 'rejected'`).Scan(&st.Rejected)
	if err != nil && err != sql.ErrNoRows {
		return nil, fmt.Errorf("db: load counters: %w", err)
	}
	return st, nil
}

// SaveSyncState durumun tamamını tek transaction'da yazar; bellekte olmayan satırlar silinir.
func (d *DB) SaveSyncState(st *store.SyncState) error {
	tx, err := d.sql.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err := tx.Exec(`DELETE FROM sync_city_year`); err != nil {
		return err
	}
	for key, cy := range st.PrayerTimes {
		cityStr, yearStr, ok := strings.Cut(key, "/")
		if !ok {
			continue
		}
		cityID, err1 := strconv.Atoi(cityStr)
		year, err2 := strconv.Atoi(yearStr)
		if err1 != nil || err2 != nil {
			continue
		}
		if _, err := tx.Exec(`INSERT INTO sync_city_year (city_id, year, last_fetched_at, horizon, complete, days, note)
			VALUES (?, ?, ?, ?, ?, ?, ?)`, cityID, year, formatTime(cy.LastFetchedAt), cy.Horizon, boolInt(cy.Complete), cy.Days, cy.Note); err != nil {
			return fmt.Errorf("db: save city year %s: %w", key, err)
		}
	}
	if _, err := tx.Exec(`INSERT INTO sync_places (id, updated_at, countries, cities, enabled_countries) VALUES (1, ?, ?, ?, ?)
		ON CONFLICT(id) DO UPDATE SET updated_at = excluded.updated_at, countries = excluded.countries,
		cities = excluded.cities, enabled_countries = excluded.enabled_countries`,
		formatTime(st.Places.UpdatedAt), st.Places.Countries, st.Places.Cities, formatIntList(st.Places.EnabledCountries)); err != nil {
		return fmt.Errorf("db: save places: %w", err)
	}
	if _, err := tx.Exec(`DELETE FROM sync_religious_days`); err != nil {
		return err
	}
	for yearStr, at := range st.ReligiousDays {
		year, err := strconv.Atoi(yearStr)
		if err != nil {
			continue
		}
		if _, err := tx.Exec(`INSERT INTO sync_religious_days (year, updated_at) VALUES (?, ?)`, year, formatTime(at)); err != nil {
			return fmt.Errorf("db: save religious days %d: %w", year, err)
		}
	}
	if _, err := tx.Exec(`INSERT INTO sync_daily_content (id, updated_at, days) VALUES (1, ?, ?)
		ON CONFLICT(id) DO UPDATE SET updated_at = excluded.updated_at, days = excluded.days`,
		formatTime(st.DailyContent.UpdatedAt), st.DailyContent.Days); err != nil {
		return fmt.Errorf("db: save daily content: %w", err)
	}
	if _, err := tx.Exec(`INSERT INTO sync_counters (name, value) VALUES ('rejected', ?)
		ON CONFLICT(name) DO UPDATE SET value = excluded.value`, st.Rejected); err != nil {
		return fmt.Errorf("db: save counters: %w", err)
	}
	return tx.Commit()
}

func boolInt(b bool) int {
	if b {
		return 1
	}
	return 0
}

func formatIntList(ids []int) string {
	parts := make([]string, len(ids))
	for i, id := range ids {
		parts[i] = strconv.Itoa(id)
	}
	return strings.Join(parts, ",")
}

func parseIntList(s string) []int {
	if s == "" {
		return nil
	}
	var out []int
	for _, p := range strings.Split(s, ",") {
		if n, err := strconv.Atoi(strings.TrimSpace(p)); err == nil {
			out = append(out, n)
		}
	}
	return out
}
