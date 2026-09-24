package jobs

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"testing"
	"time"

	"vakit/internal/geo"
	"vakit/internal/model"
	"vakit/internal/source"
	"vakit/internal/store"
)

func f64(v float64) *float64 { return &v }

func testDeps(t *testing.T, src source.Source) Deps {
	t.Helper()
	st := store.New(t.TempDir())
	return Deps{Source: src, Store: st, State: store.NewSyncState(), Logger: slog.New(slog.NewTextHandler(io.Discard, nil)),
		Now: func() time.Time { return time.Date(2026, 9, 16, 3, 0, 0, 0, time.UTC) }, Geo: geo.Index{9541: {Latitude: 41.0082, Longitude: 28.9784}}}
}

func placesFake() *fakeSource {
	f := newFake()
	f.countries = []model.Country{{ID: 1, Name: "KUZEY KIBRIS", NameEn: "NORTH CYPRUS"}, {ID: 2, Name: "TÜRKİYE", NameEn: "TURKEY"}}
	f.states[2] = []model.State{{ID: 539, Name: "İSTANBUL", CountryID: 2}}
	f.cities[539] = []model.City{{ID: 9541, Name: "İSTANBUL", StateID: 539}, {ID: 9547, Name: "ŞİLE", StateID: 539}}
	f.details[9541] = &model.CityDetail{CityID: 9541, QiblaAngle: f64(151), QiblaAngleMagnetic: f64(146), DistanceToKaaba: f64(2400)}
	f.details[9547] = &model.CityDetail{CityID: 9547, QiblaAngle: f64(150)}
	return f
}

func TestPlaces_WritesHierarchyWithGeoAndQibla(t *testing.T) {
	f := placesFake()
	d := testDeps(t, f)
	res, err := Places(context.Background(), d, []int{2})
	if err != nil {
		t.Fatal(err)
	}
	var countries []model.Country
	if err := d.Store.ReadJSON(store.CountriesPath(), &countries); err != nil || len(countries) != 2 || !countries[1].Enabled || countries[0].Enabled {
		t.Fatalf("%v %v", countries, err)
	}
	var states []model.State
	if err := d.Store.ReadJSON(store.StatesPath(2), &states); err != nil || len(states) != 1 {
		t.Fatalf("%v %v", states, err)
	}
	var cities []model.City
	if err := d.Store.ReadJSON(store.CitiesPath(539), &cities); err != nil || len(cities) != 2 {
		t.Fatalf("%v %v", cities, err)
	}
	ist := cities[0]
	if ist.CountryID != 2 || *ist.Latitude != 41.0082 || *ist.QiblaAngle != 151 || *ist.QiblaAngleMagnetic != 146 || *ist.DistanceToKaaba != 2400 {
		t.Fatalf("%+v", ist)
	}
	if cities[1].Latitude != nil || *cities[1].QiblaAngle != 150 {
		t.Fatalf("şile: %+v", cities[1])
	}
	var tr []model.CityWithState
	if err := d.Store.ReadJSON(store.TRCitiesPath(), &tr); err != nil || len(tr) != 2 || tr[0].StateName != "İSTANBUL" {
		t.Fatalf("%v %v", tr, err)
	}
	if d.State.Places.Cities != 2 || d.State.Places.Countries != 2 || d.State.Places.UpdatedAt.IsZero() {
		t.Fatalf("%+v", d.State.Places)
	}
	if res.Written != 4 || f.calls["detail"] != 2 { // countries, states, cities, tr → 4 dosya
		t.Fatalf("%+v detail=%d", res, f.calls["detail"])
	}
}

func TestPlaces_SecondRunSkipsCityDetailForKnownQibla(t *testing.T) {
	f := placesFake()
	d := testDeps(t, f)
	if _, err := Places(context.Background(), d, []int{2}); err != nil {
		t.Fatal(err)
	}
	if _, err := Places(context.Background(), d, []int{2}); err != nil {
		t.Fatal(err)
	}
	if f.calls["detail"] != 2 {
		t.Fatalf("CityDetail must not be re-fetched when qibla is known; calls=%d", f.calls["detail"])
	}
}

func TestPlaces_UnsupportedDetailIsSkipped(t *testing.T) {
	f := placesFake()
	f.unsupported = true
	d := testDeps(t, f)
	if _, err := Places(context.Background(), d, []int{2}); err != nil {
		t.Fatal(err)
	}
	var cities []model.City
	_ = d.Store.ReadJSON(store.CitiesPath(539), &cities)
	if cities[0].QiblaAngle != nil || *cities[0].Latitude != 41.0082 {
		t.Fatalf("%+v", cities[0])
	}
}

// quotaAfterCountries: ülkeler döner, illerde kota biter.
type quotaAfterCountries struct {
	*fakeSource
}

func (q *quotaAfterCountries) States(context.Context, int) ([]model.State, error) {
	return nil, source.ErrQuotaExceeded
}

func TestPlaces_QuotaStopsRunButKeepsWrittenFiles(t *testing.T) {
	f := placesFake()
	d := testDeps(t, f)
	d.Source = &quotaAfterCountries{fakeSource: f}
	res, err := Places(context.Background(), d, []int{2})
	if !errors.Is(err, source.ErrQuotaExceeded) || res.Stopped == "" {
		t.Fatalf("err=%v res=%+v", err, res)
	}
	if !d.Store.Exists(store.CountriesPath()) || d.Store.Exists(store.StatesPath(2)) {
		t.Fatal("countries must be written, states must not")
	}
}

func TestEnabledCityIDs_ReadsCitiesOfEnabledCountries(t *testing.T) {
	f := placesFake()
	d := testDeps(t, f)
	if _, err := Places(context.Background(), d, []int{2}); err != nil {
		t.Fatal(err)
	}
	ids, err := EnabledCityIDs(d.Store, []int{2})
	if err != nil || len(ids) != 2 || ids[0] != 9541 || ids[1] != 9547 {
		t.Fatalf("%v %v", ids, err)
	}
}
