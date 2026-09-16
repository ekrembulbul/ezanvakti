package jobs

import (
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"vakit/internal/model"
	"vakit/internal/store"
	"vakit/internal/validate"
)

// Verify, yayınlanmış vakit ve dinî gün dosyalarını ağ kullanmadan yeniden doğrular;
// sorun sayısını döner (cron çıkış kodu için).
func Verify(st *store.Store, logger *slog.Logger) (int, error) {
	problems := 0
	root := filepath.Join(st.Root, "prayer-times")
	err := filepath.WalkDir(root, func(path string, entry os.DirEntry, err error) error {
		if err != nil {
			if os.IsNotExist(err) {
				return nil
			}
			return err
		}
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".json") {
			return nil
		}
		rel, _ := filepath.Rel(st.Root, path)
		var yt model.YearTimes
		if err := st.ReadJSON(filepath.ToSlash(rel), &yt); err != nil {
			problems++
			logger.Error("verify: unreadable", "file", rel, "err", err.Error())
			return nil
		}
		if verr := validate.YearTimes(yt.Days, yt.Year, nil); verr != nil {
			problems++
			logger.Error("verify: invalid prayer times", "file", rel, "problem", verr.Error())
		}
		return nil
	})
	if err != nil {
		return problems, fmt.Errorf("verify: walk: %w", err)
	}
	entries, err := os.ReadDir(filepath.Join(st.Root, "religious-days"))
	if err != nil && !os.IsNotExist(err) {
		return problems, err
	}
	for _, e := range entries {
		year, convErr := strconv.Atoi(strings.TrimSuffix(e.Name(), ".json"))
		if convErr != nil {
			continue
		}
		var list []model.ReligiousDay
		rel := "religious-days/" + e.Name()
		if err := st.ReadJSON(rel, &list); err != nil {
			problems++
			logger.Error("verify: unreadable", "file", rel, "err", err.Error())
			continue
		}
		if verr := validate.ReligiousDays(list, year); verr != nil {
			problems++
			logger.Error("verify: invalid religious days", "file", rel, "problem", verr.Error())
		}
	}
	logger.Info("verify done", "problems", problems)
	return problems, nil
}
