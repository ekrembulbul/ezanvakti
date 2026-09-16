package store

import (
	"errors"
	"io/fs"
	"time"
)

// SyncState, sync işlerinin ilerlemesini tutar; health bu dosyadan üretilir.
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

func newSyncState() *SyncState {
	return &SyncState{
		PrayerTimes:   map[string]CityYearState{},
		ReligiousDays: map[string]time.Time{},
	}
}

// LoadState dosya yoksa boş durum döner; bozuk dosya hatadır (sessizce sıfırlanmaz).
func (s *Store) LoadState() (*SyncState, error) {
	st := newSyncState()
	err := s.ReadJSON(StatePath(), st)
	if errors.Is(err, fs.ErrNotExist) {
		return newSyncState(), nil
	}
	if err != nil {
		return nil, err
	}
	if st.PrayerTimes == nil {
		st.PrayerTimes = map[string]CityYearState{}
	}
	if st.ReligiousDays == nil {
		st.ReligiousDays = map[string]time.Time{}
	}
	return st, nil
}

func (s *Store) SaveState(st *SyncState) error { return s.WriteJSON(StatePath(), st) }
