package placeindex

import (
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sync"
	"time"

	"vakit/assets"
	"vakit/internal/geo"
	"vakit/internal/model"
	"vakit/internal/store"
)

var ErrNotReady = errors.New("placeindex: place list not synced yet")

// Cache, ilçe listesi dosyası değiştiğinde (haftalık sync) indeksi yeniden kurar.
// Görünen adlar ve eşanlamlar binary'ye gömülüdür, bir kez yüklenir.
type Cache struct {
	st *store.Store

	mu      sync.Mutex
	mtime   time.Time
	idx     *Index
	names   map[int]string
	aliases []Alias
	loaded  bool
}

func NewCache(st *store.Store) *Cache { return &Cache{st: st} }

// SameName: Diyanet adı ile OSM yazımı aynı arama anahtarına düşüyorsa eşit sayılır.
func SameName(diyanet, osm string) bool { return foldASCII(diyanet) == foldASCII(osm) }

func (c *Cache) loadStatic() error {
	if c.loaded {
		return nil
	}
	file, err := geo.LoadFile()
	if err != nil {
		return err
	}
	c.names = file.DisplayNames(SameName)
	aliases, err := LoadAliases(assets.TRPlaceAliases)
	if err != nil {
		return err
	}
	c.aliases = aliases
	c.loaded = true
	return nil
}

// Get güncel indeksi döner; liste dosyası yoksa ErrNotReady.
func (c *Cache) Get() (*Index, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	path := filepath.Join(c.st.Root, filepath.FromSlash(store.TRCitiesPath()))
	info, err := os.Stat(path)
	if errors.Is(err, fs.ErrNotExist) {
		return nil, ErrNotReady
	}
	if err != nil {
		return nil, fmt.Errorf("placeindex: stat: %w", err)
	}
	if c.idx != nil && info.ModTime().Equal(c.mtime) {
		return c.idx, nil
	}
	if err := c.loadStatic(); err != nil {
		return nil, err
	}
	var cities []model.CityWithState
	if err := c.st.ReadJSON(store.TRCitiesPath(), &cities); err != nil {
		return nil, fmt.Errorf("placeindex: read cities: %w", err)
	}
	idx, err := Build(cities, c.names, c.aliases)
	if err != nil {
		return nil, err
	}
	c.idx, c.mtime = idx, info.ModTime()
	return idx, nil
}
