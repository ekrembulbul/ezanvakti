// Package assets, binary'ye gömülen statik verileri taşır.
package assets

import _ "embed"

// TRCitiesGeo: Türkiye ilçe merkezlerinin koordinatları (cmd/geocode-tr üretir, ODbL).
//
//go:embed tr_cities_geo.json
var TRCitiesGeo []byte
