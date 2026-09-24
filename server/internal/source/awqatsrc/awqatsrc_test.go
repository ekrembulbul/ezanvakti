package awqatsrc

import (
	"testing"

	"vakit/internal/awqat"
)

func TestMapPrayerRecord_FullRecord(t *testing.T) {
	tz := 3
	r := awqat.PrayerRecord{Fajr: "06:11", Sunrise: "07:42", Dhuhr: "12:38", Asr: "15:01", Maghrib: "17:23", Isha: "18:49",
		AstronomicalSunrise: "07:49", AstronomicalSunset: "17:16", QiblaTime: "11:31",
		HijriDateShort: "5.5.1444", HijriDateLong: "5 Cemaziyelevvel 1444",
		GregorianDateShort: "29.11.2022", GreenwichMeanTimeZone: &tz}
	d, err := MapPrayerRecord(r)
	if err != nil {
		t.Fatal(err)
	}
	if d.Date != "2022-11-29" || d.Fajr != "06:11" || d.Isha != "18:49" || d.Hijri.Day != 5 || d.Hijri.Month != 5 ||
		d.Hijri.Year != 1444 || d.Hijri.MonthName != "Cemaziyelevvel" || *d.AstronomicalSunrise != "07:49" ||
		*d.AstronomicalSunset != "17:16" || *d.QiblaTime != "11:31" || *d.GMTOffset != 3 {
		t.Fatalf("%+v", d)
	}
}

func TestMapPrayerRecord_NormalisesSecondsAndFallsBackToShortHijri(t *testing.T) {
	r := awqat.PrayerRecord{Fajr: "06:11:00", Sunrise: "07:42:00", Dhuhr: "12:38:00", Asr: "15:01:00", Maghrib: "17:23:00", Isha: "18:49:00",
		HijriDateShort: "5.5.1444", GregorianDateLongIso8601: "2022-11-29T00:00:00.0000000+03:00"}
	d, err := MapPrayerRecord(r)
	if err != nil {
		t.Fatal(err)
	}
	if d.Date != "2022-11-29" || d.Fajr != "06:11" || d.Hijri.MonthName != "Cemaziyelevvel" || d.AstronomicalSunrise != nil || d.GMTOffset != nil {
		t.Fatalf("%+v", d)
	}
}

func TestMapPrayerRecord_Errors(t *testing.T) {
	base := awqat.PrayerRecord{Fajr: "06:11", Sunrise: "07:42", Dhuhr: "12:38", Asr: "15:01", Maghrib: "17:23", Isha: "18:49",
		HijriDateLong: "5 Cemaziyelevvel 1444", GregorianDateShort: "29.11.2022"}
	noDate := base
	noDate.GregorianDateShort = ""
	if _, err := MapPrayerRecord(noDate); err == nil {
		t.Error("missing date must fail")
	}
	noHijri := base
	noHijri.HijriDateLong = ""
	if _, err := MapPrayerRecord(noHijri); err == nil {
		t.Error("missing hijri must fail")
	}
	badClock := base
	badClock.Asr = "x"
	if _, err := MapPrayerRecord(badClock); err == nil {
		t.Error("bad clock must fail")
	}
}
