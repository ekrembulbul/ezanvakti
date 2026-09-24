// Package db, sunucunun değişken durumunu tutan gömülü SQLite veritabanıdır.
// Yayın verisi (vakit, yer listeleri) dosyalarda kalır; burada sync durumu ve
// ileride cihaz token'ı, hesap gibi kayıtlar tutulur. Şema gömülü SQL
// migration'larıyla sürümlenir.
package db

import (
	"database/sql"
	"embed"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	_ "modernc.org/sqlite" // database/sql sürücüsü "sqlite"
)

//go:embed migrations/*.sql
var migrationFiles embed.FS

// Aynı dosyayı cron konteyneri (sync) ve sunucu (serve) paylaşır: WAL eşzamanlı
// okumaya izin verir, busy_timeout kilit çakışmasında bekler.
const dsnOptions = "?_pragma=journal_mode(WAL)&_pragma=busy_timeout(5000)&_pragma=foreign_keys(1)"

type DB struct {
	sql *sql.DB
}

// Open dosyayı (dizini de) oluşturur ve bekleyen migration'ları uygular.
func Open(path string) (*DB, error) {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return nil, fmt.Errorf("db: mkdir: %w", err)
	}
	conn, err := sql.Open("sqlite", "file:"+path+dsnOptions)
	if err != nil {
		return nil, fmt.Errorf("db: open: %w", err)
	}
	conn.SetMaxOpenConns(1) // SQLite tek yazıcı; tek bağlantı kilit yarışını önler
	d := &DB{sql: conn}
	if err := d.Migrate(); err != nil {
		conn.Close()
		return nil, err
	}
	return d, nil
}

func (d *DB) Close() error { return d.sql.Close() }

type migration struct {
	version int
	name    string
	body    string
}

func loadMigrations() ([]migration, error) {
	entries, err := migrationFiles.ReadDir("migrations")
	if err != nil {
		return nil, err
	}
	var out []migration
	for _, e := range entries {
		name := e.Name()
		numStr, _, ok := strings.Cut(name, "_")
		version, err := strconv.Atoi(numStr)
		if !ok || err != nil {
			return nil, fmt.Errorf("db: migration file %q must be NNNN_name.sql", name)
		}
		body, err := migrationFiles.ReadFile("migrations/" + name)
		if err != nil {
			return nil, err
		}
		out = append(out, migration{version: version, name: name, body: string(body)})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].version < out[j].version })
	return out, nil
}

// Migrate, schema_migrations tablosunda olmayan sürümleri sırayla ve her birini
// kendi transaction'ında uygular; tekrar çağrılması güvenlidir.
func (d *DB) Migrate() error {
	if _, err := d.sql.Exec(`CREATE TABLE IF NOT EXISTS schema_migrations (
		version INTEGER PRIMARY KEY, name TEXT NOT NULL, applied_at TEXT NOT NULL)`); err != nil {
		return fmt.Errorf("db: schema_migrations: %w", err)
	}
	current, err := d.SchemaVersion()
	if err != nil {
		return err
	}
	migrations, err := loadMigrations()
	if err != nil {
		return err
	}
	for _, m := range migrations {
		if m.version <= current {
			continue
		}
		tx, err := d.sql.Begin()
		if err != nil {
			return err
		}
		if _, err := tx.Exec(m.body); err != nil {
			tx.Rollback()
			return fmt.Errorf("db: migration %s: %w", m.name, err)
		}
		if _, err := tx.Exec(`INSERT INTO schema_migrations (version, name, applied_at) VALUES (?, ?, strftime('%Y-%m-%dT%H:%M:%fZ','now'))`,
			m.version, m.name); err != nil {
			tx.Rollback()
			return fmt.Errorf("db: record migration %s: %w", m.name, err)
		}
		if err := tx.Commit(); err != nil {
			return err
		}
	}
	return nil
}

// SchemaVersion uygulanmış en yüksek migration sürümünü döner (0 = hiç).
func (d *DB) SchemaVersion() (int, error) {
	var v sql.NullInt64
	if err := d.sql.QueryRow(`SELECT MAX(version) FROM schema_migrations`).Scan(&v); err != nil {
		return 0, fmt.Errorf("db: schema version: %w", err)
	}
	return int(v.Int64), nil
}
