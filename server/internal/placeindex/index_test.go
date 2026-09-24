package placeindex

import (
	"testing"

	"vakit/internal/model"
)

func f64(v float64) *float64 { return &v }

func sampleCities() []model.CityWithState {
	mk := func(id int, name, state string, lat, lon float64) model.CityWithState {
		return model.CityWithState{City: model.City{ID: id, Name: name, StateID: 1, CountryID: 2, Latitude: f64(lat), Longitude: f64(lon)}, StateName: state}
	}
	return []model.CityWithState{
		mk(9541, "İSTANBUL", "İSTANBUL", 41.0082, 28.9784),
		mk(9547, "ŞİLE", "İSTANBUL", 41.1758, 29.6127),
		mk(9548, "SİLİVRİ", "İSTANBUL", 41.0733, 28.2467),
		mk(9206, "ANKARA", "ANKARA", 39.9334, 32.8597),
		mk(9212, "CUBUK", "ANKARA", 40.2386, 33.0322),
		mk(9800, "ŞİRVAN", "SİİRT", 38.0619, 42.0272),
		mk(9801, "SİİRT", "SİİRT", 37.9274, 41.9422),
		mk(9330, "BÜYÜK ORHAN", "BURSA", 39.7709, 28.8854),
		{City: model.City{ID: 9999, Name: "KOORDİNATSIZ", StateID: 1, CountryID: 2}, StateName: "SİİRT"},
	}
}

func sampleDisplayNames() map[int]string {
	return map[int]string{9212: "Çubuk", 9547: "Şile", 9541: "İstanbul"}
}

func sampleAliases() []Alias {
	return []Alias{{Name: "Kadıköy", CityID: 9541}, {Name: "Çankaya", CityID: 9206}}
}

func newIndex(t *testing.T) *Index {
	t.Helper()
	idx, err := Build(sampleCities(), sampleDisplayNames(), sampleAliases())
	if err != nil {
		t.Fatal(err)
	}
	return idx
}

func names(ms []Match) []string {
	out := make([]string, len(ms))
	for i, m := range ms {
		out[i] = m.DisplayName
	}
	return out
}

func TestSearch_PrefixOnDistrictBeatsContainsAndIsAccentInsensitive(t *testing.T) {
	idx := newIndex(t)
	got := idx.Search("sil", 10)
	if len(got) < 2 || got[0].DisplayName != "Silivri, İstanbul" && got[0].DisplayName != "Şile, İstanbul" {
		t.Fatalf("%v", names(got))
	}
	if got[0].ID == got[1].ID || (got[0].ID != 9547 && got[0].ID != 9548) || (got[1].ID != 9547 && got[1].ID != 9548) {
		t.Fatalf("expected Şile and Silivri first: %v", names(got))
	}
	for _, m := range got {
		if m.ID == 9800 {
			t.Fatal("Şirvan must not match prefix 'sil'")
		}
	}
}

func TestSearch_DisplayNamesUseOsmSpellingAndCentreMarker(t *testing.T) {
	idx := newIndex(t)
	got := idx.Search("cubuk", 5)
	if len(got) == 0 || got[0].ID != 9212 || got[0].DisplayName != "Çubuk, Ankara" || got[0].Name != "Çubuk" || got[0].StateName != "Ankara" {
		t.Fatalf("%+v", got)
	}
	got = idx.Search("çubuk", 5)
	if len(got) == 0 || got[0].ID != 9212 {
		t.Fatalf("Turkish input must match too: %v", names(got))
	}
	got = idx.Search("istanbul", 5)
	if len(got) == 0 || got[0].ID != 9541 || got[0].DisplayName != "İstanbul (Merkez)" {
		t.Fatalf("%v", names(got))
	}
	got = idx.Search("büyük orhan", 5)
	if len(got) == 0 || got[0].ID != 9330 || got[0].Name != "Büyük Orhan" {
		t.Fatalf("title case fallback: %+v", got)
	}
}

func TestSearch_MultiTokenAndStateName(t *testing.T) {
	idx := newIndex(t)
	got := idx.Search("şile istanbul", 5)
	if len(got) != 1 || got[0].ID != 9547 {
		t.Fatalf("%v", names(got))
	}
	got = idx.Search("siirt", 5)
	if len(got) != 3 || got[0].ID != 9801 { // il merkezi önce
		t.Fatalf("%v", names(got))
	}
}

func TestSearch_AliasResolvesToDiyanetRecord(t *testing.T) {
	idx := newIndex(t)
	got := idx.Search("kadık", 5)
	if len(got) != 1 || got[0].ID != 9541 || got[0].MatchedAlias != "Kadıköy" || got[0].DisplayName != "İstanbul (Merkez)" {
		t.Fatalf("%+v", got)
	}
	got = idx.Search("cankaya", 5)
	if len(got) != 1 || got[0].ID != 9206 || got[0].MatchedAlias != "Çankaya" {
		t.Fatalf("%+v", got)
	}
}

func TestSearch_EmptyQueryListsProvinceCentresPopularFirst(t *testing.T) {
	idx := newIndex(t)
	got := idx.Search("   ", 10)
	if len(got) != 3 || got[0].ID != 9541 || got[1].ID != 9206 || got[2].ID != 9801 {
		t.Fatalf("%v", names(got))
	}
	if len(idx.Search("", 2)) != 2 {
		t.Fatal("limit must apply")
	}
}

func TestSearch_NoMatchIsEmptyNotNil(t *testing.T) {
	idx := newIndex(t)
	if got := idx.Search("zzzz", 5); got == nil || len(got) != 0 {
		t.Fatalf("%v", got)
	}
}

func TestNearest_UsesHaversineAndSkipsEntriesWithoutCoordinates(t *testing.T) {
	idx := newIndex(t)
	m, km, ok := idx.Nearest(41.17, 29.60) // Şile yakını
	if !ok || m.ID != 9547 || km > 2 {
		t.Fatalf("%+v km=%v ok=%v", m, km, ok)
	}
	m, km, ok = idx.Nearest(37.95, 42.0)
	if !ok || m.ID != 9801 || km > 10 {
		t.Fatalf("%+v km=%v", m, km)
	}
	if _, _, ok := (&Index{}).Nearest(0, 0); ok {
		t.Fatal("empty index must report no match")
	}
}

func TestTitleTR(t *testing.T) {
	cases := map[string]string{"ŞİLE": "Şile", "BÜYÜK ORHAN": "Büyük Orhan", "IĞDIR": "Iğdır", "İSTANBUL": "İstanbul", "KEMER (B)": "Kemer", "M.EREĞLİSİ": "M.Ereğlisi"}
	for in, want := range cases {
		if got := titleTR(in); got != want {
			t.Errorf("titleTR(%q) = %q want %q", in, got, want)
		}
	}
}
