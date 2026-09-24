package model

import (
	"encoding/json"
	"strings"
	"testing"
	"time"
)

func TestHijriMonthNumber_AcceptsDiyanetSpellings(t *testing.T) {
	cases := map[string]int{
		"Muharrem": 1, "Safer": 2, "Rebiulevvel": 3, "Rebiülevvel": 3, "Rebiulahir": 4, "Rebiülahir": 4,
		"Cemaziyelevvel": 5, "Cemaziyelahir": 6, "Recep": 7, "Şaban": 8, "Ramazan": 9, "Şevval": 10,
		"Zilkade": 11, "Zilkâde": 11, "Zilhicce": 12, "zilhicce": 12,
	}
	for name, want := range cases {
		got, ok := HijriMonthNumber(name)
		if !ok || got != want {
			t.Errorf("HijriMonthNumber(%q) = %d,%v; want %d,true", name, got, ok, want)
		}
	}
	if _, ok := HijriMonthNumber("Bilinmeyen"); ok {
		t.Error("unknown month must not resolve")
	}
}

func TestParseHijriLong(t *testing.T) {
	got, err := ParseHijriLong("4 Rebiulahir 1448")
	if err != nil {
		t.Fatal(err)
	}
	want := Hijri{Day: 4, Month: 4, Year: 1448, MonthName: "Rebiulahir"}
	if got != want {
		t.Fatalf("got %+v want %+v", got, want)
	}
	for _, bad := range []string{"", "Rebiulahir 1448", "4 Foo 1448", "x Rebiulahir 1448", "31 Recep 1448"} {
		if _, err := ParseHijriLong(bad); err == nil {
			t.Errorf("ParseHijriLong(%q) should fail", bad)
		}
	}
}

func TestParseHijriShort_UsesCanonicalMonthName(t *testing.T) {
	got, err := ParseHijriShort("5.5.1444")
	if err != nil {
		t.Fatal(err)
	}
	want := Hijri{Day: 5, Month: 5, Year: 1444, MonthName: "Cemaziyelevvel"}
	if got != want {
		t.Fatalf("got %+v want %+v", got, want)
	}
	if _, err := ParseHijriShort("5.13.1444"); err == nil {
		t.Error("month 13 must fail")
	}
}

func TestParseTurkishDate(t *testing.T) {
	cases := map[string]string{
		"15 Eylül 2026 Salı":  "2026-09-15",
		"01 Ocak 2027 Cuma":   "2027-01-01",
		"31 Aralık 2027 Cuma": "2027-12-31",
		"3 Mayıs 2027":        "2027-05-03",
	}
	for in, want := range cases {
		got, err := ParseTurkishDate(in)
		if err != nil {
			t.Errorf("ParseTurkishDate(%q): %v", in, err)
			continue
		}
		if got.Format(DateLayout) != want {
			t.Errorf("ParseTurkishDate(%q) = %s want %s", in, got.Format(DateLayout), want)
		}
	}
	for _, bad := range []string{"15 September 2026", "Eylül 2026", "32 Eylül 2026"} {
		if _, err := ParseTurkishDate(bad); err == nil {
			t.Errorf("ParseTurkishDate(%q) should fail", bad)
		}
	}
}

func TestClockMinutes(t *testing.T) {
	if got, _ := ClockMinutes("05:11"); got != 311 {
		t.Fatalf("05:11 = %d want 311", got)
	}
	if got, _ := ClockMinutes("5:11"); got != 311 {
		t.Fatalf("5:11 = %d want 311", got)
	}
	if got, _ := ClockMinutes("19:22:00"); got != 1162 {
		t.Fatalf("19:22:00 = %d want 1162", got)
	}
	for _, bad := range []string{"", "25:00", "12:60", "ab:cd", "12"} {
		if _, err := ClockMinutes(bad); err == nil {
			t.Errorf("ClockMinutes(%q) should fail", bad)
		}
	}
}

func TestNormalizeClock(t *testing.T) {
	if got, _ := NormalizeClock("06:11:00"); got != "06:11" {
		t.Fatalf("got %q", got)
	}
	if got, _ := NormalizeClock("5:11"); got != "05:11" {
		t.Fatalf("got %q", got)
	}
}

func TestYearTimes_JSONFieldNamesMatchContract(t *testing.T) {
	yt := YearTimes{SchemaVersion: SchemaVersion, Source: SourceDiyanet, CityID: 9541, Year: 2026,
		GeneratedAt: time.Date(2026, 9, 15, 20, 0, 0, 0, time.UTC),
		Days: []Day{{Date: "2026-09-15", Hijri: Hijri{Day: 4, Month: 4, Year: 1448, MonthName: "Rebiulahir"},
			Fajr: "05:11", Sunrise: "06:37", Dhuhr: "13:04", Asr: "16:35", Maghrib: "19:22", Isha: "20:43"}}}
	b, err := json.Marshal(yt)
	if err != nil {
		t.Fatal(err)
	}
	for _, key := range []string{`"schemaVersion":1`, `"source":"diyanet"`, `"cityId":9541`, `"complete":false`,
		`"hijri":{"day":4,"month":4,"year":1448,"monthName":"Rebiulahir"}`, `"maghrib":"19:22"`,
		`"astronomicalSunrise":null`, `"qiblaTime":null`, `"gmtOffset":null`} {
		if !strings.Contains(string(b), key) {
			t.Errorf("JSON missing %s in %s", key, b)
		}
	}
	if strings.Contains(string(b), `"via"`) {
		t.Error(`"via" must be omitted when empty`)
	}
}
