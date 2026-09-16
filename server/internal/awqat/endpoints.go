package awqat

import (
	"context"
	"encoding/json"
	"fmt"
	"net/url"
	"strconv"
	"time"
)

const DateRangeTimeLayout = "2006-01-02T00:00:00"

type Place struct {
	ID   int
	Code string
	Name string
}

type rawPlace struct {
	ID   json.Number `json:"id"`
	Code string      `json:"code"`
	Name string      `json:"name"`
}

func (c *Client) places(ctx context.Context, path string) ([]Place, error) {
	var raw []rawPlace
	if err := c.Get(ctx, path, &raw); err != nil {
		return nil, err
	}
	out := make([]Place, 0, len(raw))
	for _, r := range raw {
		id, err := numberToInt(r.ID)
		if err != nil {
			return nil, fmt.Errorf("awqat: %s: id %q: %w", path, r.ID, err)
		}
		out = append(out, Place{ID: id, Code: r.Code, Name: r.Name})
	}
	return out, nil
}

func (c *Client) Countries(ctx context.Context) ([]Place, error) {
	return c.places(ctx, "/api/Place/Countries")
}

func (c *Client) States(ctx context.Context, countryID int) ([]Place, error) {
	return c.places(ctx, "/api/Place/States/"+strconv.Itoa(countryID))
}

func (c *Client) Cities(ctx context.Context, stateID int) ([]Place, error) {
	return c.places(ctx, "/api/Place/Cities/"+strconv.Itoa(stateID))
}

type CityDetail struct {
	ID                   int
	Name                 string
	GeographicQiblaAngle *float64 // gerçek kuzey
	QiblaAngle           *float64 // manyetik
	DistanceToKaaba      *float64 // km
	City                 string
	Country              string
}

func (c *Client) CityDetail(ctx context.Context, cityID int) (*CityDetail, error) {
	var raw struct {
		ID                   json.Number `json:"id"`
		Name                 string      `json:"name"`
		GeographicQiblaAngle json.Number `json:"geographicQiblaAngle"`
		QiblaAngle           json.Number `json:"qiblaAngle"`
		DistanceToKaaba      json.Number `json:"distanceToKaaba"`
		City                 string      `json:"city"`
		Country              string      `json:"country"`
	}
	path := "/api/Place/CityDetail/" + strconv.Itoa(cityID)
	if err := c.Get(ctx, path, &raw); err != nil {
		return nil, err
	}
	id, err := numberToInt(raw.ID)
	if err != nil {
		return nil, fmt.Errorf("awqat: %s: id: %w", path, err)
	}
	return &CityDetail{
		ID: id, Name: raw.Name, City: raw.City, Country: raw.Country,
		GeographicQiblaAngle: numberToFloatPtr(raw.GeographicQiblaAngle),
		QiblaAngle:           numberToFloatPtr(raw.QiblaAngle),
		DistanceToKaaba:      numberToFloatPtr(raw.DistanceToKaaba),
	}, nil
}

// PrayerRecord, Daily/DateRange kayıtlarının ham hâlidir; model dönüşümü awqatsrc'de.
type PrayerRecord struct {
	Fajr                     string `json:"fajr"`
	Sunrise                  string `json:"sunrise"`
	Dhuhr                    string `json:"dhuhr"`
	Asr                      string `json:"asr"`
	Maghrib                  string `json:"maghrib"`
	Isha                     string `json:"isha"`
	AstronomicalSunrise      string `json:"astronomicalSunrise"`
	AstronomicalSunset       string `json:"astronomicalSunset"`
	QiblaTime                string `json:"qiblaTime"`
	HijriDateShort           string `json:"hijriDateShort"`
	HijriDateLong            string `json:"hijriDateLong"`
	GregorianDateShort       string `json:"gregorianDateShort"`
	GregorianDateLongIso8601 string `json:"gregorianDateLongIso8601"`
	GreenwichMeanTimeZone    *int   `json:"greenwichMeanTimeZone"`
}

func (c *Client) DateRange(ctx context.Context, cityID int, start, end time.Time) ([]PrayerRecord, error) {
	body := map[string]any{
		"cityId":    cityID,
		"startDate": start.Format(DateRangeTimeLayout),
		"endDate":   end.Format(DateRangeTimeLayout),
	}
	var out []PrayerRecord
	if err := c.Post(ctx, "/api/PrayerTime/DateRange", body, &out); err != nil {
		return nil, err
	}
	return out, nil
}

type ReligiousDayRecord struct {
	ID             int    `json:"id"`
	Name           string `json:"religiousDayName"`
	IsSpecial      bool   `json:"isSpecialReligiousDay"`
	GregorianDate  string `json:"gregorianDate"`
	HijriDay       int    `json:"hijriDay"`
	HijriMonth     int    `json:"hijriMonth"`
	HijriYear      int    `json:"hijriYear"`
	HijriMonthName string `json:"hijriMonthName"`
}

func (c *Client) ReligiousDaysByYear(ctx context.Context, year int) ([]ReligiousDayRecord, error) {
	var out []ReligiousDayRecord
	if err := c.Get(ctx, "/api/IslamicReligiousDay/ByYear?year="+strconv.Itoa(year), &out); err != nil {
		return nil, err
	}
	return out, nil
}

type DailyContentRecord struct {
	ID           int     `json:"id"`
	DayOfYear    int     `json:"dayOfYear"`
	Verse        string  `json:"verse"`
	VerseSource  string  `json:"verseSource"`
	Hadith       string  `json:"hadith"`
	HadithSource string  `json:"hadithSource"`
	Pray         string  `json:"pray"`
	PraySource   *string `json:"praySource"`
}

func (c *Client) DailyContent(ctx context.Context) (*DailyContentRecord, error) {
	var out DailyContentRecord
	if err := c.Get(ctx, "/api/DailyContent", &out); err != nil {
		return nil, err
	}
	return &out, nil
}

func (c *Client) DailyContentByDate(ctx context.Context, date time.Time) (*DailyContentRecord, error) {
	q := url.Values{"date": {date.Format("2006-01-02")}}
	var out DailyContentRecord
	if err := c.Get(ctx, "/api/DailyContent/VerseHadithAndPrayer?"+q.Encode(), &out); err != nil {
		return nil, err
	}
	return &out, nil
}

// QuotaMy şekli belgelenmemiş; ham JSON döner, çağıran loglar/yazdırır.
func (c *Client) QuotaMy(ctx context.Context) (json.RawMessage, error) {
	var out json.RawMessage
	if err := c.Get(ctx, "/api/Quota/My?includeUnused=true", &out); err != nil {
		return nil, err
	}
	return out, nil
}

func numberToInt(n json.Number) (int, error) {
	if n == "" {
		return 0, fmt.Errorf("empty number")
	}
	v, err := n.Int64()
	if err != nil {
		return 0, err
	}
	return int(v), nil
}

func numberToFloatPtr(n json.Number) *float64 {
	if n == "" {
		return nil
	}
	v, err := n.Float64()
	if err != nil {
		return nil
	}
	return &v
}
