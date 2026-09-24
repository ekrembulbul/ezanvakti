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

// hijriFor, takvim gününden deterministik ve ardışık-tutarlı sahte Hicri tarih üretir
// (30 günlük aylar; yıl içinde 13. ay bir sonraki Hicri yılın 1. ayına devrilir).
func hijriFor(t time.Time) model.Hijri {
	idx := t.YearDay() - 1
	month, year := idx/30+1, 1448
	if month > 12 {
		month, year = month-12, year+1
	}
	return model.Hijri{Day: idx%30 + 1, Month: month, Year: year, MonthName: model.HijriMonths[month-1]}
}

func mkDays(year int, month time.Month, day, n int) []model.Day {
	start := time.Date(year, month, day, 0, 0, 0, 0, time.UTC)
	var out []model.Day
	for i := 0; i < n; i++ {
		t := start.AddDate(0, 0, i)
		out = append(out, model.Day{Date: t.Format(model.DateLayout), Hijri: hijriFor(t),
			Fajr: "05:00", Sunrise: "06:30", Dhuhr: "13:00", Asr: "16:30", Maghrib: "19:20", Isha: "20:40"})
	}
	return out
}

func readYear(t *testing.T, st *store.Store, city, year int) model.YearTimes {
	t.Helper()
	var yt model.YearTimes
	if err := st.ReadJSON(store.PrayerTimesPath(city, year), &yt); err != nil {
		t.Fatalf("read %d/%d: %v", city, year, err)
	}
	return yt
}

func TestPrayerTimes_WritesPartialYearAndState(t *testing.T) {
	f := newFake()
	f.prayerTimes[store.CityYearKey(9541, 2026)] = mkDays(2026, 9, 15, 31)
	d := testDeps(t, f)
	res, err := PrayerTimes(context.Background(), d, []int{9541}, []int{2026}, 10)
	if err != nil {
		t.Fatal(err)
	}
	yt := readYear(t, d.Store, 9541, 2026)
	if yt.Complete || len(yt.Days) != 31 || yt.Source != "diyanet" || yt.Via != "" || yt.CityID != 9541 || yt.SchemaVersion != 1 {
		t.Fatalf("%+v", yt)
	}
	st := d.State.PrayerTimes[store.CityYearKey(9541, 2026)]
	if st.Days != 31 || st.Horizon != "2026-10-15" || st.Complete || st.LastFetchedAt != d.Now() {
		t.Fatalf("%+v", st)
	}
	if res.Fetched != 1 || res.Written != 1 {
		t.Fatalf("%+v", res)
	}
}

func TestPrayerTimes_WebSourceMarksVia(t *testing.T) {
	f := newFake()
	f.name = "web"
	f.prayerTimes[store.CityYearKey(9541, 2027)] = mkDays(2027, 1, 1, 365)
	d := testDeps(t, f)
	if _, err := PrayerTimes(context.Background(), d, []int{9541}, []int{2027}, 10); err != nil {
		t.Fatal(err)
	}
	yt := readYear(t, d.Store, 9541, 2027)
	if yt.Via != "web" || !yt.Complete {
		t.Fatalf("%+v", yt)
	}
}

func TestPrayerTimes_MergesRollingWindowIntoExistingFile(t *testing.T) {
	f := newFake()
	f.prayerTimes[store.CityYearKey(9541, 2026)] = mkDays(2026, 9, 15, 31)
	d := testDeps(t, f)
	if _, err := PrayerTimes(context.Background(), d, []int{9541}, []int{2026}, 10); err != nil {
		t.Fatal(err)
	}
	// 8 gün sonra pencere kaydı: 23 Eyl – 23 Eki; 15 Eki'nin akşamı değişti (çekilen kazanır)
	later := mkDays(2026, 9, 23, 31)
	later[22].Maghrib = "19:21"
	f.prayerTimes[store.CityYearKey(9541, 2026)] = later
	d.Now = func() time.Time { return time.Date(2026, 9, 24, 3, 0, 0, 0, time.UTC) }
	if _, err := PrayerTimes(context.Background(), d, []int{9541}, []int{2026}, 10); err != nil {
		t.Fatal(err)
	}
	yt := readYear(t, d.Store, 9541, 2026)
	if len(yt.Days) != 39 || yt.Days[0].Date != "2026-09-15" || yt.Days[38].Date != "2026-10-23" {
		t.Fatalf("len=%d first=%s last=%s", len(yt.Days), yt.Days[0].Date, yt.Days[len(yt.Days)-1].Date)
	}
	for _, day := range yt.Days {
		if day.Date == "2026-10-15" && day.Maghrib != "19:21" {
			t.Fatalf("fetched value must win: %+v", day)
		}
	}
}

func TestPrayerTimes_SkipsCompleteAndRecentIncomplete(t *testing.T) {
	f := newFake()
	f.prayerTimes[store.CityYearKey(1, 2027)] = mkDays(2027, 1, 1, 365)
	f.prayerTimes[store.CityYearKey(2, 2026)] = mkDays(2026, 9, 15, 31)
	d := testDeps(t, f)
	if _, err := PrayerTimes(context.Background(), d, []int{1, 2}, []int{2026, 2027}, 10); err != nil {
		t.Fatal(err)
	}
	f.calls["prayer"] = 0
	d.Now = func() time.Time { return time.Date(2026, 9, 18, 3, 0, 0, 0, time.UTC) } // 2 gün sonra
	res, err := PrayerTimes(context.Background(), d, []int{1, 2}, []int{2026, 2027}, 10)
	if err != nil {
		t.Fatal(err)
	}
	// 1/2027 complete → atla; 2/2026 incomplete ama 7 gün dolmadı → atla;
	// 1/2026 ve 2/2027 "no data" denemesi 2 gün önce → 7 gün dolmadı, atla.
	if f.calls["prayer"] != 0 || res.Skipped != 4 {
		t.Fatalf("calls=%d res=%+v", f.calls["prayer"], res)
	}
}

func TestPrayerTimes_RefetchesIncompleteAfterSevenDays(t *testing.T) {
	f := newFake()
	f.prayerTimes[store.CityYearKey(2, 2026)] = mkDays(2026, 9, 15, 31)
	d := testDeps(t, f)
	_, _ = PrayerTimes(context.Background(), d, []int{2}, []int{2026}, 10)
	f.calls["prayer"] = 0
	d.Now = func() time.Time { return time.Date(2026, 9, 23, 3, 0, 0, 0, time.UTC) } // 7 gün sonra
	if _, err := PrayerTimes(context.Background(), d, []int{2}, []int{2026}, 10); err != nil || f.calls["prayer"] != 1 {
		t.Fatalf("calls=%d err=%v", f.calls["prayer"], err)
	}
}

func TestPrayerTimes_BatchLimitsFetches(t *testing.T) {
	f := newFake()
	for _, id := range []int{1, 2, 3, 4, 5} {
		f.prayerTimes[store.CityYearKey(id, 2027)] = mkDays(2027, 1, 1, 365)
	}
	d := testDeps(t, f)
	res, err := PrayerTimes(context.Background(), d, []int{1, 2, 3, 4, 5}, []int{2027}, 2)
	if err != nil || res.Fetched != 2 || res.Written != 2 || res.Stopped != "batch" {
		t.Fatalf("%+v %v", res, err)
	}
}

func TestPrayerTimes_QuotaStopsRun(t *testing.T) {
	f := newFake()
	f.failWith = source.ErrQuotaExceeded
	d := testDeps(t, f)
	res, err := PrayerTimes(context.Background(), d, []int{1, 2}, []int{2027}, 10)
	if !errors.Is(err, source.ErrQuotaExceeded) || res.Stopped != "quota" || f.calls["prayer"] != 1 {
		t.Fatalf("%+v %v calls=%d", res, err, f.calls["prayer"])
	}
}

func TestPrayerTimes_ValidationRejectKeepsOldFile(t *testing.T) {
	f := newFake()
	good := mkDays(2026, 9, 15, 31)
	f.prayerTimes[store.CityYearKey(9541, 2026)] = good
	d := testDeps(t, f)
	_, _ = PrayerTimes(context.Background(), d, []int{9541}, []int{2026}, 10)
	bad := mkDays(2026, 9, 15, 31)
	bad[3].Asr = "12:00" // sıra ihlali
	f.prayerTimes[store.CityYearKey(9541, 2026)] = bad
	d.Now = func() time.Time { return time.Date(2026, 9, 30, 3, 0, 0, 0, time.UTC) }
	res, err := PrayerTimes(context.Background(), d, []int{9541}, []int{2026}, 10)
	if err != nil || res.Rejected != 1 || d.State.Rejected != 1 {
		t.Fatalf("%+v %v state=%d", res, err, d.State.Rejected)
	}
	yt := readYear(t, d.Store, 9541, 2026)
	if yt.Days[3].Asr != "16:30" {
		t.Fatal("rejected fetch must not modify the published file")
	}
}

func TestPrayerTimes_EmptyResultLeavesNoteNoFile(t *testing.T) {
	f := newFake()
	d := testDeps(t, f)
	res, err := PrayerTimes(context.Background(), d, []int{9541}, []int{2028}, 10)
	if err != nil || res.Written != 0 || d.Store.Exists(store.PrayerTimesPath(9541, 2028)) {
		t.Fatalf("%+v %v", res, err)
	}
	if d.State.PrayerTimes[store.CityYearKey(9541, 2028)].Note != "no data" {
		t.Fatalf("%+v", d.State.PrayerTimes)
	}
}

func TestPrayerTimes_ThreeConsecutiveErrorsStopRun(t *testing.T) {
	f := newFake()
	f.failWith = errors.New("boom")
	d := testDeps(t, f)
	res, err := PrayerTimes(context.Background(), d, []int{1, 2, 3, 4}, []int{2027}, 10)
	if err == nil || res.Errors != 3 || res.Stopped != "errors" || f.calls["prayer"] != 3 {
		t.Fatalf("%+v %v calls=%d", res, err, f.calls["prayer"])
	}
}

func TestMergeDays(t *testing.T) {
	a := mkDays(2026, 9, 15, 3)
	b := mkDays(2026, 9, 16, 3)
	b[0].Isha = "20:41"
	m := mergeDays(a, b)
	if len(m) != 4 || m[0].Date != "2026-09-15" || m[3].Date != "2026-09-18" || m[1].Isha != "20:41" {
		t.Fatalf("%+v", m)
	}
}
