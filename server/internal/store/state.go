package store

import "time"

// SyncState, sync işlerinin ilerlemesini tutar; SQLite'ta saklanır (internal/db),
// health bundan üretilir.
type SyncState struct {
	Places        PlacesState              `json:"places"`
	PrayerTimes   map[string]CityYearState `json:"prayerTimes"`   // CityYearKey → durum
	ReligiousDays map[string]time.Time     `json:"religiousDays"` // yıl → updatedAt
	DailyContent  DailyContentState        `json:"dailyContent"`
	Rejected      int                      `json:"rejected"` // doğrulamadan geçmeyen yazım sayısı (kümülatif)
}

type PlacesState struct {
	UpdatedAt        time.Time `json:"updatedAt"`
	Countries        int       `json:"countries"`
	Cities           int       `json:"cities"`
	EnabledCountries []int     `json:"enabledCountries"`
}

type CityYearState struct {
	LastFetchedAt time.Time `json:"lastFetchedAt"`
	Horizon       string    `json:"horizon"` // dosyadaki son tarih (YYYY-MM-DD)
	Complete      bool      `json:"complete"`
	Days          int       `json:"days"`
	Note          string    `json:"note,omitempty"`
}

type DailyContentState struct {
	UpdatedAt time.Time `json:"updatedAt"`
	Days      int       `json:"days"`
}

func NewSyncState() *SyncState {
	return &SyncState{
		PrayerTimes:   map[string]CityYearState{},
		ReligiousDays: map[string]time.Time{},
	}
}
