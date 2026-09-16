package jobs

import (
	"context"
	"errors"
	"fmt"
	"strconv"

	"vakit/internal/source"
	"vakit/internal/store"
	"vakit/internal/validate"
)

func ReligiousDays(ctx context.Context, d Deps, years []int) (Result, error) {
	var res Result
	for _, year := range years {
		list, err := d.Source.ReligiousDays(ctx, year)
		if errors.Is(err, source.ErrUnsupported) {
			res.Skipped++
			d.Logger.Warn("religious-days: source does not provide religious days; skipping", "source", d.Source.Name(), "year", year)
			continue
		}
		if err != nil {
			if stopOnQuota(err, &res) {
				return res, fmt.Errorf("religious-days %d: %w", year, err)
			}
			res.Errors++
			d.Logger.Warn("religious-days fetch failed", "year", year, "err", err.Error())
			continue
		}
		res.Fetched++
		if verr := validate.ReligiousDays(list, year); verr != nil {
			res.Rejected++
			d.State.Rejected++
			d.Logger.Warn("religious-days rejected by validation", "year", year, "problem", verr.Error())
			continue
		}
		if err := d.Store.WriteJSON(store.ReligiousDaysPath(year), list); err != nil {
			return res, err
		}
		res.Written++
		d.State.ReligiousDays[strconv.Itoa(year)] = d.Now()
	}
	d.Logger.Info("sync religious-days done", "result", res.String())
	return res, nil
}
