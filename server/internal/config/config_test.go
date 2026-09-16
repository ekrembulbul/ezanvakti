package config

import (
	"log/slog"
	"testing"
	"time"
)

func env(m map[string]string) func(string) string {
	return func(k string) string { return m[k] }
}

func TestFromEnv_DefaultsToWebWhenNoCredentials(t *testing.T) {
	cfg, err := FromEnv(env(nil))
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Source != SourceWeb || cfg.DataDir != "./data" || cfg.Addr != "127.0.0.1:8080" ||
		len(cfg.EnabledCountries) != 1 || cfg.EnabledCountries[0] != 2 || cfg.SyncBatch != 150 ||
		cfg.SyncInterval != 500*time.Millisecond || cfg.LogLevel != slog.LevelInfo ||
		cfg.AwqatBaseURL != "https://awqatsalah.diyanet.gov.tr" {
		t.Fatalf("unexpected defaults: %+v", cfg)
	}
}

func TestFromEnv_DefaultsToAwqatWhenCredentialsPresent(t *testing.T) {
	cfg, err := FromEnv(env(map[string]string{"AWQAT_EMAIL": "a@b.c", "AWQAT_PASSWORD": "x"}))
	if err != nil || cfg.Source != SourceAwqat {
		t.Fatalf("cfg=%+v err=%v", cfg, err)
	}
}

func TestFromEnv_AwqatWithoutCredentialsIsError(t *testing.T) {
	if _, err := FromEnv(env(map[string]string{"VAKIT_SOURCE": "awqat"})); err == nil {
		t.Fatal("expected error")
	}
}

func TestFromEnv_ParsesLists_Durations_Levels(t *testing.T) {
	cfg, err := FromEnv(env(map[string]string{
		"VAKIT_ENABLED_COUNTRIES": "2, 1", "VAKIT_SYNC_BATCH": "20", "VAKIT_SYNC_INTERVAL": "2s",
		"VAKIT_LOG_LEVEL": "debug", "VAKIT_ADDR": "127.0.0.1:9090", "VAKIT_DATA_DIR": "/data",
	}))
	if err != nil {
		t.Fatal(err)
	}
	if len(cfg.EnabledCountries) != 2 || cfg.EnabledCountries[1] != 1 || cfg.SyncBatch != 20 ||
		cfg.SyncInterval != 2*time.Second || cfg.LogLevel != slog.LevelDebug || cfg.Addr != "127.0.0.1:9090" {
		t.Fatalf("%+v", cfg)
	}
	for _, bad := range []map[string]string{
		{"VAKIT_ENABLED_COUNTRIES": "2,x"}, {"VAKIT_SYNC_BATCH": "0"}, {"VAKIT_SYNC_INTERVAL": "soon"},
		{"VAKIT_LOG_LEVEL": "loud"}, {"VAKIT_SOURCE": "ftp"},
	} {
		if _, err := FromEnv(env(bad)); err == nil {
			t.Errorf("expected error for %v", bad)
		}
	}
}
