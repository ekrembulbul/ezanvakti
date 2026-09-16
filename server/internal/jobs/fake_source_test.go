package jobs

import (
	"context"
	"time"

	"vakit/internal/model"
	"vakit/internal/source"
	"vakit/internal/store"
)

// fakeSource, testlerde kaynak davranışını programlar; çağrı sayılarını tutar.
type fakeSource struct {
	name          string
	countries     []model.Country
	states        map[int][]model.State
	cities        map[int][]model.City
	details       map[int]*model.CityDetail
	prayerTimes   map[string][]model.Day // store.CityYearKey
	religiousDays map[int][]model.ReligiousDay
	daily         map[string]*model.DailyContent
	failWith      error // nil değilse veri uçları bu hatayı döner
	unsupported   bool  // CityDetail/ReligiousDays/DailyContent → ErrUnsupported
	calls         map[string]int
}

func newFake() *fakeSource {
	return &fakeSource{name: "fake", states: map[int][]model.State{}, cities: map[int][]model.City{},
		details: map[int]*model.CityDetail{}, prayerTimes: map[string][]model.Day{},
		religiousDays: map[int][]model.ReligiousDay{}, daily: map[string]*model.DailyContent{}, calls: map[string]int{}}
}

func (f *fakeSource) Name() string { return f.name }

func (f *fakeSource) Countries(context.Context) ([]model.Country, error) {
	f.calls["countries"]++
	return f.countries, f.failWith
}

func (f *fakeSource) States(_ context.Context, countryID int) ([]model.State, error) {
	f.calls["states"]++
	return f.states[countryID], f.failWith
}

func (f *fakeSource) Cities(_ context.Context, stateID int) ([]model.City, error) {
	f.calls["cities"]++
	return f.cities[stateID], f.failWith
}

func (f *fakeSource) CityDetail(_ context.Context, cityID int) (*model.CityDetail, error) {
	f.calls["detail"]++
	if f.unsupported {
		return nil, source.ErrUnsupported
	}
	if f.failWith != nil {
		return nil, f.failWith
	}
	return f.details[cityID], nil
}

func (f *fakeSource) PrayerTimes(_ context.Context, cityID, year int) ([]model.Day, error) {
	f.calls["prayer"]++
	if f.failWith != nil {
		return nil, f.failWith
	}
	return f.prayerTimes[store.CityYearKey(cityID, year)], nil
}

func (f *fakeSource) ReligiousDays(_ context.Context, year int) ([]model.ReligiousDay, error) {
	f.calls["religious"]++
	if f.unsupported {
		return nil, source.ErrUnsupported
	}
	return f.religiousDays[year], f.failWith
}

func (f *fakeSource) DailyContent(_ context.Context, date time.Time) (*model.DailyContent, error) {
	f.calls["daily"]++
	if f.unsupported {
		return nil, source.ErrUnsupported
	}
	if f.failWith != nil {
		return nil, f.failWith
	}
	return f.daily[date.Format(model.DateLayout)], nil
}
