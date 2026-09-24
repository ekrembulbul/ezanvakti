package geo

import "testing"

func TestParse_BuildsIndexAndSkipsReviewFlaggedEntries(t *testing.T) {
	data := []byte(`{"source":"OSM","generatedAt":"2026-09-16","cities":[
	  {"cityId":9541,"name":"İSTANBUL","stateName":"İSTANBUL","latitude":41.0082,"longitude":28.9784,"displayName":"İstanbul","review":false},
	  {"cityId":9547,"name":"ŞİLE","stateName":"İSTANBUL","latitude":0,"longitude":0,"displayName":"","review":true}]}`)
	idx, err := Parse(data)
	if err != nil {
		t.Fatal(err)
	}
	if p, ok := idx[9541]; !ok || p.Latitude != 41.0082 || p.Longitude != 28.9784 {
		t.Fatalf("%+v", idx)
	}
	if _, ok := idx[9547]; ok {
		t.Fatal("review-flagged entries must not enter the index")
	}
}

func TestParse_RejectsInvalidCoordinates(t *testing.T) {
	if _, err := Parse([]byte(`{"cities":[{"cityId":1,"latitude":91,"longitude":0}]}`)); err == nil {
		t.Fatal("latitude 91 must fail")
	}
	if _, err := Parse([]byte(`not json`)); err == nil {
		t.Fatal("invalid json must fail")
	}
}

func TestLoad_EmbeddedAssetParses(t *testing.T) {
	if _, err := Load(); err != nil {
		t.Fatal(err)
	}
}
