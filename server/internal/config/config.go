// Package config, ortam değişkenlerini Config'e çevirir (spec VAK.8).
package config

import (
	"fmt"
	"log/slog"
	"strconv"
	"strings"
	"time"
)

const (
	SourceAwqat = "awqat"
	SourceWeb   = "web"

	defaultBaseURL  = "https://awqatsalah.diyanet.gov.tr"
	defaultDataDir  = "./data"
	defaultAddr     = "127.0.0.1:8080"
	defaultBatch    = 150
	defaultInterval = 500 * time.Millisecond
	turkeyCountryID = 2
)

type Config struct {
	AwqatEmail       string
	AwqatPassword    string
	AwqatBaseURL     string
	Source           string
	DataDir          string
	Addr             string
	EnabledCountries []int
	SyncBatch        int
	SyncInterval     time.Duration
	LogLevel         slog.Level
}

func FromEnv(getenv func(string) string) (Config, error) {
	cfg := Config{
		AwqatEmail:       getenv("AWQAT_EMAIL"),
		AwqatPassword:    getenv("AWQAT_PASSWORD"),
		AwqatBaseURL:     orDefault(getenv("AWQAT_BASE_URL"), defaultBaseURL),
		DataDir:          orDefault(getenv("VAKIT_DATA_DIR"), defaultDataDir),
		Addr:             orDefault(getenv("VAKIT_ADDR"), defaultAddr),
		EnabledCountries: []int{turkeyCountryID},
		SyncBatch:        defaultBatch,
		SyncInterval:     defaultInterval,
		LogLevel:         slog.LevelInfo,
	}
	hasCreds := cfg.AwqatEmail != "" && cfg.AwqatPassword != ""
	switch src := getenv("VAKIT_SOURCE"); src {
	case "":
		cfg.Source = SourceWeb
		if hasCreds {
			cfg.Source = SourceAwqat
		}
	case SourceAwqat:
		if !hasCreds {
			return cfg, fmt.Errorf("config: VAKIT_SOURCE=awqat requires AWQAT_EMAIL and AWQAT_PASSWORD")
		}
		cfg.Source = SourceAwqat
	case SourceWeb:
		cfg.Source = SourceWeb
	default:
		return cfg, fmt.Errorf("config: VAKIT_SOURCE=%q must be awqat or web", src)
	}
	if v := getenv("VAKIT_ENABLED_COUNTRIES"); v != "" {
		ids, err := parseIntList(v)
		if err != nil {
			return cfg, fmt.Errorf("config: VAKIT_ENABLED_COUNTRIES: %w", err)
		}
		cfg.EnabledCountries = ids
	}
	if v := getenv("VAKIT_SYNC_BATCH"); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil || n < 1 {
			return cfg, fmt.Errorf("config: VAKIT_SYNC_BATCH=%q must be a positive integer", v)
		}
		cfg.SyncBatch = n
	}
	if v := getenv("VAKIT_SYNC_INTERVAL"); v != "" {
		d, err := time.ParseDuration(v)
		if err != nil || d < 0 {
			return cfg, fmt.Errorf("config: VAKIT_SYNC_INTERVAL=%q must be a duration like 500ms", v)
		}
		cfg.SyncInterval = d
	}
	if v := getenv("VAKIT_LOG_LEVEL"); v != "" {
		var lvl slog.Level
		if err := lvl.UnmarshalText([]byte(strings.ToUpper(v))); err != nil {
			return cfg, fmt.Errorf("config: VAKIT_LOG_LEVEL=%q must be debug|info|warn|error", v)
		}
		cfg.LogLevel = lvl
	}
	return cfg, nil
}

func orDefault(v, def string) string {
	if strings.TrimSpace(v) == "" {
		return def
	}
	return v
}

func parseIntList(v string) ([]int, error) {
	var out []int
	for _, part := range strings.Split(v, ",") {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		n, err := strconv.Atoi(part)
		if err != nil {
			return nil, fmt.Errorf("%q is not an integer", part)
		}
		out = append(out, n)
	}
	if len(out) == 0 {
		return nil, fmt.Errorf("empty list")
	}
	return out, nil
}
