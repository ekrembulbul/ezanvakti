// Package jobs, Diyanet kaynağından veri çekip doğrulayarak store'a yazan sync işlerini içerir (VAK.4).
// Her iş idempotent; ilerleme Deps.State üzerinden tutulur ve çağıran SaveState yapar.
package jobs

import (
	"errors"
	"fmt"
	"log/slog"
	"time"

	"vakit/internal/geo"
	"vakit/internal/source"
	"vakit/internal/store"
)

type Deps struct {
	Source source.Source
	Store  *store.Store
	State  *store.SyncState
	Logger *slog.Logger
	Now    func() time.Time
	Geo    geo.Index
}

type Result struct {
	Fetched  int
	Written  int
	Rejected int
	Skipped  int
	Errors   int
	Stopped  string // boş değilse çalıştırma erken bitti (kota, batch, ardışık hata)
}

func (r Result) String() string {
	return fmt.Sprintf("fetched=%d written=%d rejected=%d skipped=%d errors=%d stopped=%q",
		r.Fetched, r.Written, r.Rejected, r.Skipped, r.Errors, r.Stopped)
}

// stopOnQuota: kota hatasında çalıştırma biter; ertesi cron devam eder.
func stopOnQuota(err error, res *Result) bool {
	if errors.Is(err, source.ErrQuotaExceeded) {
		res.Stopped = "quota"
		return true
	}
	return false
}
