// Package validate, yayın öncesi veri kurallarını (spec VAK.5) uygular.
// Kural ihlali dosya yazımını engeller; hata *Problem olarak döner.
package validate

import (
	"fmt"
	"time"

	"vakit/internal/model"
)

const MaxYearOverYearDriftMinutes = 5

type Problem struct {
	Rule   string // nonempty | date | year | order | clock | prayer-order | hijri | hijri-step | drift | name
	Date   string
	Detail string
}

func (p *Problem) Error() string {
	if p.Date == "" {
		return fmt.Sprintf("validate[%s]: %s", p.Rule, p.Detail)
	}
	return fmt.Sprintf("validate[%s] %s: %s", p.Rule, p.Date, p.Detail)
}

func isLeap(year int) bool { return year%4 == 0 && (year%100 != 0 || year%400 == 0) }

func DaysInYear(year int) int {
	if isLeap(year) {
		return 366
	}
	return 365
}

func IsComplete(days []model.Day, year int) bool { return len(days) == DaysInYear(year) }

// YearTimes: tarihler yıl içinde, tekrar yok, artan; vakit sırası; Hicri sağlamlığı;
// ardışık günde Hicri adımı; önceki yılın aynı ay-günüyle ±5 dk. Boşluk izinli.
func YearTimes(days []model.Day, year int, previous []model.Day) error {
	if len(days) == 0 {
		return &Problem{Rule: "nonempty", Detail: "no days"}
	}
	prevByMonthDay := make(map[string]model.Day, len(previous))
	for _, p := range previous {
		if t, err := time.Parse(model.DateLayout, p.Date); err == nil {
			prevByMonthDay[t.Format("01-02")] = p
		}
	}
	var lastDate time.Time
	var lastDay *model.Day
	for i := range days {
		d := &days[i]
		t, err := time.Parse(model.DateLayout, d.Date)
		if err != nil {
			return &Problem{Rule: "date", Date: d.Date, Detail: "not YYYY-MM-DD"}
		}
		if t.Year() != year {
			return &Problem{Rule: "year", Date: d.Date, Detail: fmt.Sprintf("outside %d", year)}
		}
		if lastDay != nil && !t.After(lastDate) {
			return &Problem{Rule: "order", Date: d.Date, Detail: "dates must be strictly ascending"}
		}
		if err := checkClocks(d); err != nil {
			return err
		}
		if err := checkHijri(d); err != nil {
			return err
		}
		if lastDay != nil && t.Sub(lastDate) == 24*time.Hour {
			if err := checkHijriStep(lastDay, d); err != nil {
				return err
			}
		}
		if p, ok := prevByMonthDay[t.Format("01-02")]; ok {
			if err := checkDrift(d, &p); err != nil {
				return err
			}
		}
		lastDate, lastDay = t, d
	}
	return nil
}

func checkClocks(d *model.Day) error {
	clocks := d.Clocks()
	prev := -1
	for i, c := range clocks {
		mins, err := model.ClockMinutes(c)
		if err != nil {
			return &Problem{Rule: "clock", Date: d.Date, Detail: fmt.Sprintf("%s=%q", model.ClockNames[i], c)}
		}
		if mins <= prev {
			return &Problem{Rule: "prayer-order", Date: d.Date,
				Detail: fmt.Sprintf("%s (%s) not after %s", model.ClockNames[i], c, model.ClockNames[i-1])}
		}
		prev = mins
	}
	return nil
}

func checkHijri(d *model.Day) error {
	h := d.Hijri
	if h.Day < 1 || h.Day > 30 || h.Month < 1 || h.Month > 12 {
		return &Problem{Rule: "hijri", Date: d.Date, Detail: fmt.Sprintf("day=%d month=%d", h.Day, h.Month)}
	}
	if n, ok := model.HijriMonthNumber(h.MonthName); !ok || n != h.Month {
		return &Problem{Rule: "hijri", Date: d.Date, Detail: fmt.Sprintf("monthName %q != month %d", h.MonthName, h.Month)}
	}
	return nil
}

// checkHijriStep: ertesi gün ya aynı ayda +1 gündür ya da bir sonraki ayın 1'i (yıl devri dahil).
func checkHijriStep(prev, cur *model.Day) error {
	p, c := prev.Hijri, cur.Hijri
	sameMonthNext := c.Year == p.Year && c.Month == p.Month && c.Day == p.Day+1
	nextMonthFirst := c.Day == 1 && ((c.Year == p.Year && c.Month == p.Month+1) ||
		(p.Month == 12 && c.Month == 1 && c.Year == p.Year+1))
	if sameMonthNext || nextMonthFirst {
		return nil
	}
	return &Problem{Rule: "hijri-step", Date: cur.Date,
		Detail: fmt.Sprintf("%d.%d.%d after %d.%d.%d", c.Day, c.Month, c.Year, p.Day, p.Month, p.Year)}
}

func checkDrift(cur, prev *model.Day) error {
	cc, pc := cur.Clocks(), prev.Clocks()
	for i := range cc {
		a, errA := model.ClockMinutes(cc[i])
		b, errB := model.ClockMinutes(pc[i])
		if errA != nil || errB != nil {
			continue // önceki yılın bozuk değeri bu yılı reddettirmez; cur zaten checkClocks'tan geçti
		}
		if diff := a - b; diff > MaxYearOverYearDriftMinutes || diff < -MaxYearOverYearDriftMinutes {
			return &Problem{Rule: "drift", Date: cur.Date,
				Detail: fmt.Sprintf("%s %s vs previous year %s (%d min)", model.ClockNames[i], cc[i], pc[i], diff)}
		}
	}
	return nil
}

// ReligiousDays: tarihler yıl içinde ve azalmayan; ad boş değil; Hicri sağlam.
func ReligiousDays(list []model.ReligiousDay, year int) error {
	if len(list) == 0 {
		return &Problem{Rule: "nonempty", Detail: "no religious days"}
	}
	var last time.Time
	for i, r := range list {
		t, err := time.Parse(model.DateLayout, r.Date)
		if err != nil {
			return &Problem{Rule: "date", Date: r.Date, Detail: "not YYYY-MM-DD"}
		}
		if t.Year() != year {
			return &Problem{Rule: "year", Date: r.Date, Detail: fmt.Sprintf("outside %d", year)}
		}
		if i > 0 && t.Before(last) {
			return &Problem{Rule: "order", Date: r.Date, Detail: "dates must be non-decreasing"}
		}
		if r.Name == "" {
			return &Problem{Rule: "name", Date: r.Date, Detail: "empty name"}
		}
		if err := checkHijri(&model.Day{Date: r.Date, Hijri: r.Hijri}); err != nil {
			return err
		}
		last = t
	}
	return nil
}
