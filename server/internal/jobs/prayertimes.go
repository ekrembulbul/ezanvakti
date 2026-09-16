package jobs

import (
	"context"
	"errors"
	"fmt"
	"io/fs"
	"sort"
	"time"

	"vakit/internal/model"
	"vakit/internal/store"
	"vakit/internal/validate"
)

const (
	// Tamamlanmamış yıl (web modunda kayan pencere, API modunda henüz yayınlanmamış günler)
	// en erken bir hafta sonra yeniden çekilir: DateRange yer bazında ayda 10 istekle sınırlı.
	RefetchIncompleteAfter = 7 * 24 * time.Hour
	MaxConsecutiveErrors   = 3
)

// PrayerTimes: enabled ilçeler × yıllar için eksik veriyi çeker, mevcut dosyayla birleştirir,
// doğrular ve yazar. batch kadar çekimden sonra durur.
func PrayerTimes(ctx context.Context, d Deps, cityIDs []int, years []int, batch int) (Result, error) {
	var res Result
	consecutiveErrors := 0
	for _, year := range years {
		for _, cityID := range cityIDs {
			if res.Fetched >= batch {
				res.Stopped = "batch"
				d.Logger.Info("sync prayer-times batch limit reached", "batch", batch)
				return res, nil
			}
			key := store.CityYearKey(cityID, year)
			existing, _, err := readExisting(d.Store, cityID, year)
			if err != nil {
				return res, err
			}
			if !needsFetch(d.State.PrayerTimes[key], d.Now()) {
				res.Skipped++
				continue
			}
			res.Fetched++
			fetched, err := d.Source.PrayerTimes(ctx, cityID, year)
			if err != nil {
				if stopOnQuota(err, &res) {
					return res, fmt.Errorf("prayer-times %s: %w", key, err)
				}
				res.Errors++
				consecutiveErrors++
				d.Logger.Warn("prayer-times fetch failed", "city", cityID, "year", year, "err", err.Error())
				if consecutiveErrors >= MaxConsecutiveErrors {
					res.Stopped = "errors"
					return res, fmt.Errorf("prayer-times: %d consecutive source errors, last: %w", consecutiveErrors, err)
				}
				continue
			}
			consecutiveErrors = 0
			if len(fetched) == 0 {
				st := d.State.PrayerTimes[key]
				st.LastFetchedAt, st.Note = d.Now(), "no data"
				d.State.PrayerTimes[key] = st
				d.Logger.Info("prayer-times: source has no data yet", "city", cityID, "year", year)
				continue
			}
			merged := mergeDays(existing.Days, fetched)
			prev, _, err := readExisting(d.Store, cityID, year-1)
			if err != nil {
				return res, err
			}
			if verr := validate.YearTimes(merged, year, prev.Days); verr != nil {
				res.Rejected++
				d.State.Rejected++
				d.Logger.Warn("prayer-times rejected by validation", "city", cityID, "year", year, "problem", verr.Error())
				continue
			}
			yt := model.YearTimes{
				SchemaVersion: model.SchemaVersion, Source: model.SourceDiyanet, GeneratedAt: d.Now(),
				CityID: cityID, Year: year, Complete: validate.IsComplete(merged, year), Days: merged,
			}
			if d.Source.Name() == model.ViaWeb {
				yt.Via = model.ViaWeb
			}
			if err := d.Store.WriteJSON(store.PrayerTimesPath(cityID, year), yt); err != nil {
				return res, err
			}
			res.Written++
			d.State.PrayerTimes[key] = store.CityYearState{LastFetchedAt: d.Now(), Horizon: merged[len(merged)-1].Date,
				Complete: yt.Complete, Days: len(merged)}
		}
	}
	d.Logger.Info("sync prayer-times done", "result", res.String())
	return res, nil
}

func readExisting(st *store.Store, cityID, year int) (model.YearTimes, bool, error) {
	var yt model.YearTimes
	err := st.ReadJSON(store.PrayerTimesPath(cityID, year), &yt)
	if errors.Is(err, fs.ErrNotExist) {
		return model.YearTimes{}, false, nil
	}
	if err != nil {
		return model.YearTimes{}, false, fmt.Errorf("prayer-times: read %d/%d: %w", cityID, year, err)
	}
	return yt, true, nil
}

// needsFetch: tamamsa hayır; hiç denenmemişse evet; değilse son denemeden 7 gün geçtiyse evet
// ("no data" denemeleri de sayılır — yayınlanmamış yıl her gün sorgulanmaz).
func needsFetch(st store.CityYearState, now time.Time) bool {
	if st.Complete {
		return false
	}
	if st.LastFetchedAt.IsZero() {
		return true
	}
	return !now.Before(st.LastFetchedAt.Add(RefetchIncompleteAfter))
}

// mergeDays tarih bazında birleştirir; çekilen gün mevcut günün üstüne yazar; çıktı sıralı.
func mergeDays(existing, fetched []model.Day) []model.Day {
	byDate := make(map[string]model.Day, len(existing)+len(fetched))
	for _, d := range existing {
		byDate[d.Date] = d
	}
	for _, d := range fetched {
		byDate[d.Date] = d
	}
	out := make([]model.Day, 0, len(byDate))
	for _, d := range byDate {
		out = append(out, d)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Date < out[j].Date })
	return out
}
