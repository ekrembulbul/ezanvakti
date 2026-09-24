// Package assets, binary'ye gömülen statik verileri taşır.
package assets

import _ "embed"

// TRCitiesGeo: Türkiye ilçe merkezlerinin koordinatları (cmd/geocode-tr üretir, ODbL).
//
//go:embed tr_cities_geo.json
var TRCitiesGeo []byte

// TRPlaceAliases: Diyanet'te ayrı olmayan (büyükşehir merkez) ilçelerin Diyanet kaydına eşlemesi.
//
//go:embed tr_place_aliases.json
var TRPlaceAliases []byte
