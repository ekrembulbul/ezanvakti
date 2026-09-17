// Package placeindex, Türkiye ilçe listesi üzerinde arama (metin → ilçe) ve
// çözümleme (koordinat → en yakın ilçe) yapar. Liste sunucuda tutulur; uygulama
// yalnız /v1/places/search ve /v1/places/resolve uçlarını çağırır.
package placeindex

import (
	"encoding/json"
	"fmt"
	"math"
	"sort"
	"strings"

	"vakit/internal/model"
)

// Alias: Diyanet'te ayrı kaydı olmayan ilçe (büyükşehir merkezi) → Diyanet kaydı.
type Alias struct {
	Name   string `json:"name"`
	CityID int    `json:"cityId"`
}

func LoadAliases(data []byte) ([]Alias, error) {
	var f struct {
		Aliases []Alias `json:"aliases"`
	}
	if err := json.Unmarshal(data, &f); err != nil {
		return nil, fmt.Errorf("placeindex: aliases: %w", err)
	}
	return f.Aliases, nil
}

// Match, arama ve çözümleme sonucudur; adlar ekranda gösterilecek yazımdadır.
type Match struct {
	ID                 int      `json:"id"`
	Name               string   `json:"name"`
	StateName          string   `json:"stateName"`
	DisplayName        string   `json:"displayName"`
	StateID            int      `json:"stateId"`
	CountryID          int      `json:"countryId"`
	IsCentre           bool     `json:"isCentre"`
	Latitude           *float64 `json:"latitude"`
	Longitude          *float64 `json:"longitude"`
	QiblaAngle         *float64 `json:"qiblaAngle"`
	QiblaAngleMagnetic *float64 `json:"qiblaAngleMagnetic"`
	DistanceToKaaba    *float64 `json:"distanceToKaaba"`
	MatchedAlias       string   `json:"matchedAlias,omitempty"`
}

type aliasEntry struct {
	display string
	key     string
}

type entry struct {
	match    Match
	nameKey  string
	rawKey   string
	stateKey string
	words    []string
	aliases  []aliasEntry
}

type Index struct {
	entries []entry
	centres []int // popüler sıra + alfabetik, entries index'i
}

// popularStates: boş aramada önce gösterilecek iller (nüfus sırası).
var popularStates = []string{"İSTANBUL", "ANKARA", "İZMİR", "BURSA", "ANTALYA", "ADANA", "KONYA", "GAZİANTEP",
	"ŞANLIURFA", "KOCAELİ", "MERSİN", "DİYARBAKIR", "HATAY", "MANİSA", "KAYSERİ", "SAMSUN", "BALIKESİR",
	"KAHRAMANMARAŞ", "VAN", "AYDIN"}

// Build indeksi kurar. displayNames: Diyanet ilçe id → ekran yazımı (OSM'den); yoksa
// Diyanet adı Türkçe başlık biçimine çevrilir.
func Build(cities []model.CityWithState, displayNames map[int]string, aliases []Alias) (*Index, error) {
	if len(cities) == 0 {
		return nil, fmt.Errorf("placeindex: empty city list")
	}
	byID := make(map[int]int, len(cities))
	idx := &Index{entries: make([]entry, 0, len(cities))}
	for _, c := range cities {
		name := titleTR(c.Name)
		if dn, ok := displayNames[c.ID]; ok && dn != "" {
			name = dn
		}
		state := titleTR(c.StateName)
		isCentre := foldASCII(c.Name) == foldASCII(c.StateName)
		m := Match{ID: c.ID, Name: name, StateName: state, StateID: c.StateID, CountryID: c.CountryID, IsCentre: isCentre,
			Latitude: c.Latitude, Longitude: c.Longitude, QiblaAngle: c.QiblaAngle, QiblaAngleMagnetic: c.QiblaAngleMagnetic,
			DistanceToKaaba: c.DistanceToKaaba}
		if isCentre {
			m.DisplayName = name + " (Merkez)"
		} else {
			m.DisplayName = name + ", " + state
		}
		e := entry{match: m, nameKey: foldASCII(name), rawKey: foldASCII(c.Name), stateKey: foldASCII(state)}
		for _, w := range strings.Fields(lowerTR(name)) {
			e.words = append(e.words, foldASCII(w))
		}
		byID[c.ID] = len(idx.entries)
		idx.entries = append(idx.entries, e)
	}
	for _, a := range aliases {
		i, ok := byID[a.CityID]
		if !ok {
			continue // alias hedefi listede yok; sessizce atla (liste güncellenince gelir)
		}
		idx.entries[i].aliases = append(idx.entries[i].aliases, aliasEntry{display: a.Name, key: foldASCII(a.Name)})
	}
	rank := map[string]int{}
	for i, s := range popularStates {
		rank[foldASCII(s)] = i
	}
	for i, e := range idx.entries {
		if e.match.IsCentre {
			idx.centres = append(idx.centres, i)
		}
	}
	sort.SliceStable(idx.centres, func(a, b int) bool {
		ra, oka := rank[idx.entries[idx.centres[a]].stateKey]
		rb, okb := rank[idx.entries[idx.centres[b]].stateKey]
		switch {
		case oka && okb:
			return ra < rb
		case oka != okb:
			return oka
		default:
			return idx.entries[idx.centres[a]].stateKey < idx.entries[idx.centres[b]].stateKey
		}
	})
	return idx, nil
}

type scored struct {
	match Match
	score float64
}

// Search: her sorgu parçası ilçe adı, il adı ya da eşanlamla eşleşmeli.
// Puan: ad öneki 3 · kelime öneki 2 · eşanlam öneki 2,5 · il öneki 1 · içerir 0,5/0,25.
func (i *Index) Search(q string, limit int) []Match {
	if limit <= 0 {
		limit = 10
	}
	tokens := make([]string, 0, 3)
	for _, t := range strings.Fields(q) {
		if k := foldASCII(t); k != "" {
			tokens = append(tokens, k)
		}
	}
	if len(tokens) == 0 {
		out := make([]Match, 0, limit)
		for _, ci := range i.centres {
			if len(out) >= limit {
				break
			}
			out = append(out, i.entries[ci].match)
		}
		return out
	}
	var results []scored
	for _, e := range i.entries {
		total, alias, ok := scoreEntry(e, tokens)
		if !ok {
			continue
		}
		m := e.match
		m.MatchedAlias = alias
		results = append(results, scored{match: m, score: total})
	}
	sort.SliceStable(results, func(a, b int) bool {
		if results[a].score != results[b].score {
			return results[a].score > results[b].score
		}
		if results[a].match.IsCentre != results[b].match.IsCentre {
			return results[a].match.IsCentre
		}
		return results[a].match.DisplayName < results[b].match.DisplayName
	})
	out := make([]Match, 0, limit)
	for _, r := range results {
		if len(out) >= limit {
			break
		}
		out = append(out, r.match)
	}
	return out
}

func scoreEntry(e entry, tokens []string) (float64, string, bool) {
	total := 0.0
	alias := ""
	for _, tok := range tokens {
		best := 0.0
		switch {
		case strings.HasPrefix(e.nameKey, tok) || strings.HasPrefix(e.rawKey, tok):
			best = 3
		}
		for _, w := range e.words {
			if strings.HasPrefix(w, tok) {
				best = math.Max(best, 2)
			}
		}
		for _, a := range e.aliases {
			if strings.HasPrefix(a.key, tok) {
				if 2.5 > best {
					best = 2.5
					alias = a.display
				}
			}
		}
		if strings.HasPrefix(e.stateKey, tok) {
			best = math.Max(best, 1)
		}
		if best == 0 {
			if strings.Contains(e.nameKey, tok) || strings.Contains(e.rawKey, tok) {
				best = 0.5
			} else if strings.Contains(e.stateKey, tok) {
				best = 0.25
			}
		}
		if best == 0 {
			return 0, "", false
		}
		total += best
	}
	return total, alias, true
}

const earthRadiusKm = 6371.0

func haversineKm(lat1, lon1, lat2, lon2 float64) float64 {
	toRad := func(d float64) float64 { return d * math.Pi / 180 }
	dLat := toRad(lat2 - lat1)
	dLon := toRad(lon2 - lon1)
	a := math.Sin(dLat/2)*math.Sin(dLat/2) + math.Cos(toRad(lat1))*math.Cos(toRad(lat2))*math.Sin(dLon/2)*math.Sin(dLon/2)
	return 2 * earthRadiusKm * math.Asin(math.Sqrt(a))
}

// Nearest koordinatı olan en yakın ilçeyi ve uzaklığı (km) döner.
func (i *Index) Nearest(lat, lon float64) (Match, float64, bool) {
	best, bestKm, found := Match{}, math.Inf(1), false
	for _, e := range i.entries {
		if e.match.Latitude == nil || e.match.Longitude == nil {
			continue
		}
		km := haversineKm(lat, lon, *e.match.Latitude, *e.match.Longitude)
		if km < bestKm {
			best, bestKm, found = e.match, km, true
		}
	}
	return best, bestKm, found
}
