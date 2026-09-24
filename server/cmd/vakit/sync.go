package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log/slog"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

	"vakit/internal/awqat"
	"vakit/internal/config"
	"vakit/internal/db"
	"vakit/internal/geo"
	"vakit/internal/httpapi"
	"vakit/internal/jobs"
	"vakit/internal/source"
	"vakit/internal/source/awqatsrc"
	"vakit/internal/source/web"
	"vakit/internal/store"
)

const syncUsage = `vakit sync <iş> [flags]

İşler:
  places                                   ülke/il/ilçe listeleri (+ kıble, koordinat)
  prayer-times [--year Y]... [--batch N]   ilçe bazlı yıllık vakitler (varsayılan: bu yıl ve gelecek yıl)
  religious-days [--year Y]...             dinî günler
  daily-content [--ahead N]                günün ayet/hadis/duası (varsayılan 7 gün ileri)
  quota                                    Diyanet kota durumunu yazdırır (yalnız awqat kaynağı)
  verify                                   yayınlanmış dosyaları yeniden doğrular (ağ yok)
`

// intList: tekrarlanabilir ve virgülle ayrılabilir tam sayı flag'i (--year 2026 --year 2027,2028).
type intList []int

func (l *intList) String() string {
	parts := make([]string, len(*l))
	for i, v := range *l {
		parts[i] = strconv.Itoa(v)
	}
	return strings.Join(parts, ",")
}

func (l *intList) Set(v string) error {
	for _, part := range strings.Split(v, ",") {
		n, err := strconv.Atoi(strings.TrimSpace(part))
		if err != nil {
			return fmt.Errorf("%q is not an integer", part)
		}
		*l = append(*l, n)
	}
	return nil
}

func defaultYears(now time.Time) []int { return []int{now.Year(), now.Year() + 1} }

func runSync(args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		fmt.Fprint(stderr, syncUsage)
		return 2
	}
	job, rest := args[0], args[1:]
	cfg, err := config.FromEnv(os.Getenv)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 2
	}
	logger := httpapi.NewLogger(stdout, cfg.LogLevel)
	st := store.New(cfg.DataDir)

	if job == "verify" {
		problems, err := jobs.Verify(st, logger)
		if err != nil {
			fmt.Fprintln(stderr, err)
			return 1
		}
		if problems > 0 {
			return 1
		}
		return 0
	}

	src, client := buildSource(cfg, st, logger)
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	if job == "quota" {
		if client == nil {
			fmt.Fprintln(stderr, "kota bilgisi yalnız resmî API (VAKIT_SOURCE=awqat) kaynağında alınabilir")
			return 2
		}
		raw, err := client.QuotaMy(ctx)
		if err != nil {
			fmt.Fprintln(stderr, err)
			return 1
		}
		var pretty bytes.Buffer
		if err := json.Indent(&pretty, raw, "", "  "); err != nil {
			pretty.Write(raw)
		}
		fmt.Fprintln(stdout, pretty.String())
		return 0
	}

	database, err := db.Open(filepath.Join(st.Root, filepath.FromSlash(store.DBPath())))
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 1
	}
	defer database.Close()
	state, err := database.LoadSyncState()
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 1
	}
	geoIndex, err := geo.Load()
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 1
	}
	deps := jobs.Deps{Source: src, Store: st, State: state, Logger: logger, Now: time.Now, Geo: geoIndex}
	logger.Info("sync start", "job", job, "source", src.Name(), "data_dir", cfg.DataDir)

	var res jobs.Result
	var jobErr error
	switch job {
	case "places":
		res, jobErr = jobs.Places(ctx, deps, cfg.EnabledCountries)
	case "prayer-times":
		fs := flag.NewFlagSet("prayer-times", flag.ContinueOnError)
		fs.SetOutput(stderr)
		var years intList
		fs.Var(&years, "year", "yıl (tekrarlanabilir)")
		batch := fs.Int("batch", cfg.SyncBatch, "çalıştırma başına en çok çekim")
		if err := fs.Parse(rest); err != nil {
			return 2
		}
		if len(years) == 0 {
			years = defaultYears(time.Now())
		}
		cityIDs, err := jobs.EnabledCityIDs(st, cfg.EnabledCountries)
		if err != nil {
			fmt.Fprintln(stderr, err)
			return 1
		}
		res, jobErr = jobs.PrayerTimes(ctx, deps, cityIDs, years, *batch)
	case "religious-days":
		fs := flag.NewFlagSet("religious-days", flag.ContinueOnError)
		fs.SetOutput(stderr)
		var years intList
		fs.Var(&years, "year", "yıl (tekrarlanabilir)")
		if err := fs.Parse(rest); err != nil {
			return 2
		}
		if len(years) == 0 {
			years = defaultYears(time.Now())
		}
		res, jobErr = jobs.ReligiousDays(ctx, deps, years)
	case "daily-content":
		fs := flag.NewFlagSet("daily-content", flag.ContinueOnError)
		fs.SetOutput(stderr)
		ahead := fs.Int("ahead", 7, "kaç gün ileri")
		if err := fs.Parse(rest); err != nil {
			return 2
		}
		res, jobErr = jobs.DailyContent(ctx, deps, *ahead)
	default:
		fmt.Fprintf(stderr, "bilinmeyen iş: %q\n\n%s", job, syncUsage)
		return 2
	}

	if saveErr := database.SaveSyncState(state); saveErr != nil {
		logger.Error("sync state could not be saved", "err", saveErr.Error())
		if jobErr == nil {
			jobErr = saveErr
		}
	}
	logger.Info("sync end", "job", job, "result", res.String())
	if jobErr != nil {
		if errors.Is(jobErr, source.ErrQuotaExceeded) {
			logger.Warn("sync stopped: quota exhausted; next run continues", "job", job)
			return 0
		}
		fmt.Fprintln(stderr, jobErr)
		return 1
	}
	return 0
}

// buildSource, config'e göre kaynağı kurar; awqat seçildiyse istemciyi de döner (quota için).
func buildSource(cfg config.Config, st *store.Store, logger *slog.Logger) (source.Source, *awqat.Client) {
	if cfg.Source == config.SourceAwqat {
		client := awqat.New(cfg.AwqatBaseURL, awqat.Credentials{Email: cfg.AwqatEmail, Password: cfg.AwqatPassword},
			filepath.Join(st.Root, filepath.FromSlash(store.TokenPath())), logger, awqat.WithInterval(cfg.SyncInterval))
		return awqatsrc.New(client), client
	}
	if cfg.AwqatEmail == "" {
		logger.Warn("AWQAT_EMAIL not set; using web source (namazvakitleri.diyanet.gov.tr)")
	}
	return web.New(web.DefaultBaseURL, web.WithInterval(maxDuration(cfg.SyncInterval, time.Second))), nil
}

func maxDuration(a, b time.Duration) time.Duration {
	if a > b {
		return a
	}
	return b
}
