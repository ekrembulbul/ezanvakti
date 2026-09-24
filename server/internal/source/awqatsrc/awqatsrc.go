// Package awqatsrc, awqat istemcisini source.Source'a uyarlar.
package awqatsrc

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"vakit/internal/awqat"
	"vakit/internal/model"
	"vakit/internal/source"
)

type Source struct {
	c *awqat.Client
}

func New(c *awqat.Client) *Source { return &Source{c: c} }

func (s *Source) Name() string { return "awqat" }

// wrap, kota hatasını kaynak-bağımsız hataya çevirir; diğerlerini olduğu gibi geçirir.
func wrap(err error) error {
	if errors.Is(err, awqat.ErrQuotaExceeded) {
		return fmt.Errorf("%w: %v", source.ErrQuotaExceeded, err)
	}
	return err
}

func (s *Source) Countries(ctx context.Context) ([]model.Country, error) {
	places, err := s.c.Countries(ctx)
	if err != nil {
		return nil, wrap(err)
	}
	out := make([]model.Country, 0, len(places))
	for _, p := range places {
		out = append(out, model.Country{ID: p.ID, Name: p.Name, NameEn: p.Code})
	}
	return out, nil
}

func (s *Source) States(ctx context.Context, countryID int) ([]model.State, error) {
	places, err := s.c.States(ctx, countryID)
	if err != nil {
		return nil, wrap(err)
	}
	out := make([]model.State, 0, len(places))
	for _, p := range places {
		out = append(out, model.State{ID: p.ID, Name: p.Name, CountryID: countryID})
	}
	return out, nil
}

func (s *Source) Cities(ctx context.Context, stateID int) ([]model.City, error) {
	places, err := s.c.Cities(ctx, stateID)
	if err != nil {
		return nil, wrap(err)
	}
	out := make([]model.City, 0, len(places))
	for _, p := range places {
		out = append(out, model.City{ID: p.ID, Name: p.Name, StateID: stateID})
	}
	return out, nil
}

func (s *Source) CityDetail(ctx context.Context, cityID int) (*model.CityDetail, error) {
	d, err := s.c.CityDetail(ctx, cityID)
	if err != nil {
		return nil, wrap(err)
	}
	return &model.CityDetail{CityID: d.ID, QiblaAngle: d.GeographicQiblaAngle, QiblaAngleMagnetic: d.QiblaAngle,
		DistanceToKaaba: d.DistanceToKaaba}, nil
}

func (s *Source) PrayerTimes(ctx context.Context, cityID, year int) ([]model.Day, error) {
	start := time.Date(year, 1, 1, 0, 0, 0, 0, time.UTC)
	end := time.Date(year, 12, 31, 0, 0, 0, 0, time.UTC)
	recs, err := s.c.DateRange(ctx, cityID, start, end)
	if err != nil {
		return nil, wrap(err)
	}
	days := make([]model.Day, 0, len(recs))
	for i, r := range recs {
		d, err := MapPrayerRecord(r)
		if err != nil {
			return nil, fmt.Errorf("awqatsrc: city %d year %d record %d: %w", cityID, year, i, err)
		}
		days = append(days, d)
	}
	return days, nil
}

func (s *Source) ReligiousDays(ctx context.Context, year int) ([]model.ReligiousDay, error) {
	recs, err := s.c.ReligiousDaysByYear(ctx, year)
	if err != nil {
		return nil, wrap(err)
	}
	out := make([]model.ReligiousDay, 0, len(recs))
	for _, r := range recs {
		date, err := time.Parse("2006-01-02T15:04:05", r.GregorianDate)
		if err != nil {
			return nil, fmt.Errorf("awqatsrc: religious day %d date %q: %w", r.ID, r.GregorianDate, err)
		}
		monthName := r.HijriMonthName
		if n, ok := model.HijriMonthNumber(monthName); ok {
			monthName = model.HijriMonths[n-1]
		}
		out = append(out, model.ReligiousDay{ID: r.ID, Date: date.Format(model.DateLayout), Name: r.Name, IsSpecial: r.IsSpecial,
			Hijri: model.Hijri{Day: r.HijriDay, Month: r.HijriMonth, Year: r.HijriYear, MonthName: monthName}})
	}
	return out, nil
}

func (s *Source) DailyContent(ctx context.Context, date time.Time) (*model.DailyContent, error) {
	rec, err := s.c.DailyContentByDate(ctx, date)
	if err != nil {
		return nil, wrap(err)
	}
	return &model.DailyContent{Date: date.Format(model.DateLayout), DayOfYear: rec.DayOfYear, Verse: rec.Verse,
		VerseSource: rec.VerseSource, Hadith: rec.Hadith, HadithSource: rec.HadithSource, Prayer: rec.Pray,
		PrayerSource: rec.PraySource}, nil
}

// MapPrayerRecord, Diyanet kaydını yayın gününe çevirir. Tarih için gregorianDateShort
// ("29.11.2022"), yoksa ISO alanının ilk 10 karakteri; Hicri için long, yoksa short.
func MapPrayerRecord(r awqat.PrayerRecord) (model.Day, error) {
	date, err := parseGregorian(r)
	if err != nil {
		return model.Day{}, err
	}
	hijri, err := parseHijri(r)
	if err != nil {
		return model.Day{}, err
	}
	clocks := [6]string{r.Fajr, r.Sunrise, r.Dhuhr, r.Asr, r.Maghrib, r.Isha}
	for i := range clocks {
		norm, err := model.NormalizeClock(clocks[i])
		if err != nil {
			return model.Day{}, fmt.Errorf("%s: %w", model.ClockNames[i], err)
		}
		clocks[i] = norm
	}
	return model.Day{
		Date: date, Hijri: hijri,
		Fajr: clocks[0], Sunrise: clocks[1], Dhuhr: clocks[2], Asr: clocks[3], Maghrib: clocks[4], Isha: clocks[5],
		AstronomicalSunrise: optionalClock(r.AstronomicalSunrise),
		AstronomicalSunset:  optionalClock(r.AstronomicalSunset),
		QiblaTime:           optionalClock(r.QiblaTime),
		GMTOffset:           r.GreenwichMeanTimeZone,
	}, nil
}

func parseGregorian(r awqat.PrayerRecord) (string, error) {
	if s := strings.TrimSpace(r.GregorianDateShort); s != "" {
		t, err := time.Parse("02.01.2006", s)
		if err != nil {
			return "", fmt.Errorf("gregorianDateShort %q: %w", s, err)
		}
		return t.Format(model.DateLayout), nil
	}
	if s := r.GregorianDateLongIso8601; len(s) >= 10 {
		t, err := time.Parse(model.DateLayout, s[:10])
		if err != nil {
			return "", fmt.Errorf("gregorianDateLongIso8601 %q: %w", s, err)
		}
		return t.Format(model.DateLayout), nil
	}
	return "", errors.New("record has no gregorian date")
}

func parseHijri(r awqat.PrayerRecord) (model.Hijri, error) {
	if r.HijriDateLong != "" {
		return model.ParseHijriLong(r.HijriDateLong)
	}
	if r.HijriDateShort != "" {
		return model.ParseHijriShort(r.HijriDateShort)
	}
	return model.Hijri{}, errors.New("record has no hijri date")
}

func optionalClock(s string) *string {
	norm, err := model.NormalizeClock(s)
	if err != nil {
		return nil
	}
	return &norm
}
