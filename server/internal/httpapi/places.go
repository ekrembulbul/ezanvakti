package httpapi

import (
	"encoding/json"
	"errors"
	"math"
	"net/http"
	"strconv"

	"vakit/internal/placeindex"
)

const (
	searchCacheControl = "public, max-age=3600"
	maxQueryLength     = 64
	defaultSearchLimit = 10
	maxSearchLimit     = 25
	// Türkiye dışı koordinat: en yakın ilçe bu uzaklıktan ötedeyse kapsama yok.
	maxCoverageKm = 60.0
	// Gizlilik: koordinat ~100 m'ye yuvarlanır; ham değer saklanmaz, loglanmaz.
	coordinatePrecision = 1000.0
	notReadyRetryAfter  = "300"
)

var (
	errNoCoverage = &apiError{Status: http.StatusNotFound, Code: "NO_COVERAGE", Message: "no Diyanet district near these coordinates"}
	errNotReady   = &apiError{Status: http.StatusServiceUnavailable, Code: "NOT_READY", Message: "place list is not synced yet; retry later"}
)

func (h *handler) placeIndex(w http.ResponseWriter) (*placeindex.Index, bool) {
	idx, err := h.places.Get()
	if errors.Is(err, placeindex.ErrNotReady) {
		w.Header().Set("Retry-After", notReadyRetryAfter)
		writeError(w, errNotReady)
		return nil, false
	}
	if err != nil {
		h.logger.Error("place index unavailable", "err", err.Error())
		writeError(w, errInternal)
		return nil, false
	}
	return idx, true
}

func writeJSON(w http.ResponseWriter, cacheControl string, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", cacheControl)
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(v)
}

// GET /v1/places/search?q=&limit= — sorgu metni loglanmaz; sonuç Cloudflare'de sorguya göre cache'lenir.
func (h *handler) placesSearch(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet && r.Method != http.MethodHead {
		w.Header().Set("Allow", "GET, HEAD")
		writeError(w, errMethod)
		return
	}
	q := r.URL.Query().Get("q")
	if len(q) > maxQueryLength {
		writeError(w, errInvalidParam("q must be at most 64 characters"))
		return
	}
	limit := defaultSearchLimit
	if raw := r.URL.Query().Get("limit"); raw != "" {
		n, err := strconv.Atoi(raw)
		if err != nil || n < 1 || n > maxSearchLimit {
			writeError(w, errInvalidParam("limit must be between 1 and 25"))
			return
		}
		limit = n
	}
	idx, ok := h.placeIndex(w)
	if !ok {
		return
	}
	writeJSON(w, searchCacheControl, map[string]any{"query": q, "results": idx.Search(q, limit)})
}

// GET /v1/places/resolve?lat=&lon= — en yakın ilçe; koordinat yuvarlanır, yanıt cache'lenmez.
func (h *handler) placesResolve(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet && r.Method != http.MethodHead {
		w.Header().Set("Allow", "GET, HEAD")
		writeError(w, errMethod)
		return
	}
	lat, errLat := strconv.ParseFloat(r.URL.Query().Get("lat"), 64)
	lon, errLon := strconv.ParseFloat(r.URL.Query().Get("lon"), 64)
	if errLat != nil || errLon != nil || lat < -90 || lat > 90 || lon < -180 || lon > 180 {
		writeError(w, errInvalidParam("lat must be -90..90 and lon -180..180"))
		return
	}
	lat = math.Round(lat*coordinatePrecision) / coordinatePrecision
	lon = math.Round(lon*coordinatePrecision) / coordinatePrecision
	idx, ok := h.placeIndex(w)
	if !ok {
		return
	}
	match, km, found := idx.Nearest(lat, lon)
	if !found || km > maxCoverageKm {
		writeError(w, errNoCoverage)
		return
	}
	writeJSON(w, "no-store", map[string]any{"city": match, "distanceKm": math.Round(km*10) / 10})
}
