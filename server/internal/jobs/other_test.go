package jobs

import (
	"context"
	"errors"
	"testing"
	"time"

	"vakit/internal/model"
	"vakit/internal/source"
	"vakit/internal/store"
)

func TestReligiousDays_WritesValidatedYear(t *testing.T) {
	f := newFake()
	f.religiousDays[2026] = []model.ReligiousDay{
		{ID: 1, Date: "2026-01-15", Name: "Miraç Kandili", IsSpecial: true, Hijri: model.Hijri{Day: 26, Month: 7, Year: 1447, MonthName: "Recep"}},
		{ID: 2, Date: "2026-02-19", Name: "Ramazan Başlangıcı", Hijri: model.Hijri{Day: 1, Month: 9, Year: 1447, MonthName: "Ramazan"}},
	}
	d := testDeps(t, f)
	res, err := ReligiousDays(context.Background(), d, []int{2026})
	if err != nil || res.Written != 1 {
		t.Fatalf("%+v %v", res, err)
	}
	var got []model.ReligiousDay
	if err := d.Store.ReadJSON(store.ReligiousDaysPath(2026), &got); err != nil || len(got) != 2 {
		t.Fatalf("%v %v", got, err)
	}
	if d.State.ReligiousDays["2026"] != d.Now() {
		t.Fatalf("%+v", d.State.ReligiousDays)
	}
}

func TestReligiousDays_InvalidIsRejected(t *testing.T) {
	f := newFake()
	f.religiousDays[2026] = []model.ReligiousDay{{ID: 1, Date: "2025-12-31", Name: "x", Hijri: model.Hijri{Day: 1, Month: 1, Year: 1447, MonthName: "Muharrem"}}}
	d := testDeps(t, f)
	res, err := ReligiousDays(context.Background(), d, []int{2026})
	if err != nil || res.Rejected != 1 || d.Store.Exists(store.ReligiousDaysPath(2026)) {
		t.Fatalf("%+v %v", res, err)
	}
}

func TestReligiousDays_EmptyYearIsNotYetPublished(t *testing.T) {
	f := newFake() // 2027 tanımsız: kaynak boş liste döner (Diyanet o yılı henüz yayımlamadı)
	d := testDeps(t, f)
	res, err := ReligiousDays(context.Background(), d, []int{2027})
	if err != nil || res.Rejected != 0 || d.State.Rejected != 0 || res.Written != 0 {
		t.Fatalf("%+v %v state.Rejected=%d", res, err, d.State.Rejected)
	}
	if d.Store.Exists(store.ReligiousDaysPath(2027)) {
		t.Fatal("boş yıl yazılmamalı")
	}
	if _, ok := d.State.ReligiousDays["2027"]; ok {
		t.Fatalf("boş yıl güncellenmiş sayılmamalı: %+v", d.State.ReligiousDays)
	}
}

func TestReligiousDays_UnsupportedSourceIsSkipped(t *testing.T) {
	f := newFake()
	f.unsupported = true
	d := testDeps(t, f)
	res, err := ReligiousDays(context.Background(), d, []int{2026, 2027})
	if err != nil || res.Skipped != 2 {
		t.Fatalf("%+v %v", res, err)
	}
}

func TestReligiousDays_QuotaStops(t *testing.T) {
	f := newFake()
	f.failWith = source.ErrQuotaExceeded
	d := testDeps(t, f)
	if _, err := ReligiousDays(context.Background(), d, []int{2026}); !errors.Is(err, source.ErrQuotaExceeded) {
		t.Fatal(err)
	}
}

// trNoon, Türkiye gününün öğlesini verir; DailyContentPath yerel yıl gününü kullanır.
func trNoon(y int, m time.Month, d int) time.Time { return time.Date(y, m, d, 12, 0, 0, 0, TurkeyZone) }

func fullContent(dayOfYear int) *model.DailyContent {
	return &model.DailyContent{DayOfYear: dayOfYear, Verse: "v", VerseSource: "vs", Hadith: "h", HadithSource: "hs", Prayer: "p"}
}

func TestDailyContent_WritesTurkeyDayWhenDayMatches(t *testing.T) {
	f := newFake()
	d := testDeps(t, f)
	d.Now = func() time.Time { return time.Date(2026, 10, 1, 21, 5, 0, 0, time.UTC) } // TR 2 Ekim 00:05
	f.today = fullContent(275)
	res, err := DailyContent(context.Background(), d)
	if err != nil || res.Written != 1 || res.Fetched != 1 {
		t.Fatalf("%+v %v", res, err)
	}
	var got model.DailyContent
	if err := d.Store.ReadJSON(store.DailyContentPath(trNoon(2026, 10, 2)), &got); err != nil || got.Date != "2026-10-02" {
		t.Fatalf("%+v %v", got, err)
	}
	if d.State.DailyContent.UpdatedAt.IsZero() || d.State.DailyContent.Days != 1 {
		t.Fatalf("%+v", d.State.DailyContent)
	}
}

func TestDailyContent_BeforeTurkeyMidnightUsesPreviousDay(t *testing.T) {
	f := newFake()
	d := testDeps(t, f)
	d.Now = func() time.Time { return time.Date(2026, 10, 1, 20, 59, 0, 0, time.UTC) } // TR 1 Ekim 23:59
	f.today = fullContent(274)
	if res, err := DailyContent(context.Background(), d); err != nil || res.Written != 1 {
		t.Fatalf("%+v %v", res, err)
	}
	if !d.Store.Exists(store.DailyContentPath(trNoon(2026, 10, 1))) {
		t.Fatal("1 Ekim dosyası yazılmalıydı")
	}
}

func TestDailyContent_DayMismatchWritesNothing(t *testing.T) {
	f := newFake()
	d := testDeps(t, f)
	d.Now = func() time.Time { return time.Date(2026, 10, 1, 21, 5, 0, 0, time.UTC) }
	f.today = fullContent(274) // Diyanet henüz 1 Ekim'de
	res, err := DailyContent(context.Background(), d)
	if err != nil || res.Written != 0 || res.Skipped != 1 {
		t.Fatalf("%+v %v", res, err)
	}
	for _, day := range []time.Time{trNoon(2026, 10, 1), trNoon(2026, 10, 2)} {
		if d.Store.Exists(store.DailyContentPath(day)) {
			t.Fatalf("%s yazılmamalıydı", day.Format(model.DateLayout))
		}
	}
}

func TestDailyContent_ExistingTodaySkipsFetch(t *testing.T) {
	f := newFake()
	d := testDeps(t, f)
	d.Now = func() time.Time { return time.Date(2026, 10, 1, 21, 5, 0, 0, time.UTC) }
	if err := d.Store.WriteJSON(store.DailyContentPath(trNoon(2026, 10, 2)), fullContent(275)); err != nil {
		t.Fatal(err)
	}
	f.today = fullContent(275)
	res, err := DailyContent(context.Background(), d)
	if err != nil || res.Skipped != 1 || f.calls["daily"] != 0 {
		t.Fatalf("%+v %v calls=%d", res, err, f.calls["daily"])
	}
}

func TestDailyContent_IncompleteRejected(t *testing.T) {
	f := newFake()
	d := testDeps(t, f)
	d.Now = func() time.Time { return time.Date(2026, 10, 1, 21, 5, 0, 0, time.UTC) }
	f.today = fullContent(275)
	f.today.Hadith = ""
	res, err := DailyContent(context.Background(), d)
	if err != nil || res.Rejected != 1 || res.Written != 0 {
		t.Fatalf("%+v %v", res, err)
	}
	if d.Store.Exists(store.DailyContentPath(trNoon(2026, 10, 2))) {
		t.Fatal("eksik içerik yazılmamalı")
	}
}

func TestDailyContent_PrunesOlderThanSevenDays(t *testing.T) {
	f := newFake()
	d := testDeps(t, f)
	d.Now = func() time.Time { return time.Date(2026, 10, 1, 21, 5, 0, 0, time.UTC) } // TR 2 Ekim
	old := []time.Time{trNoon(2026, 9, 24), trNoon(2025, 12, 31)}
	kept := []time.Time{trNoon(2026, 9, 25), trNoon(2026, 9, 30)}
	for _, day := range append(append([]time.Time{}, old...), kept...) {
		if err := d.Store.WriteJSON(store.DailyContentPath(day), fullContent(day.YearDay())); err != nil {
			t.Fatal(err)
		}
	}
	f.today = fullContent(275)
	if _, err := DailyContent(context.Background(), d); err != nil {
		t.Fatal(err)
	}
	for _, day := range old {
		if d.Store.Exists(store.DailyContentPath(day)) {
			t.Fatalf("%s silinmeliydi", day.Format(model.DateLayout))
		}
	}
	for _, day := range kept {
		if !d.Store.Exists(store.DailyContentPath(day)) {
			t.Fatalf("%s kalmalıydı", day.Format(model.DateLayout))
		}
	}
	if d.State.DailyContent.Days != 3 { // 25 Eylül, 30 Eylül, 2 Ekim
		t.Fatalf("days=%d", d.State.DailyContent.Days)
	}
}

func TestDailyContent_UnsupportedSkips(t *testing.T) {
	f := newFake()
	f.unsupported = true
	d := testDeps(t, f)
	res, err := DailyContent(context.Background(), d)
	if err != nil || res.Skipped != 1 || res.Fetched != 0 {
		t.Fatalf("%+v %v", res, err)
	}
}

func TestDailyContent_QuotaStops(t *testing.T) {
	f := newFake()
	f.failWith = source.ErrQuotaExceeded
	d := testDeps(t, f)
	if _, err := DailyContent(context.Background(), d); !errors.Is(err, source.ErrQuotaExceeded) {
		t.Fatal(err)
	}
}

func TestVerify_ReportsBrokenPublishedFiles(t *testing.T) {
	d := testDeps(t, newFake())
	good := model.YearTimes{SchemaVersion: 1, Source: "diyanet", CityID: 1, Year: 2027, Days: mkDays(2027, 1, 1, 10)}
	_ = d.Store.WriteJSON(store.PrayerTimesPath(1, 2027), good)
	bad := good
	bad.CityID = 2
	bad.Days = mkDays(2027, 1, 1, 10)
	bad.Days[5].Fajr = "23:00"
	_ = d.Store.WriteJSON(store.PrayerTimesPath(2, 2027), bad)
	_ = d.Store.WriteJSON(store.ReligiousDaysPath(2026), []model.ReligiousDay{{ID: 1, Date: "2026-01-15", Name: "x", Hijri: model.Hijri{Day: 26, Month: 7, Year: 1447, MonthName: "Recep"}}})
	problems, err := Verify(d.Store, d.Logger)
	if err != nil || problems != 1 {
		t.Fatalf("problems=%d err=%v", problems, err)
	}
}
