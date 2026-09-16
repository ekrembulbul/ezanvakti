// Package source, veri kaynaklarının (resmî API, web sayfası) ortak arayüzüdür.
// Sync işleri yalnız bu arayüzü görür; kaynak env ile seçilir (K4).
package source

import (
	"context"
	"errors"
	"time"

	"vakit/internal/model"
)

var (
	ErrUnsupported   = errors.New("source: operation not supported by this source")
	ErrQuotaExceeded = errors.New("source: quota exceeded")
)

type Source interface {
	Name() string
	Countries(ctx context.Context) ([]model.Country, error)
	States(ctx context.Context, countryID int) ([]model.State, error)
	Cities(ctx context.Context, stateID int) ([]model.City, error)
	CityDetail(ctx context.Context, cityID int) (*model.CityDetail, error)
	PrayerTimes(ctx context.Context, cityID, year int) ([]model.Day, error)
	ReligiousDays(ctx context.Context, year int) ([]model.ReligiousDay, error)
	DailyContent(ctx context.Context, date time.Time) (*model.DailyContent, error)
}
