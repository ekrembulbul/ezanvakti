// Package geo, ilçe koordinat dosyasını (K7) okur.
package geo

import (
	"encoding/json"
	"fmt"
	"strings"

	"vakit/assets"
)

type Point struct {
	Latitude  float64
	Longitude float64
}

type Index map[int]Point

type Entry struct {
	CityID      int     `json:"cityId"`
	Name        string  `json:"name"`
	StateName   string  `json:"stateName"`
	Latitude    float64 `json:"latitude"`
	Longitude   float64 `json:"longitude"`
	DisplayName string  `json:"displayName"`
	Review      bool    `json:"review"` // elle doğrulanmadı → yayına girmez
}

type File struct {
	Source      string  `json:"source"`
	GeneratedAt string  `json:"generatedAt"`
	Cities      []Entry `json:"cities"`
}

func Parse(data []byte) (Index, error) {
	var f File
	if err := json.Unmarshal(data, &f); err != nil {
		return nil, fmt.Errorf("geo: decode: %w", err)
	}
	idx := make(Index, len(f.Cities))
	for _, e := range f.Cities {
		if e.Review {
			continue
		}
		if e.Latitude < -90 || e.Latitude > 90 || e.Longitude < -180 || e.Longitude > 180 {
			return nil, fmt.Errorf("geo: city %d has invalid coordinates %v,%v", e.CityID, e.Latitude, e.Longitude)
		}
		idx[e.CityID] = Point{Latitude: e.Latitude, Longitude: e.Longitude}
	}
	return idx, nil
}

func Load() (Index, error) { return Parse(assets.TRCitiesGeo) }

// LoadFile gömülü koordinat dosyasının tamamını (görünen adlar dahil) döner.
func LoadFile() (File, error) {
	var f File
	if err := json.Unmarshal(assets.TRCitiesGeo, &f); err != nil {
		return File{}, fmt.Errorf("geo: decode: %w", err)
	}
	return f, nil
}

// DisplayNames: ilçe id → OSM'deki yazım (displayName'in ilk bileşeni, ör. "Çubuk").
// Yalnız Diyanet adıyla aynı ada katlanan kayıtlar kullanılır; farklıysa Diyanet adı kalır.
func (f File) DisplayNames(sameName func(diyanet, osm string) bool) map[int]string {
	out := make(map[int]string, len(f.Cities))
	for _, e := range f.Cities {
		if e.Review || e.DisplayName == "" {
			continue
		}
		first := e.DisplayName
		if i := strings.Index(first, ","); i >= 0 {
			first = first[:i]
		}
		first = strings.TrimSpace(first)
		if first != "" && sameName(e.Name, first) {
			out[e.CityID] = first
		}
	}
	return out
}
