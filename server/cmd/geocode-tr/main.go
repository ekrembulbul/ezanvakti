// Command geocode-tr, places/tr/cities.json'daki ilçeleri Nominatim ile koordinata
// çevirir ve assets/tr_cities_geo.json üretir. Tek seferlik araç; çıktı elle gözden
// geçirilip commit'lenir. Nominatim politikası: ≤ 1 istek/sn, tanımlayıcı User-Agent.
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"vakit/internal/geo"
	"vakit/internal/model"
)

const (
	nominatimURL    = "https://nominatim.openstreetmap.org/search"
	requestInterval = 1100 * time.Millisecond
	requestTimeout  = 30 * time.Second
)

func main() {
	in := flag.String("in", "data/places/tr/cities.json", "vakit sync places çıktısı")
	out := flag.String("out", "assets/tr_cities_geo.json", "üretilecek dosya (varsa üstüne devam eder)")
	contact := flag.String("contact", "", "Nominatim User-Agent için iletişim e-postası (zorunlu)")
	limit := flag.Int("limit", 0, "en çok N ilçe (0 = hepsi)")
	flag.Parse()
	if *contact == "" {
		fmt.Fprintln(os.Stderr, "--contact zorunlu (Nominatim kullanım politikası)")
		os.Exit(2)
	}
	if err := run(*in, *out, *contact, *limit); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run(inPath, outPath, contact string, limit int) error {
	raw, err := os.ReadFile(inPath)
	if err != nil {
		return fmt.Errorf("önce 'vakit sync places' çalıştır: %w", err)
	}
	var cities []model.CityWithState
	if err := json.Unmarshal(raw, &cities); err != nil {
		return err
	}
	file := geo.File{Source: "OpenStreetMap Nominatim (ODbL) — © OpenStreetMap contributors"}
	if existing, err := os.ReadFile(outPath); err == nil {
		_ = json.Unmarshal(existing, &file)
	}
	done := make(map[int]bool, len(file.Cities))
	for _, e := range file.Cities {
		done[e.CityID] = true
	}
	client := &http.Client{Timeout: requestTimeout}
	processed := 0
	for _, city := range cities {
		if done[city.ID] {
			continue
		}
		if limit > 0 && processed >= limit {
			break
		}
		entry, err := geocode(client, contact, city)
		if err != nil {
			return fmt.Errorf("%s/%s: %w", city.StateName, city.Name, err)
		}
		file.Cities = append(file.Cities, entry)
		processed++
		fmt.Printf("%4d/%d %-28s %-16s %8.4f %8.4f review=%v\n", len(file.Cities), len(cities), city.Name, city.StateName, entry.Latitude, entry.Longitude, entry.Review)
		file.GeneratedAt = time.Now().UTC().Format(time.RFC3339)
		if err := writeFile(outPath, file); err != nil { // her adımda yaz: kesilirse kaldığı yerden devam eder
			return err
		}
		time.Sleep(requestInterval)
	}
	review := 0
	for _, e := range file.Cities {
		if e.Review {
			review++
		}
	}
	fmt.Printf("bitti: %d ilçe, %d elle gözden geçirilecek (review=true)\n", len(file.Cities), review)
	return nil
}

func geocode(client *http.Client, contact string, city model.CityWithState) (geo.Entry, error) {
	results, err := search(client, contact, city)
	if err != nil {
		return geo.Entry{}, err
	}
	if len(results) == 0 && strings.Contains(city.Name, " ") {
		time.Sleep(requestInterval)
		compact := city
		compact.Name = compactName(city.Name)
		if results, err = search(client, contact, compact); err != nil {
			return geo.Entry{}, err
		}
	}
	picked, review := pickResult(results, city.Name, city.StateName)
	entry := geo.Entry{CityID: city.ID, Name: city.Name, StateName: city.StateName, DisplayName: picked.DisplayName, Review: review}
	if picked.Lat != "" {
		entry.Latitude, _ = strconv.ParseFloat(picked.Lat, 64)
		entry.Longitude, _ = strconv.ParseFloat(picked.Lon, 64)
	}
	return entry, nil
}

func writeFile(path string, file geo.File) error {
	data, err := json.MarshalIndent(file, "", " ")
	if err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

func search(client *http.Client, contact string, city model.CityWithState) ([]nominatimResult, error) {
	req, err := http.NewRequest(http.MethodGet, nominatimURL+"?"+buildQuery(city).Encode(), nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "vakit-api geocode-tr/1.0 ("+contact+")")
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("nominatim HTTP %d", resp.StatusCode)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return nil, err
	}
	var results []nominatimResult
	if err := json.Unmarshal(body, &results); err != nil {
		return nil, err
	}
	return results, nil
}
