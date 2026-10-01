package jobs

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"vakit/internal/model"
	"vakit/internal/source"
	"vakit/internal/store"
)

// TurkeyZone, Diyanet içeriğinin gün sınırı: Türkiye 2016'dan beri sabit UTC+3.
// Çalışma imajında tzdata yok; LoadLocation kullanılmaz.
var TurkeyZone = time.FixedZone("TRT", 3*3600)

// dailyContentKeepDays, sunucuda tutulan en eski günün bugünden uzaklığı.
const dailyContentKeepDays = 7

// DailyContent, Türkiye günü için Diyanet'in tarihsiz günlük içeriğini yazar. Gelen
// dayOfYear bugünle eşleşmezse (Diyanet henüz yeni güne geçmediyse) yazmaz; cron saat
// başı yeniden dener. Her çalışmada 7 günden eski dosyaları siler.
func DailyContent(ctx context.Context, d Deps) (Result, error) {
	var res Result
	today := d.Now().In(TurkeyZone)
	defer func() { d.State.DailyContent.Days = pruneDailyContent(d, today) }()

	path := store.DailyContentPath(today)
	if d.Store.Exists(path) {
		res.Skipped++
		return res, nil
	}
	content, err := d.Source.DailyContent(ctx)
	switch {
	case errors.Is(err, source.ErrUnsupported):
		res.Skipped++
		return res, nil
	case err != nil:
		if stopOnQuota(err, &res) {
			return res, fmt.Errorf("daily-content: %w", err)
		}
		res.Errors++
		d.Logger.Warn("daily-content fetch failed", "err", err.Error())
		return res, nil
	}
	res.Fetched++
	if content == nil || content.Verse == "" || content.Hadith == "" || content.Prayer == "" {
		res.Rejected++
		d.Logger.Warn("daily-content incomplete; not written")
		return res, nil
	}
	if content.DayOfYear != today.YearDay() {
		res.Skipped++
		d.Logger.Warn("daily-content day mismatch; retry later", "got", content.DayOfYear, "want", today.YearDay())
		return res, nil
	}
	content.Date = today.Format(model.DateLayout)
	if err := d.Store.WriteJSON(path, content); err != nil {
		return res, err
	}
	res.Written++
	d.State.DailyContent.UpdatedAt = d.Now()
	d.Logger.Info("sync daily-content done", "result", res.String())
	return res, nil
}

// pruneDailyContent, bu ve geçen yılın klasörlerinde 7 günden eski dosyaları siler ve
// kalan gün sayısını döner. Okunamayan klasör (henüz yok) sessizce atlanır.
func pruneDailyContent(d Deps, today time.Time) int {
	start := time.Date(today.Year(), today.Month(), today.Day(), 0, 0, 0, 0, TurkeyZone)
	cutoff := start.AddDate(0, 0, -dailyContentKeepDays)
	kept := 0
	for _, year := range []int{today.Year() - 1, today.Year()} {
		dir := filepath.Join(d.Store.Root, "daily-content", strconv.Itoa(year))
		entries, err := os.ReadDir(dir)
		if err != nil {
			continue
		}
		for _, e := range entries {
			n, err := strconv.Atoi(strings.TrimSuffix(e.Name(), ".json"))
			if e.IsDir() || err != nil || !strings.HasSuffix(e.Name(), ".json") {
				continue
			}
			day := time.Date(year, 1, 1, 0, 0, 0, 0, TurkeyZone).AddDate(0, 0, n-1)
			if day.Before(cutoff) {
				if err := d.Store.Remove(store.DailyContentPath(day)); err != nil {
					d.Logger.Warn("daily-content prune failed", "day", day.Format(model.DateLayout), "err", err.Error())
					kept++
				}
				continue
			}
			kept++
		}
	}
	return kept
}
