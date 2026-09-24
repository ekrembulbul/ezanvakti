package jobs

import (
	"context"
	"errors"
	"fmt"
	"io/fs"

	"vakit/internal/model"
	"vakit/internal/source"
	"vakit/internal/store"
)

const turkeyCountryID = 2

// Places: ülkeler → enabled ülkelerin illeri → ilçeler (+ eksikse kıble detayı, + koordinat) → dosyalar.
func Places(ctx context.Context, d Deps, enabled []int) (Result, error) {
	var res Result
	enabledSet := make(map[int]bool, len(enabled))
	for _, id := range enabled {
		enabledSet[id] = true
	}
	countries, err := d.Source.Countries(ctx)
	if err != nil {
		stopOnQuota(err, &res)
		return res, fmt.Errorf("places: countries: %w", err)
	}
	res.Fetched++
	for i := range countries {
		countries[i].Enabled = enabledSet[countries[i].ID]
	}
	if err := d.Store.WriteJSON(store.CountriesPath(), countries); err != nil {
		return res, err
	}
	res.Written++

	totalCities := 0
	var trCities []model.CityWithState
	for _, countryID := range enabled {
		states, err := d.Source.States(ctx, countryID)
		if err != nil {
			stopOnQuota(err, &res)
			return res, fmt.Errorf("places: states of %d: %w", countryID, err)
		}
		res.Fetched++
		if err := d.Store.WriteJSON(store.StatesPath(countryID), states); err != nil {
			return res, err
		}
		res.Written++
		for _, st := range states {
			cities, err := d.Source.Cities(ctx, st.ID)
			if err != nil {
				stopOnQuota(err, &res)
				return res, fmt.Errorf("places: cities of state %d: %w", st.ID, err)
			}
			res.Fetched++
			known := existingQibla(d.Store, st.ID)
			for i := range cities {
				c := &cities[i]
				c.StateID, c.CountryID = st.ID, countryID
				if p, ok := d.Geo[c.ID]; ok {
					lat, lon := p.Latitude, p.Longitude
					c.Latitude, c.Longitude = &lat, &lon
				}
				if err := fillQibla(ctx, d, c, known, &res); err != nil {
					return res, err
				}
				if countryID == turkeyCountryID {
					trCities = append(trCities, model.CityWithState{City: *c, StateName: st.Name})
				}
			}
			if err := d.Store.WriteJSON(store.CitiesPath(st.ID), cities); err != nil {
				return res, err
			}
			res.Written++
			totalCities += len(cities)
		}
	}
	if enabledSet[turkeyCountryID] {
		if err := d.Store.WriteJSON(store.TRCitiesPath(), trCities); err != nil {
			return res, err
		}
		res.Written++
	}
	d.State.Places = store.PlacesState{UpdatedAt: d.Now(), Countries: len(countries), Cities: totalCities, EnabledCountries: enabled}
	d.Logger.Info("sync places done", "countries", len(countries), "cities", totalCities, "result", res.String())
	return res, nil
}

// existingQibla, önceki çalıştırmada yazılmış ilçe dosyasındaki kıble bilgisini döner;
// böylece CityDetail yalnız eksik ilçeler için çağrılır.
func existingQibla(st *store.Store, stateID int) map[int]model.City {
	var prev []model.City
	if err := st.ReadJSON(store.CitiesPath(stateID), &prev); err != nil {
		return nil
	}
	out := make(map[int]model.City, len(prev))
	for _, c := range prev {
		if c.QiblaAngle != nil {
			out[c.ID] = c
		}
	}
	return out
}

func fillQibla(ctx context.Context, d Deps, c *model.City, known map[int]model.City, res *Result) error {
	if prev, ok := known[c.ID]; ok {
		c.QiblaAngle, c.QiblaAngleMagnetic, c.DistanceToKaaba = prev.QiblaAngle, prev.QiblaAngleMagnetic, prev.DistanceToKaaba
		res.Skipped++
		return nil
	}
	detail, err := d.Source.CityDetail(ctx, c.ID)
	switch {
	case errors.Is(err, source.ErrUnsupported):
		return nil
	case err != nil:
		if stopOnQuota(err, res) {
			return fmt.Errorf("places: city detail %d: %w", c.ID, err)
		}
		res.Errors++
		d.Logger.Warn("city detail failed; continuing without qibla", "city", c.ID, "err", err.Error())
		return nil
	}
	res.Fetched++
	c.QiblaAngle, c.QiblaAngleMagnetic, c.DistanceToKaaba = detail.QiblaAngle, detail.QiblaAngleMagnetic, detail.DistanceToKaaba
	return nil
}

// EnabledCityIDs, yazılmış yer dosyalarından enabled ülkelerin tüm ilçe kimliklerini toplar.
func EnabledCityIDs(st *store.Store, enabled []int) ([]int, error) {
	var ids []int
	for _, countryID := range enabled {
		var states []model.State
		if err := st.ReadJSON(store.StatesPath(countryID), &states); err != nil {
			if errors.Is(err, fs.ErrNotExist) {
				return nil, fmt.Errorf("sync: places for country %d not synced yet; run 'vakit sync places' first", countryID)
			}
			return nil, err
		}
		for _, s := range states {
			var cities []model.City
			if err := st.ReadJSON(store.CitiesPath(s.ID), &cities); err != nil {
				return nil, err
			}
			for _, c := range cities {
				ids = append(ids, c.ID)
			}
		}
	}
	return ids, nil
}
