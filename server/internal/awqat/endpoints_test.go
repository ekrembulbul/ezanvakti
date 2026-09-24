package awqat

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

// Yanıtlar kılavuz PDF'indeki örneklerden (s.7–12) alınmıştır.
func endpointServer(t *testing.T) (*httptest.Server, *fakeDiyanet) {
	f := &fakeDiyanet{t: t, accessExp: time.Now().Add(time.Hour)}
	f.onCall = func(w http.ResponseWriter, r *http.Request, _ int32) {
		switch r.URL.Path {
		case "/api/Place/Countries":
			fmt.Fprint(w, `{"data":[{"id":1,"code":"NORTH CYPRUS","name":"KUZEY KIBRIS"},{"id":2,"code":"TURKEY","name":"TÜRKİYE"}],"success":true,"message":null}`)
		case "/api/Place/States/2":
			fmt.Fprint(w, `{"data":[{"id":500,"code":"ADANA","name":"ADANA"}],"success":true,"message":null}`)
		case "/api/Place/Cities/539":
			fmt.Fprint(w, `{"data":[{"id":9541,"code":"ISTANBUL","name":"İSTANBUL"}],"success":true,"message":null}`)
		case "/api/Place/CityDetail/17885":
			fmt.Fprint(w, `{"data":{"id":"17885","name":"DEVREKANİ","code":null,"geographicQiblaAngle":"164","distanceToKaaba":"2312","qiblaAngle":"159","city":"KASTAMONU","cityEn":null,"country":"TÜRKİYE","countryEn":"TÜRKİYE"},"success":true,"message":null}`)
		case "/api/PrayerTime/DateRange":
			var body map[string]any
			_ = json.NewDecoder(r.Body).Decode(&body)
			if r.Method != http.MethodPost || body["cityId"] != float64(9541) || body["startDate"] != "2026-01-01T00:00:00" || body["endDate"] != "2026-12-31T00:00:00" {
				t.Errorf("unexpected DateRange request: %s %v", r.Method, body)
			}
			fmt.Fprint(w, `{"data":[{"shapeMoonUrl":"http://x/r5.gif","fajr":"06:11","sunrise":"07:42","dhuhr":"12:38","asr":"15:01","maghrib":"17:23","isha":"18:49","astronomicalSunset":"17:16","astronomicalSunrise":"07:49","hijriDateShort":"5.5.1444","hijriDateShortIso8601":null,"hijriDateLong":"5 Cemaziyelevvel 1444","hijriDateLongIso8601":null,"qiblaTime":"11:31","gregorianDateShort":"29.11.2022","gregorianDateShortIso8601":"29.11.2022","gregorianDateLong":"29 Kasım 2022 Salı","gregorianDateLongIso8601":"2022-11-29T00:00:00.0000000+03:00","greenwichMeanTimeZone":3}],"success":true,"message":null}`)
		case "/api/IslamicReligiousDay/ByYear":
			if r.URL.Query().Get("year") != "2026" {
				t.Errorf("year query = %q", r.URL.Query().Get("year"))
			}
			fmt.Fprint(w, `{"data":[{"id":1,"religiousDayName":"Miraç Kandili","isSpecialReligiousDay":true,"gregorianDate":"2026-01-15T00:00:00","hijriDay":26,"hijriMonthName":"Recep","hijriMonth":7,"hijriYear":1447,"moonPhase":"sd5.gif","moonPhaseUrl":"https://x/sd5.gif","hijriDate":"26.7.1447","hijriDateLong":"26 Recep 1447"}],"success":true,"message":null}`)
		case "/api/DailyContent":
			fmt.Fprint(w, `{"data":{"id":333,"dayOfYear":333,"verse":"\"Gökleri...\"","verseSource":"(Şu'arâ, 42/29)","hadith":"“Küçüklerimize...”","hadithSource":"(Tirmizî, “Birr ”, 15)","pray":"\"Bizleri...\"","praySource":null},"success":true,"message":null}`)
		case "/api/DailyContent/VerseHadithAndPrayer":
			if r.URL.Query().Get("date") != "2026-09-16" {
				t.Errorf("date query = %q", r.URL.Query().Get("date"))
			}
			fmt.Fprint(w, `{"data":{"id":259,"dayOfYear":259,"verse":"v","verseSource":"vs","hadith":"h","hadithSource":"hs","pray":"p","praySource":"ps"},"success":true,"message":null}`)
		case "/api/Quota/My":
			fmt.Fprint(w, `{"data":{"daily":[{"endpoint":"DateRange","remaining":7}]},"success":true,"message":null}`)
		default:
			t.Errorf("unexpected path %s", r.URL.Path)
			w.WriteHeader(404)
		}
	}
	srv := httptest.NewServer(f.handler())
	t.Cleanup(srv.Close)
	return srv, f
}

func TestPlaces(t *testing.T) {
	srv, _ := endpointServer(t)
	c := newClient(t, srv)
	ctx := context.Background()
	countries, err := c.Countries(ctx)
	if err != nil || len(countries) != 2 || countries[1] != (Place{ID: 2, Code: "TURKEY", Name: "TÜRKİYE"}) {
		t.Fatalf("%v %v", countries, err)
	}
	states, err := c.States(ctx, 2)
	if err != nil || len(states) != 1 || states[0].ID != 500 {
		t.Fatalf("%v %v", states, err)
	}
	cities, err := c.Cities(ctx, 539)
	if err != nil || len(cities) != 1 || cities[0].Name != "İSTANBUL" {
		t.Fatalf("%v %v", cities, err)
	}
}

func TestCityDetail_ParsesStringNumbers(t *testing.T) {
	srv, _ := endpointServer(t)
	d, err := newClient(t, srv).CityDetail(context.Background(), 17885)
	if err != nil {
		t.Fatal(err)
	}
	if d.ID != 17885 || d.Name != "DEVREKANİ" || *d.GeographicQiblaAngle != 164 || *d.QiblaAngle != 159 || *d.DistanceToKaaba != 2312 || d.City != "KASTAMONU" {
		t.Fatalf("%+v", d)
	}
}

func TestDateRange(t *testing.T) {
	srv, _ := endpointServer(t)
	recs, err := newClient(t, srv).DateRange(context.Background(), 9541,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC), time.Date(2026, 12, 31, 0, 0, 0, 0, time.UTC))
	if err != nil || len(recs) != 1 {
		t.Fatalf("%v %v", recs, err)
	}
	r := recs[0]
	if r.Fajr != "06:11" || r.Isha != "18:49" || r.HijriDateLong != "5 Cemaziyelevvel 1444" || r.GregorianDateShort != "29.11.2022" ||
		r.GreenwichMeanTimeZone == nil || *r.GreenwichMeanTimeZone != 3 || r.QiblaTime != "11:31" || r.AstronomicalSunrise != "07:49" {
		t.Fatalf("%+v", r)
	}
}

func TestReligiousDaysByYear(t *testing.T) {
	srv, _ := endpointServer(t)
	days, err := newClient(t, srv).ReligiousDaysByYear(context.Background(), 2026)
	if err != nil || len(days) != 1 {
		t.Fatalf("%v %v", days, err)
	}
	d := days[0]
	if d.Name != "Miraç Kandili" || !d.IsSpecial || d.GregorianDate != "2026-01-15T00:00:00" || d.HijriDay != 26 || d.HijriMonth != 7 || d.HijriYear != 1447 || d.HijriMonthName != "Recep" {
		t.Fatalf("%+v", d)
	}
}

func TestDailyContent(t *testing.T) {
	srv, _ := endpointServer(t)
	c := newClient(t, srv)
	today, err := c.DailyContent(context.Background())
	if err != nil || today.DayOfYear != 333 || today.PraySource != nil || today.VerseSource != "(Şu'arâ, 42/29)" {
		t.Fatalf("%+v %v", today, err)
	}
	byDate, err := c.DailyContentByDate(context.Background(), time.Date(2026, 9, 16, 0, 0, 0, 0, time.UTC))
	if err != nil || byDate.DayOfYear != 259 || byDate.PraySource == nil || *byDate.PraySource != "ps" {
		t.Fatalf("%+v %v", byDate, err)
	}
}

func TestQuotaMy_ReturnsRawData(t *testing.T) {
	srv, _ := endpointServer(t)
	raw, err := newClient(t, srv).QuotaMy(context.Background())
	if err != nil || !json.Valid(raw) || len(raw) == 0 {
		t.Fatalf("%s %v", raw, err)
	}
}
