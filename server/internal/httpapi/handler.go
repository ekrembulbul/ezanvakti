// Package httpapi, data/ dizinindeki yayın dosyalarını /v1 sözleşmesiyle sunar.
// Yol parametreleri sayı/tarih olarak ayrıştırılır; dosya yolu bu değerlerden
// üretilir, kullanıcı girdisi dosya sistemine ham geçmez.
package httpapi

import (
	"errors"
	"io/fs"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"time"

	"vakit/internal/model"
	"vakit/internal/store"
)

const (
	cacheDaily  = "public, max-age=86400, stale-while-revalidate=604800"
	cacheWeekly = "public, max-age=604800, stale-while-revalidate=604800"
	minYear     = 2000
	maxYear     = 2100
)

type Options struct {
	Version   string
	StartedAt time.Time
}

// StateLoader, health için sync durumunu sağlar (internal/db uygular).
type StateLoader interface {
	LoadSyncState() (*store.SyncState, error)
}

type handler struct {
	st     *store.Store
	states StateLoader
	opts   Options
	logger *slog.Logger
}

type resolver func(r *http.Request) (rel string, err *apiError)

func NewHandler(st *store.Store, states StateLoader, opts Options, logger *slog.Logger) http.Handler {
	h := &handler{st: st, states: states, opts: opts, logger: logger}
	mux := http.NewServeMux()
	mux.HandleFunc("/v1/places/countries", h.file(cacheWeekly, func(*http.Request) (string, *apiError) {
		return store.CountriesPath(), nil
	}))
	mux.HandleFunc("/v1/places/countries/{countryId}/states", h.file(cacheWeekly, func(r *http.Request) (string, *apiError) {
		id, err := pathID(r, "countryId")
		if err != nil {
			return "", err
		}
		return store.StatesPath(id), nil
	}))
	mux.HandleFunc("/v1/places/states/{stateId}/cities", h.file(cacheWeekly, func(r *http.Request) (string, *apiError) {
		id, err := pathID(r, "stateId")
		if err != nil {
			return "", err
		}
		return store.CitiesPath(id), nil
	}))
	mux.HandleFunc("/v1/places/tr/cities", h.file(cacheWeekly, func(*http.Request) (string, *apiError) {
		return store.TRCitiesPath(), nil
	}))
	mux.HandleFunc("/v1/prayer-times/{cityId}/{year}", h.file(cacheDaily, func(r *http.Request) (string, *apiError) {
		id, err := pathID(r, "cityId")
		if err != nil {
			return "", err
		}
		year, err := pathYear(r)
		if err != nil {
			return "", err
		}
		return store.PrayerTimesPath(id, year), nil
	}))
	mux.HandleFunc("/v1/religious-days/{year}", h.file(cacheDaily, func(r *http.Request) (string, *apiError) {
		year, err := pathYear(r)
		if err != nil {
			return "", err
		}
		return store.ReligiousDaysPath(year), nil
	}))
	mux.HandleFunc("/v1/daily-content/{date}", h.file(cacheDaily, func(r *http.Request) (string, *apiError) {
		t, err := time.Parse(model.DateLayout, r.PathValue("date"))
		if err != nil {
			return "", errInvalidParam("date must be YYYY-MM-DD")
		}
		return store.DailyContentPath(t), nil
	}))
	mux.HandleFunc("/v1/health", h.health)
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) { writeError(w, errNotFound) })
	return accessLog(logger, mux)
}

func pathID(r *http.Request, name string) (int, *apiError) {
	n, err := strconv.Atoi(r.PathValue(name))
	if err != nil || n <= 0 {
		return 0, errInvalidParam(name + " must be a positive integer")
	}
	return n, nil
}

func pathYear(r *http.Request) (int, *apiError) {
	n, err := strconv.Atoi(r.PathValue("year"))
	if err != nil || n < minYear || n > maxYear {
		return 0, errInvalidParam("year must be between 2000 and 2100")
	}
	return n, nil
}

func (h *handler) file(cacheControl string, resolve resolver) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet && r.Method != http.MethodHead {
			w.Header().Set("Allow", "GET, HEAD")
			writeError(w, errMethod)
			return
		}
		rel, aerr := resolve(r)
		if aerr != nil {
			writeError(w, aerr)
			return
		}
		data, etag, err := h.st.Read(rel)
		if errors.Is(err, fs.ErrNotExist) {
			writeError(w, errNotFound)
			return
		}
		if err != nil {
			h.logger.Error("store read failed", "path", rel, "err", err.Error())
			writeError(w, errInternal)
			return
		}
		hdr := w.Header()
		hdr.Set("Content-Type", "application/json; charset=utf-8")
		hdr.Set("ETag", etag)
		hdr.Set("Cache-Control", cacheControl)
		if etagMatches(r.Header.Get("If-None-Match"), etag) {
			w.WriteHeader(http.StatusNotModified)
			return
		}
		hdr.Set("Content-Length", strconv.Itoa(len(data)))
		w.WriteHeader(http.StatusOK)
		if r.Method == http.MethodHead {
			return
		}
		_, _ = w.Write(data)
	}
}

// etagMatches, If-None-Match listesindeki (zayıf öneki yok sayılarak) herhangi bir değer
// ya da "*" ile eşleşirse true döner.
func etagMatches(ifNoneMatch, etag string) bool {
	if strings.TrimSpace(ifNoneMatch) == "" {
		return false
	}
	for _, candidate := range strings.Split(ifNoneMatch, ",") {
		candidate = strings.TrimSpace(candidate)
		candidate = strings.TrimPrefix(candidate, "W/")
		if candidate == "*" || candidate == etag {
			return true
		}
	}
	return false
}
