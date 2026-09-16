// Package store, data/ dizinindeki JSON dosyalarını atomik yazar ve okur.
// Sync ile serve aynı dizini paylaşır; rename atomik olduğu için okuyucu
// yarım dosya görmez.
package store

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

type Store struct {
	Root string
}

func New(root string) *Store { return &Store{Root: root} }

func (s *Store) full(rel string) string {
	return filepath.Join(s.Root, filepath.FromSlash(rel))
}

// ETag, içeriğin SHA-256 özetinin ilk 16 hex karakterini tırnaklı döner (güçlü ETag).
func ETag(data []byte) string {
	sum := sha256.Sum256(data)
	return `"` + hex.EncodeToString(sum[:8]) + `"`
}

func (s *Store) WriteJSON(rel string, v any) error {
	data, err := json.Marshal(v)
	if err != nil {
		return fmt.Errorf("store: marshal %s: %w", rel, err)
	}
	return s.WriteRaw(rel, data)
}

// WriteRaw: geçici dosyaya yaz, fsync, 0644, sonra rename.
func (s *Store) WriteRaw(rel string, data []byte) error {
	full := s.full(rel)
	dir := filepath.Dir(full)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return fmt.Errorf("store: mkdir %s: %w", dir, err)
	}
	tmp, err := os.CreateTemp(dir, ".tmp-*")
	if err != nil {
		return fmt.Errorf("store: temp for %s: %w", rel, err)
	}
	tmpName := tmp.Name()
	fail := func(step string, err error) error {
		tmp.Close()
		os.Remove(tmpName)
		return fmt.Errorf("store: %s %s: %w", step, rel, err)
	}
	if _, err := tmp.Write(data); err != nil {
		return fail("write", err)
	}
	if err := tmp.Sync(); err != nil {
		return fail("sync", err)
	}
	if err := tmp.Close(); err != nil {
		os.Remove(tmpName)
		return fmt.Errorf("store: close %s: %w", rel, err)
	}
	if err := os.Chmod(tmpName, 0o644); err != nil {
		os.Remove(tmpName)
		return fmt.Errorf("store: chmod %s: %w", rel, err)
	}
	if err := os.Rename(tmpName, full); err != nil {
		os.Remove(tmpName)
		return fmt.Errorf("store: rename %s: %w", rel, err)
	}
	return nil
}

// Read dosyayı ve ETag'ini döner; dosya yoksa hata fs.ErrNotExist'i sarar.
func (s *Store) Read(rel string) ([]byte, string, error) {
	data, err := os.ReadFile(s.full(rel))
	if err != nil {
		return nil, "", err
	}
	return data, ETag(data), nil
}

func (s *Store) ReadJSON(rel string, v any) error {
	data, _, err := s.Read(rel)
	if err != nil {
		return err
	}
	if err := json.Unmarshal(data, v); err != nil {
		return fmt.Errorf("store: decode %s: %w", rel, err)
	}
	return nil
}

func (s *Store) Exists(rel string) bool {
	_, err := os.Stat(s.full(rel))
	return err == nil
}
