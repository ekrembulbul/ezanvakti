package store

import (
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestWriteJSON_WritesFileAtomicallyWithoutTempLeftovers(t *testing.T) {
	st := New(t.TempDir())
	if err := st.WriteJSON("prayer-times/9541/2026.json", map[string]int{"a": 1}); err != nil {
		t.Fatal(err)
	}
	data, etag, err := st.Read("prayer-times/9541/2026.json")
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != `{"a":1}` {
		t.Fatalf("data = %s", data)
	}
	if etag != ETag(data) || !strings.HasPrefix(etag, `"`) || len(etag) != 18 {
		t.Fatalf("etag = %q", etag)
	}
	entries, _ := os.ReadDir(filepath.Join(st.Root, "prayer-times", "9541"))
	for _, e := range entries {
		if strings.HasPrefix(e.Name(), ".tmp-") {
			t.Fatalf("temp file left behind: %s", e.Name())
		}
	}
}

func TestRead_MissingFileIsNotExist(t *testing.T) {
	st := New(t.TempDir())
	_, _, err := st.Read("prayer-times/1/2026.json")
	if !errors.Is(err, fs.ErrNotExist) {
		t.Fatalf("err = %v, want fs.ErrNotExist", err)
	}
	if st.Exists("prayer-times/1/2026.json") {
		t.Fatal("Exists must be false")
	}
}

func TestWriteJSON_OverwriteReplacesContent(t *testing.T) {
	st := New(t.TempDir())
	_ = st.WriteJSON("x.json", map[string]int{"v": 1})
	if err := st.WriteJSON("x.json", map[string]int{"v": 2}); err != nil {
		t.Fatal(err)
	}
	var got map[string]int
	if err := st.ReadJSON("x.json", &got); err != nil || got["v"] != 2 {
		t.Fatalf("got %v err %v", got, err)
	}
}

func TestETag_IsStableAndQuoted(t *testing.T) {
	a, b := ETag([]byte("abc")), ETag([]byte("abc"))
	if a != b || a != `"ba7816bf8f01cfea"` {
		t.Fatalf("etag = %s / %s", a, b)
	}
}

func TestPaths(t *testing.T) {
	cases := map[string]string{
		CountriesPath():             "places/countries.json",
		StatesPath(2):               "places/countries/2/states.json",
		CitiesPath(539):             "places/states/539/cities.json",
		TRCitiesPath():              "places/tr/cities.json",
		PrayerTimesPath(9541, 2026): "prayer-times/9541/2026.json",
		ReligiousDaysPath(2026):     "religious-days/2026.json",
		DailyContentPath(time.Date(2026, 9, 15, 0, 0, 0, 0, time.UTC)): "daily-content/2026/258.json",
		DBPath(): "state/vakit.db",
	}
	for got, want := range cases {
		if got != want {
			t.Errorf("path = %q want %q", got, want)
		}
	}
	if CityYearKey(9541, 2026) != "9541/2026" {
		t.Error("CityYearKey")
	}
}
