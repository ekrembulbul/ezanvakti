// Package geo, ilçe koordinat dosyasını (K7) okur.
package geo

import (
	"encoding/json"
	"fmt"

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
