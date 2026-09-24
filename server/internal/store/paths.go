package store

import (
	"fmt"
	"time"
)

func CountriesPath() string { return "places/countries.json" }
func StatesPath(countryID int) string {
	return fmt.Sprintf("places/countries/%d/states.json", countryID)
}
func CitiesPath(stateID int) string { return fmt.Sprintf("places/states/%d/cities.json", stateID) }
func TRCitiesPath() string          { return "places/tr/cities.json" }
func PrayerTimesPath(cityID, year int) string {
	return fmt.Sprintf("prayer-times/%d/%d.json", cityID, year)
}
func ReligiousDaysPath(year int) string { return fmt.Sprintf("religious-days/%d.json", year) }
func DailyContentPath(t time.Time) string {
	return fmt.Sprintf("daily-content/%d/%d.json", t.Year(), t.YearDay())
}
func DBPath() string                      { return "state/vakit.db" }
func TokenPath() string                   { return "state/awqat_token.json" }
func CityYearKey(cityID, year int) string { return fmt.Sprintf("%d/%d", cityID, year) }
