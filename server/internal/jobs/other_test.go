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

func TestDailyContent_FetchesTodayAndAheadSkippingExisting(t *testing.T) {
	f := newFake()
	for i := 0; i < 3; i++ {
		day := time.Date(2026, 9, 16+i, 0, 0, 0, 0, time.UTC)
		f.daily[day.Format(model.DateLayout)] = &model.DailyContent{Date: day.Format(model.DateLayout), DayOfYear: day.YearDay(), Verse: "v"}
	}
	d := testDeps(t, f)
	res, err := DailyContent(context.Background(), d, 2)
	if err != nil || res.Written != 3 || res.Fetched != 3 {
		t.Fatalf("%+v %v", res, err)
	}
	var got model.DailyContent
	if err := d.Store.ReadJSON(store.DailyContentPath(time.Date(2026, 9, 17, 0, 0, 0, 0, time.UTC)), &got); err != nil || got.Date != "2026-09-17" {
		t.Fatalf("%+v %v", got, err)
	}
	f.calls["daily"] = 0
	res, err = DailyContent(context.Background(), d, 2)
	if err != nil || res.Skipped != 3 || f.calls["daily"] != 0 {
		t.Fatalf("second run must skip existing: %+v calls=%d", res, f.calls["daily"])
	}
	if d.State.DailyContent.Days != 3 {
		t.Fatalf("%+v", d.State.DailyContent)
	}
}

func TestDailyContent_UnsupportedSkips(t *testing.T) {
	f := newFake()
	f.unsupported = true
	d := testDeps(t, f)
	res, err := DailyContent(context.Background(), d, 7)
	if err != nil || res.Skipped != 8 || res.Fetched != 0 {
		t.Fatalf("%+v %v", res, err)
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
