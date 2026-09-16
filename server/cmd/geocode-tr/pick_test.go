package main

import (
	"testing"

	"vakit/internal/model"
)

func TestFoldTR(t *testing.T) {
	if foldTR("İSTANBUL") != "istanbul" || foldTR("IĞDIR") != "ığdır" || foldTR("Şile") != "şile" {
		t.Fatalf("%q %q %q", foldTR("İSTANBUL"), foldTR("IĞDIR"), foldTR("Şile"))
	}
	if foldTR("Elâzığ") != foldTR("ELAZIĞ") || foldTR("Hakkâri") != foldTR("HAKKARİ") {
		t.Fatalf("circumflex must fold: %q vs %q", foldTR("Elâzığ"), foldTR("ELAZIĞ"))
	}
	if compactName("BÜYÜK ORHAN") != "BÜYÜKORHAN" {
		t.Fatal(compactName("BÜYÜK ORHAN"))
	}
}

func TestFoldASCII_MatchesDiyanetAsciiToOsmTurkish(t *testing.T) {
	cases := [][2]string{{"CUBUK", "Çubuk"}, {"KIGI", "Kiğı"}, {"KARAISALI", "Karaisalı"}, {"SEFERIHİSAR", "Seferihisar"},
		{"YENİSAR BADEMLİ", "Yenişarbademli"}, {"ALTINYAYLA(S)", "Altınyayla"}, {"KEMER (B)", "Kemer"}}
	for _, c := range cases {
		if foldASCII(searchName(c[0])) != foldASCII(c[1]) {
			t.Errorf("%q → %q, %q → %q", c[0], foldASCII(searchName(c[0])), c[1], foldASCII(c[1]))
		}
	}
	if searchName("M.EREĞLİSİ") != "Marmaraereğlisi" {
		t.Fatal(searchName("M.EREĞLİSİ"))
	}
}

func TestPickResult_PrefersResultContainingCityAndState(t *testing.T) {
	results := []nominatimResult{
		{Lat: "36.88", Lon: "30.70", DisplayName: "Antalya, Muratpaşa, Antalya, Akdeniz Bölgesi, Türkiye", AddressType: "city"},
		{Lat: "36.54", Lon: "31.99", DisplayName: "Alanya, Antalya, Akdeniz Bölgesi, 07400, Türkiye", AddressType: "town"},
	}
	got, review := pickResult(results, "ALANYA", "ANTALYA")
	if review || got.Lat != "36.54" {
		t.Fatalf("%+v review=%v", got, review)
	}
}

func TestPickResult_PrefersAdministrativeTypeOverPOI(t *testing.T) {
	results := []nominatimResult{
		{Lat: "1", Lon: "1", DisplayName: "TP Menzil Petrol, İpek Yolu, Edremit, Van, Türkiye", AddressType: "fuel"},
		{Lat: "2", Lon: "2", DisplayName: "Edremit, Van, Doğu Anadolu Bölgesi, Türkiye", AddressType: "town"},
	}
	got, review := pickResult(results, "EDREMİT (V)", "VAN")
	if review || got.Lat != "2" {
		t.Fatalf("%+v review=%v", got, review)
	}
}

func TestPickResult_StateOnlyMatchIsFlagged(t *testing.T) {
	results := []nominatimResult{{Lat: "1", Lon: "2", DisplayName: "Somewhere, Ankara, Türkiye", AddressType: "village"}}
	got, review := pickResult(results, "FOO", "ANKARA")
	if !review || got.Lat != "1" {
		t.Fatalf("%+v review=%v", got, review)
	}
	if _, review := pickResult(nil, "FOO", "İZMİR"); !review {
		t.Fatal("empty results must be flagged")
	}
	if _, review := pickResult(results, "FOO", "İZMİR"); !review {
		t.Fatal("no state match must be flagged")
	}
}

func TestBuildQuery_UsesSearchName(t *testing.T) {
	q := buildQuery(model.CityWithState{City: model.City{Name: "KEMER (B)"}, StateName: "BURDUR"})
	if q.Get("q") != "KEMER, BURDUR, Türkiye" || q.Get("countrycodes") != "tr" || q.Get("format") != "jsonv2" || q.Get("limit") != "10" {
		t.Fatalf("%v", q)
	}
}

func TestPickResult_PrefersTownOverNeighbourhoodOfProvinceCentre(t *testing.T) {
	results := []nominatimResult{
		{Lat: "40.55", Lon: "34.95", DisplayName: "Bayat Mahallesi, Çorum Merkez, Çorum, Türkiye", AddressType: "suburb"},
		{Lat: "40.64", Lon: "34.26", DisplayName: "Bayat, Çorum, Karadeniz Bölgesi, Türkiye", AddressType: "town"},
	}
	got, review := pickResult(results, "BAYAT", "ÇORUM")
	if review || got.Lat != "40.64" {
		t.Fatalf("%+v review=%v", got, review)
	}
}
