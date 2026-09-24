package validate

import (
	"errors"
	"testing"
	"time"

	"vakit/internal/model"
)

func day(date string, hijri model.Hijri, clocks ...string) model.Day {
	return model.Day{Date: date, Hijri: hijri, Fajr: clocks[0], Sunrise: clocks[1], Dhuhr: clocks[2],
		Asr: clocks[3], Maghrib: clocks[4], Isha: clocks[5]}
}

func goodDays(year int, n int) []model.Day {
	start := time.Date(year, 9, 1, 0, 0, 0, 0, time.UTC)
	days := make([]model.Day, 0, n)
	h := model.Hijri{Day: 19, Month: 3, Year: 1448, MonthName: "Rebiulevvel"}
	for i := 0; i < n; i++ {
		days = append(days, day(start.AddDate(0, 0, i).Format(model.DateLayout), h,
			"05:00", "06:30", "13:00", "16:30", "19:20", "20:40"))
		h.Day++
		if h.Day > 30 {
			h.Day, h.Month = 1, h.Month+1
			h.MonthName = model.HijriMonths[h.Month-1]
		}
	}
	return days
}

func ruleOf(t *testing.T, err error) string {
	t.Helper()
	var p *Problem
	if !errors.As(err, &p) {
		t.Fatalf("expected *Problem, got %v", err)
	}
	return p.Rule
}

func TestYearTimes_AcceptsWellFormedPartialYear(t *testing.T) {
	if err := YearTimes(goodDays(2026, 31), 2026, nil); err != nil {
		t.Fatal(err)
	}
}

func TestYearTimes_RejectsEmpty(t *testing.T) {
	if got := ruleOf(t, YearTimes(nil, 2026, nil)); got != "nonempty" {
		t.Fatal(got)
	}
}

func TestYearTimes_RejectsDateOutsideYear(t *testing.T) {
	d := goodDays(2026, 2)
	d[1].Date = "2027-01-01"
	if got := ruleOf(t, YearTimes(d, 2026, nil)); got != "year" {
		t.Fatal(got)
	}
}

func TestYearTimes_RejectsDuplicateOrUnsortedDates(t *testing.T) {
	d := goodDays(2026, 3)
	d[2].Date = d[1].Date
	if got := ruleOf(t, YearTimes(d, 2026, nil)); got != "order" {
		t.Fatal(got)
	}
}

func TestYearTimes_RejectsPrayerOrderViolation(t *testing.T) {
	d := goodDays(2026, 1)
	d[0].Asr = "12:00" // dhuhr'dan önce
	if got := ruleOf(t, YearTimes(d, 2026, nil)); got != "prayer-order" {
		t.Fatal(got)
	}
}

func TestYearTimes_RejectsBadClock(t *testing.T) {
	d := goodDays(2026, 1)
	d[0].Isha = "25:00"
	if got := ruleOf(t, YearTimes(d, 2026, nil)); got != "clock" {
		t.Fatal(got)
	}
}

func TestYearTimes_RejectsYearOverYearDrift(t *testing.T) {
	cur := goodDays(2026, 1)
	prev := goodDays(2025, 1) // aynı ay-gün: 09-01
	prev[0].Maghrib = "19:26" // 6 dk fark
	if got := ruleOf(t, YearTimes(cur, 2026, prev)); got != "drift" {
		t.Fatal(got)
	}
	prev[0].Maghrib = "19:25" // 5 dk sınırda kabul
	if err := YearTimes(cur, 2026, prev); err != nil {
		t.Fatal(err)
	}
}

func TestYearTimes_HijriStepMustBePlusOneOrResetToOne(t *testing.T) {
	d := goodDays(2026, 2)
	d[1].Hijri.Day = d[0].Hijri.Day + 2
	if got := ruleOf(t, YearTimes(d, 2026, nil)); got != "hijri-step" {
		t.Fatal(got)
	}
	d = goodDays(2026, 2)
	d[0].Hijri = model.Hijri{Day: 29, Month: 12, Year: 1447, MonthName: "Zilhicce"}
	d[1].Hijri = model.Hijri{Day: 1, Month: 1, Year: 1448, MonthName: "Muharrem"}
	if err := YearTimes(d, 2026, nil); err != nil {
		t.Fatalf("year rollover must be accepted: %v", err)
	}
}

func TestYearTimes_GapBetweenDatesIsAllowedAndSkipsHijriStep(t *testing.T) {
	d := goodDays(2026, 3)
	d = []model.Day{d[0], d[2]} // 1 günlük boşluk, hicri gün +2
	if err := YearTimes(d, 2026, nil); err != nil {
		t.Fatal(err)
	}
}

func TestYearTimes_RejectsHijriMonthNameMismatch(t *testing.T) {
	d := goodDays(2026, 1)
	d[0].Hijri.MonthName = "Ramazan" // ay 3 ile uyumsuz
	if got := ruleOf(t, YearTimes(d, 2026, nil)); got != "hijri" {
		t.Fatal(got)
	}
}

func TestIsCompleteAndDaysInYear(t *testing.T) {
	if DaysInYear(2028) != 366 || DaysInYear(2026) != 365 || DaysInYear(2100) != 365 {
		t.Fatal("leap rules")
	}
	if IsComplete(goodDays(2026, 31), 2026) {
		t.Fatal("31 days is not complete")
	}
}

func TestReligiousDays(t *testing.T) {
	ok := []model.ReligiousDay{
		{ID: 1, Date: "2026-01-15", Name: "Miraç Kandili", Hijri: model.Hijri{Day: 26, Month: 7, Year: 1447, MonthName: "Recep"}},
		{ID: 2, Date: "2026-01-20", Name: "Şaban Ayı Başlangıcı", Hijri: model.Hijri{Day: 1, Month: 8, Year: 1447, MonthName: "Şaban"}},
		{ID: 3, Date: "2026-01-20", Name: "Aynı güne ikinci kayıt", Hijri: model.Hijri{Day: 1, Month: 8, Year: 1447, MonthName: "Şaban"}},
	}
	if err := ReligiousDays(ok, 2026); err != nil {
		t.Fatal(err)
	}
	bad := append([]model.ReligiousDay{}, ok...)
	bad[1].Date = "2026-01-10" // sıra bozuk
	if got := ruleOf(t, ReligiousDays(bad, 2026)); got != "order" {
		t.Fatal(got)
	}
	bad = append([]model.ReligiousDay{}, ok...)
	bad[0].Name = ""
	if got := ruleOf(t, ReligiousDays(bad, 2026)); got != "name" {
		t.Fatal(got)
	}
	bad = append([]model.ReligiousDay{}, ok...)
	bad[0].Date = "2025-12-31"
	if got := ruleOf(t, ReligiousDays(bad, 2026)); got != "year" {
		t.Fatal(got)
	}
	if err := ReligiousDays(nil, 2026); err == nil {
		t.Fatal("empty list must fail")
	}
}
