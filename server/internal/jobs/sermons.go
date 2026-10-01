package jobs

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
	"unicode/utf8"

	"vakit/internal/model"
	"vakit/internal/sermon"
	"vakit/internal/store"
)

const (
	// sermonsKeep, yayımlanan en çok hutbe sayısı (Diyanet Haber akışının verdiği kadar).
	sermonsKeep = 20
	// sermonMinRunes: paragrafların toplamı bundan kısaysa sayfa bozuk sayılır, eski metin korunur.
	sermonMinRunes = 500
	// sermonPDFRetryDays: çevirisi eksik hutbe, tarihinden bu kadar gün geçene kadar yeniden aranır.
	sermonPDFRetryDays = 7
)

// Sermons, Diyanet Haber hutbe RSS'indeki en yeni 20 hutbeyi yayımlar: her hutbenin Türkçe
// metni (sermons/{id}.json) ve dizin (sermons/index.json). Metni olan ve günü geçmiş hutbenin
// sayfası yeniden istenmez; hutbe günü ve öncesinde (cuma düzeltmesi için) her çalışmada
// istenir. İngilizce/Arapça PDF bağlantıları Din Hizmetleri'nden bir kez aranır, eksikse
// hutbe tarihinden 7 gün geçene kadar yeniden aranır. RSS okunamazsa ya da hiçbir hutbe
// çözülemezse dosyalara dokunulmaz ve iş hata döner. Listeden düşen hutbenin metni silinir.
// Result: Fetched çekilen hutbe sayfası, Written yazılan metin, Skipped çekilmeyen ya da
// değişmemiş metin, Rejected bozuk/kısa sayfa, Errors başarısız istek sayısıdır.
func Sermons(ctx context.Context, d Deps, c *sermon.Client) (Result, error) {
	var res Result
	now := d.Now()
	trNow := now.In(TurkeyZone)
	trDay := time.Date(trNow.Year(), trNow.Month(), trNow.Day(), 0, 0, 0, 0, time.UTC)
	today := trDay.Format(model.DateLayout)
	retryAfter := trDay.AddDate(0, 0, -sermonPDFRetryDays).Format(model.DateLayout)

	feed, err := c.Get(ctx, c.FeedURL())
	if err != nil {
		return res, fmt.Errorf("sermons: feed: %w", err)
	}
	parsed, err := sermon.ParseFeed(bytes.NewReader(feed))
	if err != nil {
		return res, fmt.Errorf("sermons: %w", err)
	}
	items := newestSermons(parsed)
	if len(items) == 0 {
		return res, errors.New("sermons: feed has no recognizable sermon; existing files kept")
	}

	run := &sermonRun{d: d, c: c, res: &res}
	previous := run.previousIndex()
	var out []sermon.Summary
	for _, it := range items {
		id := sermon.ID(it.Date, it.Kind)
		date := it.Date.Format(model.DateLayout)
		text, ok, err := run.text(ctx, it, id, date >= today)
		if err != nil {
			return res, err
		}
		if !ok {
			continue // metni hiç alınamadı: uygulamada açılamayacağı için listelenmez
		}
		sum := sermon.Summary{ID: id, Date: date, Kind: it.Kind, Title: it.Title, SourceURL: it.Link,
			ModifiedAt: text.ModifiedAt, PDFs: map[string]sermon.PDF{}}
		prev, seen := previous[id]
		for lang, pdf := range prev.PDFs {
			sum.PDFs[lang] = pdf
		}
		if (sum.PDFs["en"].URL == "" || sum.PDFs["ar"].URL == "") && (!seen || date > retryAfter) {
			if err := run.findPDFs(ctx, it, text, sum.PDFs); err != nil {
				return res, err
			}
		}
		out = append(out, sum)
	}
	if len(out) == 0 {
		return res, errors.New("sermons: no sermon text could be read; existing files kept")
	}
	idx := sermon.Index{SchemaVersion: sermon.SchemaVersion, UpdatedAt: now.UTC().Truncate(time.Second), Sermons: out}
	if err := d.Store.WriteJSON(store.SermonIndexPath(), idx); err != nil {
		return res, err
	}
	pruneSermons(d, out)
	d.Logger.Info("sync sermons done", "result", res.String(), "sermons", len(out))
	return res, nil
}

// newestSermons, aynı kimlikli tekrarları atar (akıştaki ilk kayıt kalır), tarih azalan
// sıralar ve en yeni 20'yi döner.
func newestSermons(items []sermon.FeedItem) []sermon.FeedItem {
	seen := map[string]bool{}
	var out []sermon.FeedItem
	for _, it := range items {
		id := sermon.ID(it.Date, it.Kind)
		if seen[id] {
			continue
		}
		seen[id] = true
		out = append(out, it)
	}
	sort.SliceStable(out, func(i, j int) bool {
		if !out[i].Date.Equal(out[j].Date) {
			return out[i].Date.After(out[j].Date)
		}
		return out[i].Kind > out[j].Kind
	})
	if len(out) > sermonsKeep {
		out = out[:sermonsKeep]
	}
	return out
}

type sermonRun struct {
	d   Deps
	c   *sermon.Client
	res *Result

	homeTried bool
	home      []byte // Din Hizmetleri ana sayfası; çalışma başına en çok bir kez çekilir
}

func (r *sermonRun) previousIndex() map[string]sermon.Summary {
	var idx sermon.Index
	if err := r.d.Store.ReadJSON(store.SermonIndexPath(), &idx); err != nil {
		if !errors.Is(err, fs.ErrNotExist) {
			r.d.Logger.Warn("sermons: previous index unreadable; starting fresh", "err", err.Error())
		}
		return map[string]sermon.Summary{}
	}
	out := make(map[string]sermon.Summary, len(idx.Sermons))
	for _, s := range idx.Sermons {
		out[s.ID] = s
	}
	return out
}

// text, hutbenin yayımlanacak Türkçe metnini döner; ok false ise hiç metin yok. Sayfa yalnız
// metin yoksa, hutbe günü bugün ya da ilerideyse veya RSS'teki başlık/bağlantı değiştiyse
// çekilir. Bozuk ya da kısa sayfada eski metin korunur. Hata yalnız iptal ve yazma hatasıdır.
func (r *sermonRun) text(ctx context.Context, it sermon.FeedItem, id string, upcoming bool) (sermon.Text, bool, error) {
	path := store.SermonTextPath(id)
	var cur sermon.Text
	has := false
	if err := r.d.Store.ReadJSON(path, &cur); err == nil {
		has = true
	} else if !errors.Is(err, fs.ErrNotExist) {
		r.d.Logger.Warn("sermon text unreadable; refetching", "id", id, "err", err.Error())
	}
	if has && !upcoming && cur.Title == it.Title && cur.SourceURL == it.Link {
		r.res.Skipped++
		return cur, true, nil
	}
	pageURL, err := r.c.ArticleURL(it.Link)
	if err != nil {
		r.res.Rejected++
		r.d.Logger.Warn("sermon link rejected", "id", id, "err", err.Error())
		return cur, has, nil
	}
	body, err := r.c.Get(ctx, pageURL)
	if err != nil {
		if ctx.Err() != nil {
			return cur, false, ctx.Err()
		}
		r.res.Errors++
		r.d.Logger.Warn("sermon page fetch failed", "id", id, "err", err.Error())
		return cur, has, nil
	}
	r.res.Fetched++
	heading, paragraphs, footnotes, signature, modifiedAt, err := sermon.ParseArticle(bytes.NewReader(body))
	if err != nil {
		r.res.Rejected++
		r.d.Logger.Warn("sermon page not parsed; previous text kept", "id", id, "err", err.Error())
		return cur, has, nil
	}
	if n := utf8.RuneCountInString(strings.Join(paragraphs, "")); n < sermonMinRunes {
		r.res.Rejected++
		r.d.Logger.Warn("sermon text too short; previous text kept", "id", id, "runes", n)
		return cur, has, nil
	}
	next := sermon.Text{ID: id, Date: it.Date.Format(model.DateLayout), Kind: it.Kind, Title: it.Title, Heading: heading,
		Paragraphs: paragraphs, Footnotes: footnotes, Signature: signature, SourceURL: it.Link, ModifiedAt: modifiedAt}
	if has && sameJSON(cur, next) {
		r.res.Skipped++
		return cur, true, nil
	}
	if err := r.d.Store.WriteJSON(path, next); err != nil {
		return cur, false, err
	}
	r.res.Written++
	r.d.Logger.Info("sermon text written", "id", id, "modifiedAt", modifiedAt)
	return next, true, nil
}

// findPDFs, Din Hizmetleri'nde hutbe sayfasını bulur ve en/ar PDF bağlantılarını into'ya
// ekler. Bulunamaması hata değildir (çeviri sonradan eklenebilir); hata yalnız iptaldir.
func (r *sermonRun) findPDFs(ctx context.Context, it sermon.FeedItem, text sermon.Text, into map[string]sermon.PDF) error {
	id := sermon.ID(it.Date, it.Kind)
	if !r.homeTried {
		r.homeTried = true
		body, err := r.c.Get(ctx, r.c.HomeURL())
		if err != nil {
			if ctx.Err() != nil {
				return ctx.Err()
			}
			r.res.Errors++
			r.d.Logger.Warn("dinhizmetleri home fetch failed", "err", err.Error())
		}
		r.home = body
	}
	if r.home == nil {
		return nil
	}
	link, err := sermon.FindDetailURL(bytes.NewReader(r.home), it.Date, it.Kind)
	if err != nil || link == "" {
		r.d.Logger.Info("sermon translations not listed yet", "id", id)
		return nil
	}
	detailURL, err := r.c.DetailURL(link)
	if err != nil {
		r.d.Logger.Warn("sermon translation link rejected", "id", id, "err", err.Error())
		return nil
	}
	body, err := r.c.Get(ctx, detailURL)
	if err != nil {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		r.res.Errors++
		r.d.Logger.Warn("sermon translation page fetch failed", "id", id, "err", err.Error())
		return nil
	}
	trTitle := it.Title
	if it.Kind == sermon.KindBayram && text.Heading != "" {
		trTitle = text.Heading // bayramda RSS konusu "… Bayramı Hutbesi"; Türkçe ek başlıkla adlanır
	}
	found, err := sermon.ParsePDFs(bytes.NewReader(body), r.c.DinHizmetleriBase(), trTitle)
	if err != nil {
		r.d.Logger.Warn("sermon translation page not parsed", "id", id, "err", err.Error())
		return nil
	}
	for lang, pdf := range found {
		into[lang] = pdf
	}
	if into["en"].URL == "" || into["ar"].URL == "" {
		r.d.Logger.Info("sermon translations incomplete", "id", id, "found", len(found))
	}
	return nil
}

// pruneSermons, dizinde olmayan hutbe metinlerini siler. Yalnız geçerli kimlik adlı dosyalara
// dokunulur; dizin dosyası ve başka dosyalar kalır.
func pruneSermons(d Deps, keep []sermon.Summary) {
	ids := make(map[string]bool, len(keep))
	for _, s := range keep {
		ids[s.ID] = true
	}
	entries, err := os.ReadDir(filepath.Join(d.Store.Root, "sermons"))
	if err != nil {
		d.Logger.Warn("sermons: prune skipped", "err", err.Error())
		return
	}
	for _, e := range entries {
		id, isJSON := strings.CutSuffix(e.Name(), ".json")
		if e.IsDir() || !isJSON || !sermon.ValidID(id) || ids[id] {
			continue
		}
		if err := d.Store.Remove(store.SermonTextPath(id)); err != nil {
			d.Logger.Warn("sermons: prune failed", "id", id, "err", err.Error())
			continue
		}
		d.Logger.Info("sermon text removed", "id", id)
	}
}

func sameJSON(a, b any) bool {
	x, errA := json.Marshal(a)
	y, errB := json.Marshal(b)
	return errA == nil && errB == nil && bytes.Equal(x, y)
}
