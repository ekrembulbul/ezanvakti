package jobs

import (
	"context"
	"errors"
	"fmt"
	"time"

	"vakit/internal/model"
	"vakit/internal/source"
	"vakit/internal/store"
)

// DailyContent bugün + ahead gün için günün ayet/hadis/duasını çeker; var olan günü atlar.
func DailyContent(ctx context.Context, d Deps, ahead int) (Result, error) {
	var res Result
	today := d.Now().UTC().Truncate(24 * time.Hour)
	for i := 0; i <= ahead; i++ {
		day := today.AddDate(0, 0, i)
		path := store.DailyContentPath(day)
		if d.Store.Exists(path) {
			res.Skipped++
			continue
		}
		content, err := d.Source.DailyContent(ctx, day)
		if errors.Is(err, source.ErrUnsupported) {
			res.Skipped++
			continue
		}
		if err != nil {
			if stopOnQuota(err, &res) {
				return res, fmt.Errorf("daily-content %s: %w", day.Format(model.DateLayout), err)
			}
			res.Errors++
			d.Logger.Warn("daily-content fetch failed", "date", day.Format(model.DateLayout), "err", err.Error())
			continue
		}
		res.Fetched++
		if content == nil || content.Verse == "" {
			d.Logger.Warn("daily-content empty; not written", "date", day.Format(model.DateLayout))
			continue
		}
		content.Date = day.Format(model.DateLayout)
		if err := d.Store.WriteJSON(path, content); err != nil {
			return res, err
		}
		res.Written++
	}
	if res.Written > 0 {
		d.State.DailyContent.UpdatedAt = d.Now()
	}
	d.State.DailyContent.Days += res.Written
	d.Logger.Info("sync daily-content done", "result", res.String())
	return res, nil
}
