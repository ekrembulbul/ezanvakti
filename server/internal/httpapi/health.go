package httpapi

import (
	"encoding/json"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"time"

	"vakit/internal/store"
)

type yearHealth struct {
	Cities    int       `json:"cities"`
	Complete  bool      `json:"complete"`
	UpdatedAt time.Time `json:"updatedAt"`
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
	state, err := h.st.LoadState()
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
	_ = json.NewEncoder(w).Encode(buildHealth(state, h.opts, time.Now()))
}
