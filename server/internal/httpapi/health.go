package httpapi

import (
	"encoding/json"
	"errors"
	"io/fs"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"time"

	"vakit/internal/sermon"
	"vakit/internal/store"
)

type yearHealth struct {
	Cities    int       `json:"cities"`
	Complete  bool      `json:"complete"`
	UpdatedAt time.Time `json:"updatedAt"`
}

// sermonsHealth, yayımlanan hutbe dizininden türetilir (sync durumu tablosunda tutulmaz).
type sermonsHealth struct {
	UpdatedAt time.Time `json:"updatedAt"`
	Count     int       `json:"count"`
}

type healthResponse struct {
	Status        string `json:"status"`
	Version       string `json:"version"`
	UptimeSeconds int64  `json:"uptimeSeconds"`
	Datasets      struct {
		Places        store.PlacesState     `json:"places"`
		PrayerTimes   map[string]yearHealth `json:"prayerTimes"`
		ReligiousDays struct {
			Years     []int     `json:"years"`
			UpdatedAt time.Time `json:"updatedAt"`
		} `json:"religiousDays"`
		DailyContent store.DailyContentState `json:"dailyContent"`
		Sermons      sermonsHealth           `json:"sermons"`
		Rejected     int                     `json:"rejected"`
	} `json:"datasets"`
}

func buildHealth(state *store.SyncState, opts Options, now time.Time) healthResponse {
	resp := healthResponse{Status: "ok", Version: opts.Version, UptimeSeconds: int64(now.Sub(opts.StartedAt).Seconds())}
	resp.Datasets.Places = state.Places
	resp.Datasets.DailyContent = state.DailyContent
	resp.Datasets.Rejected = state.Rejected
	years := map[string]*yearHealth{}
	for key, cy := range state.PrayerTimes {
		_, yearStr, ok := strings.Cut(key, "/")
		if !ok {
			continue
		}
		yh, exists := years[yearStr]
		if !exists {
			yh = &yearHealth{Complete: true}
			years[yearStr] = yh
		}
		yh.Cities++
		yh.Complete = yh.Complete && cy.Complete
		if cy.LastFetchedAt.After(yh.UpdatedAt) {
			yh.UpdatedAt = cy.LastFetchedAt
		}
	}
	resp.Datasets.PrayerTimes = make(map[string]yearHealth, len(years))
	for y, yh := range years {
		resp.Datasets.PrayerTimes[y] = *yh
	}
	for y, at := range state.ReligiousDays {
		if n, err := strconv.Atoi(y); err == nil {
			resp.Datasets.ReligiousDays.Years = append(resp.Datasets.ReligiousDays.Years, n)
		}
		if at.After(resp.Datasets.ReligiousDays.UpdatedAt) {
			resp.Datasets.ReligiousDays.UpdatedAt = at
		}
	}
	sort.Ints(resp.Datasets.ReligiousDays.Years)
	return resp
}

func (h *handler) health(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet && r.Method != http.MethodHead {
		w.Header().Set("Allow", "GET, HEAD")
		writeError(w, errMethod)
		return
	}
	state, err := h.states.LoadSyncState()
	if err != nil {
		h.logger.Error("health: state unreadable", "err", err.Error())
		writeError(w, errInternal)
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(http.StatusOK)
	if r.Method == http.MethodHead {
		return
	}
	resp := buildHealth(state, h.opts, time.Now())
	resp.Datasets.Sermons = h.sermonsHealth()
	_ = json.NewEncoder(w).Encode(resp)
}

// sermonsHealth: son başarılı hutbe çekiminin zamanı ve yayımlanan hutbe sayısı; dizin henüz
// yoksa sıfır değerler.
func (h *handler) sermonsHealth() sermonsHealth {
	var idx sermon.Index
	if err := h.st.ReadJSON(store.SermonIndexPath(), &idx); err != nil {
		if !errors.Is(err, fs.ErrNotExist) {
			h.logger.Warn("health: sermon index unreadable", "err", err.Error())
		}
		return sermonsHealth{}
	}
	return sermonsHealth{UpdatedAt: idx.UpdatedAt, Count: len(idx.Sermons)}
}
