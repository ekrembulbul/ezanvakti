// Package model, /v1 sözleşmesinin yayın şemalarını ve Diyanet metinlerini
// ayrıştıran yardımcıları içerir. Alan adları spec VAK.1 ile birebirdir.
package model

import "time"

const (
	SchemaVersion = 1
	SourceDiyanet = "diyanet"
	ViaWeb        = "web"
	DateLayout    = "2006-01-02"
)

type Country struct {
	ID      int    `json:"id"`
	Name    string `json:"name"`
	NameEn  string `json:"nameEn"`
	Enabled bool   `json:"enabled"`
}

type State struct {
	ID        int    `json:"id"`
	Name      string `json:"name"`
	CountryID int    `json:"countryId"`
}

type City struct {
	ID                 int      `json:"id"`
	Name               string   `json:"name"`
	StateID            int      `json:"stateId"`
	CountryID          int      `json:"countryId"`
	Latitude           *float64 `json:"latitude"`
	Longitude          *float64 `json:"longitude"`
	QiblaAngle         *float64 `json:"qiblaAngle"`         // gerçek kuzey (Diyanet geographicQiblaAngle)
	QiblaAngleMagnetic *float64 `json:"qiblaAngleMagnetic"` // manyetik (Diyanet qiblaAngle)
	DistanceToKaaba    *float64 `json:"distanceToKaaba"`    // km
}

type CityWithState struct {
	City
	StateName string `json:"stateName"`
}

// CityDetail, Diyanet CityDetail ucundan gelen kıble bilgisidir; City'ye işlenir.
type CityDetail struct {
	CityID             int
	QiblaAngle         *float64
	QiblaAngleMagnetic *float64
	DistanceToKaaba    *float64
}

type Hijri struct {
	Day       int    `json:"day"`
	Month     int    `json:"month"`
	Year      int    `json:"year"`
	MonthName string `json:"monthName"`
}

type Day struct {
	Date                string  `json:"date"` // YYYY-MM-DD
	Hijri               Hijri   `json:"hijri"`
	Fajr                string  `json:"fajr"`
	Sunrise             string  `json:"sunrise"`
	Dhuhr               string  `json:"dhuhr"`
	Asr                 string  `json:"asr"`
	Maghrib             string  `json:"maghrib"`
	Isha                string  `json:"isha"`
	AstronomicalSunrise *string `json:"astronomicalSunrise"`
	AstronomicalSunset  *string `json:"astronomicalSunset"`
	QiblaTime           *string `json:"qiblaTime"`
	GMTOffset           *int    `json:"gmtOffset"`
}

// Clocks, doğrulama ve karşılaştırma için altı vakti sabit sırayla döner.
func (d Day) Clocks() [6]string {
	return [6]string{d.Fajr, d.Sunrise, d.Dhuhr, d.Asr, d.Maghrib, d.Isha}
}

var ClockNames = [6]string{"fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha"}

type YearTimes struct {
	SchemaVersion int       `json:"schemaVersion"`
	Source        string    `json:"source"`
	Via           string    `json:"via,omitempty"`
	GeneratedAt   time.Time `json:"generatedAt"`
	CityID        int       `json:"cityId"`
	Year          int       `json:"year"`
	Complete      bool      `json:"complete"`
	Days          []Day     `json:"days"`
}

type ReligiousDay struct {
	ID        int    `json:"id"`
	Date      string `json:"date"`
	Name      string `json:"name"`
	IsSpecial bool   `json:"isSpecial"`
	Hijri     Hijri  `json:"hijri"`
}

type DailyContent struct {
	Date         string  `json:"date"`
	DayOfYear    int     `json:"dayOfYear"`
	Verse        string  `json:"verse"`
	VerseSource  string  `json:"verseSource"`
	Hadith       string  `json:"hadith"`
	HadithSource string  `json:"hadithSource"`
	Prayer       string  `json:"prayer"`
	PrayerSource *string `json:"prayerSource"`
}
