package main

import (
	"net/url"
	"regexp"
	"strings"

	"vakit/internal/model"
)

type nominatimResult struct {
	Lat         string  `json:"lat"`
	Lon         string  `json:"lon"`
	DisplayName string  `json:"display_name"`
	AddressType string  `json:"addresstype"`
	Importance  float64 `json:"importance"`
}

// Diyanet'in ayırıcı ekleri ("KEMER (B)", "ALTINYAYLA(S)") ve noktalama ("M.EREĞLİSİ").
var parenSuffix = regexp.MustCompile(`\s*\([^)]*\)\s*$`)

// nameAliases: Diyanet kısaltması → OSM'deki tam ad.
var nameAliases = map[string]string{
	"M.EREĞLİSİ":       "Marmaraereğlisi",
	"DOĞUBEYAZIT":      "Doğubayazıt",
	"KARADENİZ EREĞLİ": "Ereğli",
}

// typeRank: idari yerleşim türleri POI (benzinlik, okul) ve mahallelerden önce gelir;
// ilçe merkezi bir mahalle ("Bayat Mahallesi") değil kasaba/ilçe kaydıdır.
var typeRank = map[string]int{
	"town": 0, "municipality": 0, "administrative": 0, "city": 0, "district": 0, "county": 0,
	"village": 1, "hamlet": 1,
	"suburb": 2, "neighbourhood": 2, "quarter": 2,
}

func rankOf(r nominatimResult) int {
	if rank, ok := typeRank[r.AddressType]; ok {
		return rank
	}
	return 3 // POI ve diğerleri
}

// foldTR: Türkçe büyük İ/I kurallarıyla küçük harfe indirir (strings.ToLower I→i yapar, yanlış)
// ve OSM'nin şapkalı yazımını (Elâzığ, Hakkâri) Diyanet yazımına yaklaştırır.
func foldTR(s string) string {
	s = strings.NewReplacer("İ", "i", "I", "ı").Replace(s)
	s = strings.ToLower(s)
	return strings.NewReplacer("â", "a", "î", "i", "û", "u").Replace(s)
}

// foldASCII: karşılaştırma için Türkçe harfleri ASCII'ye indirir ve harf dışını atar —
// Diyanet "CUBUK", OSM "Çubuk" aynı anahtara düşer.
func foldASCII(s string) string {
	s = foldTR(s)
	s = strings.NewReplacer("ç", "c", "ğ", "g", "ı", "i", "ö", "o", "ş", "s", "ü", "u").Replace(s)
	var b strings.Builder
	for _, r := range s {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
			b.WriteRune(r)
		}
	}
	return b.String()
}

// searchName: Diyanet ilçe adından sorgu adı üretir (ek/alias düzeltmeleri).
func searchName(name string) string {
	if alias, ok := nameAliases[name]; ok {
		return alias
	}
	return strings.TrimSpace(parenSuffix.ReplaceAllString(name, ""))
}

// compactName: "BÜYÜK ORHAN" → "BÜYÜKORHAN" — OSM bazı ilçeleri tek kelime yazar.
func compactName(name string) string { return strings.ReplaceAll(name, " ", "") }

func buildQuery(city model.CityWithState) url.Values {
	return url.Values{
		"q":            {searchName(city.Name) + ", " + city.StateName + ", Türkiye"},
		"format":       {"jsonv2"},
		"limit":        {"10"},
		"countrycodes": {"tr"},
	}
}

// pickResult: il adını içeren sonuçlar arasından ilçe adını da içereni (idari tür öncelikli)
// seçer. Yalnız il eşleşirse ilkini review=true ile döner; hiç sonuç yoksa boş + review.
func pickResult(results []nominatimResult, cityName, stateName string) (nominatimResult, bool) {
	if len(results) == 0 {
		return nominatimResult{}, true
	}
	state := foldASCII(stateName)
	city := foldASCII(searchName(cityName))
	var stateOnly []nominatimResult
	var withCity []nominatimResult
	for _, r := range results {
		dn := foldASCII(r.DisplayName)
		if !strings.Contains(dn, state) {
			continue
		}
		stateOnly = append(stateOnly, r)
		if city != "" && strings.Contains(dn, city) {
			withCity = append(withCity, r)
		}
	}
	if len(withCity) > 0 {
		best := withCity[0]
		for _, r := range withCity[1:] {
			if rankOf(r) < rankOf(best) {
				best = r
			}
		}
		return best, false
	}
	if len(stateOnly) > 0 {
		return stateOnly[0], true
	}
	return results[0], true
}
