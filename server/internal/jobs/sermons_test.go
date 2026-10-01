package jobs

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"testing"
	"time"

	"vakit/internal/sermon"
	"vakit/internal/store"
)

const sermonFixtures = "../sermon/testdata/"

// fakeSites, Diyanet Haber ve Din Hizmetleri'nin sahte sunucuları; istekleri sayar.
type fakeSites struct {
	mu          sync.Mutex
	hits        map[string]int // "dh:/yol" ya da "din:/yol"
	rssStatus   int
	rss         []byte
	articles    map[string][]byte // yol → sayfa (yoksa türüne göre fixture)
	detailsDown map[string]bool   // Din Hizmetleri sayfa id'si → 404
	dh, din     *httptest.Server
}

func readSermonFixture(t *testing.T, name string) []byte {
	t.Helper()
	b, err := os.ReadFile(sermonFixtures + name)
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func newFakeSites(t *testing.T) *fakeSites {
	t.Helper()
	f := &fakeSites{hits: map[string]int{}, articles: map[string][]byte{}, detailsDown: map[string]bool{},
		rss: readSermonFixture(t, "diyanethaber_rss.xml")}
	cuma := readSermonFixture(t, "diyanethaber_2026-09-25.html")
	bayram := readSermonFixture(t, "diyanethaber_bayram_2026-05-27.html")
	home := readSermonFixture(t, "dinhizmetleri_home.html")
	details := map[string][]byte{
		"1318": readSermonFixture(t, "dinhizmetleri_detay_1318.html"),
		"1251": readSermonFixture(t, "dinhizmetleri_detay_1251.html"),
	}
	f.dh = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		f.mu.Lock()
		f.hits["dh:"+r.URL.Path]++
		status, rss, override := f.rssStatus, f.rss, f.articles[r.URL.Path]
		f.mu.Unlock()
		switch {
		case r.URL.Path == "/rss/hutbeler":
			if status != 0 {
				http.Error(w, "down", status)
				return
			}
			_, _ = w.Write(rss)
		case override != nil:
			_, _ = w.Write(override)
		case strings.Contains(r.URL.Path, "bayram"):
			_, _ = w.Write(bayram)
		case strings.Contains(r.URL.Path, "cuma-hutbesi"):
			_, _ = w.Write(cuma)
		default:
			http.NotFound(w, r)
		}
	}))
	t.Cleanup(f.dh.Close)
	f.din = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		parts := strings.Split(r.URL.Path, "/") // "", "Detay", id, slug
		f.mu.Lock()
		f.hits["din:"+r.URL.Path]++
		down := len(parts) == 4 && f.detailsDown[parts[2]]
		f.mu.Unlock()
		if r.URL.Path == "/" {
			_, _ = w.Write(home)
			return
		}
		if len(parts) == 4 && parts[1] == "Detay" && details[parts[2]] != nil && !down {
			_, _ = w.Write(details[parts[2]])
			return
		}
		http.NotFound(w, r)
	}))
	t.Cleanup(f.din.Close)
	return f
}

func (f *fakeSites) client() *sermon.Client {
	return sermon.NewClient(sermon.WithHTTPClient(f.dh.Client()), sermon.WithInterval(0), sermon.WithBaseURLs(f.dh.URL, f.din.URL))
}

func (f *fakeSites) count(prefix string) int {
	f.mu.Lock()
	defer f.mu.Unlock()
	n := 0
	for k, v := range f.hits {
		if strings.HasPrefix(k, prefix) {
			n += v
		}
	}
	return n
}

func (f *fakeSites) hit(key string) int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.hits[key]
}

func (f *fakeSites) snapshot() map[string]int {
	f.mu.Lock()
	defer f.mu.Unlock()
	out := make(map[string]int, len(f.hits))
	for k, v := range f.hits {
		out[k] = v
	}
	return out
}

func (f *fakeSites) reset() {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.hits = map[string]int{}
}

func (f *fakeSites) set(fn func(*fakeSites)) {
	f.mu.Lock()
	defer f.mu.Unlock()
	fn(f)
}

func articlePage(t *testing.T, modified, body string) []byte {
	t.Helper()
	ld, err := json.Marshal(map[string]any{"@type": "NewsArticle", "dateModified": modified, "articleBody": body})
	if err != nil {
		t.Fatal(err)
	}
	return []byte(`<html><head><script type="application/ld+json">` + string(ld) + `</script></head></html>`)
}

func sermonDeps(t *testing.T, now time.Time) Deps {
	d := testDeps(t, newFake())
	d.Now = func() time.Time { return now }
	return d
}

func readSermonIndex(t *testing.T, d Deps) sermon.Index {
	t.Helper()
	var idx sermon.Index
	if err := d.Store.ReadJSON(store.SermonIndexPath(), &idx); err != nil {
		t.Fatal(err)
	}
	return idx
}

func readSermonText(t *testing.T, d Deps, id string) sermon.Text {
	t.Helper()
	var txt sermon.Text
	if err := d.Store.ReadJSON(store.SermonTextPath(id), &txt); err != nil {
		t.Fatal(err)
	}
	return txt
}

func sermonFiles(t *testing.T, d Deps) []string {
	t.Helper()
	entries, err := os.ReadDir(filepath.Join(d.Store.Root, "sermons"))
	if err != nil {
		t.Fatal(err)
	}
	var names []string
	for _, e := range entries {
		names = append(names, e.Name())
	}
	sort.Strings(names)
	return names
}

func TestSermons_FirstRunPublishesFeedNewestFirst(t *testing.T) {
	f := newFakeSites(t)
	d := sermonDeps(t, time.Date(2026, 10, 1, 19, 0, 4, 900, time.UTC))
	res, err := Sermons(context.Background(), d, f.client())
	if err != nil || res.Written != 20 || res.Fetched != 20 {
		t.Fatalf("res=%v err=%v", res, err)
	}
	idx := readSermonIndex(t, d)
	if idx.SchemaVersion != 1 || len(idx.Sermons) != 20 || !idx.UpdatedAt.Equal(time.Date(2026, 10, 1, 19, 0, 4, 0, time.UTC)) {
		t.Fatalf("index: version=%d count=%d updatedAt=%v", idx.SchemaVersion, len(idx.Sermons), idx.UpdatedAt)
	}
	for i := 1; i < len(idx.Sermons); i++ {
		if idx.Sermons[i-1].Date < idx.Sermons[i].Date {
			t.Fatalf("not newest first at %d: %s < %s", i, idx.Sermons[i-1].Date, idx.Sermons[i].Date)
		}
	}
	top := idx.Sermons[0]
	if top.ID != "2026-09-25-cuma" || top.Date != "2026-09-25" || top.Kind != sermon.KindCuma || top.Title != "Tebliğ Sorumluluğumuz" ||
		top.SourceURL != "https://www.diyanethaber.com.tr/25-eylul-2026-cuma-hutbesi" || top.ModifiedAt != "2026-09-25T11:28:09+03:00" {
		t.Fatalf("top = %+v", top)
	}
	if top.PDFs["en"] != (sermon.PDF{Title: "Our Responsibility to Convey Islam", URL: f.din.URL + "/Documents/Our%20Responsibility%20to%20Convey%20Islam.pdf"}) ||
		top.PDFs["ar"].URL == "" {
		t.Fatalf("top pdfs = %+v", top.PDFs)
	}
	var bayram *sermon.Summary
	for i := range idx.Sermons {
		if idx.Sermons[i].ID == "2026-05-27-bayram" {
			bayram = &idx.Sermons[i]
		}
	}
	if bayram == nil || bayram.Kind != sermon.KindBayram || bayram.Title != "Kurban Bayramı Hutbesi" {
		t.Fatalf("bayram = %+v", bayram)
	}
	raw, _, err := d.Store.Read(store.SermonIndexPath())
	if err != nil || !bytes.Contains(raw, []byte(`"updatedAt":"2026-10-01T19:00:04Z"`)) || !bytes.Contains(raw, []byte(`"pdfs":{}`)) {
		t.Fatalf("index json: %s", raw)
	}
	txt := readSermonText(t, d, "2026-09-25-cuma")
	if txt.ID != "2026-09-25-cuma" || txt.Heading != "TEBLİĞ SORUMLULUĞUMUZ" || txt.Title != "Tebliğ Sorumluluğumuz" || len(txt.Footnotes) != 6 ||
		txt.Signature != "Din Hizmetleri Genel Müdürlüğü" || txt.SourceURL != top.SourceURL || txt.ModifiedAt != top.ModifiedAt || txt.Paragraphs[0] != "Muhterem Müslümanlar!" {
		t.Fatalf("text = %+v", txt)
	}
	if b := readSermonText(t, d, "2026-05-27-bayram"); b.Heading != "KURBAN BAYRAMI" || b.Kind != sermon.KindBayram {
		t.Fatalf("bayram text = %+v", b)
	}
	if home := f.count("din:/"); home < 2 || f.hit("din:/") != 1 {
		t.Fatalf("Din Hizmetleri ana sayfası çalışma başına bir kez istenmeli: home=%d all=%d", f.hit("din:/"), home)
	}
}

func TestSermons_SecondRunSkipsPastSermonPages(t *testing.T) {
	f := newFakeSites(t)
	d := sermonDeps(t, time.Date(2026, 10, 1, 19, 0, 0, 0, time.UTC))
	if _, err := Sermons(context.Background(), d, f.client()); err != nil {
		t.Fatal(err)
	}
	f.reset()
	res, err := Sermons(context.Background(), d, f.client())
	if err != nil || res.Skipped != 20 || res.Written != 0 || res.Fetched != 0 {
		t.Fatalf("res=%v err=%v", res, err)
	}
	if dh, din := f.count("dh:"), f.count("din:"); dh != 1 || din != 0 {
		t.Fatalf("yalnız RSS istenmeli: dh=%d din=%d hits=%v", dh, din, f.snapshot())
	}
	if len(readSermonIndex(t, d).Sermons) != 20 {
		t.Fatal("index must still list 20")
	}
}

func TestSermons_SermonDayRefetchesAndUpdatesChangedText(t *testing.T) {
	f := newFakeSites(t)
	d := sermonDeps(t, time.Date(2026, 9, 25, 6, 0, 0, 0, time.UTC)) // TR cuma 09:00
	if _, err := Sermons(context.Background(), d, f.client()); err != nil {
		t.Fatal(err)
	}
	f.reset()
	res, err := Sermons(context.Background(), d, f.client())
	if err != nil || res.Fetched != 1 || res.Written != 0 || f.hit("dh:/25-eylul-2026-cuma-hutbesi") != 1 || f.count("dh:") != 2 {
		t.Fatalf("unchanged sermon-day refetch: res=%v err=%v hits=%v", res, err, f.snapshot())
	}

	page := bytes.Replace(readSermonFixture(t, "diyanethaber_2026-09-25.html"), []byte("2026-09-25T11:28:09+03:00"), []byte("2026-09-25T11:45:00+03:00"), 1)
	page = bytes.Replace(page, []byte("(s.a.s)"), []byte("(s.a.v.)"), 1) // ilk paragraftaki ilk geçiş
	f.set(func(f *fakeSites) { f.articles["/25-eylul-2026-cuma-hutbesi"] = page })
	res, err = Sermons(context.Background(), d, f.client())
	if err != nil || res.Written != 1 {
		t.Fatalf("res=%v err=%v", res, err)
	}
	txt := readSermonText(t, d, "2026-09-25-cuma")
	if txt.ModifiedAt != "2026-09-25T11:45:00+03:00" || !strings.Contains(txt.Paragraphs[1], "(s.a.v.)") {
		t.Fatalf("text not updated: %s %q", txt.ModifiedAt, txt.Paragraphs[1])
	}
	if top := readSermonIndex(t, d).Sermons[0]; top.ModifiedAt != "2026-09-25T11:45:00+03:00" || top.PDFs["en"].URL == "" {
		t.Fatalf("index top = %+v", top)
	}
}

func TestSermons_ShortTextKeepsPreviousText(t *testing.T) {
	f := newFakeSites(t)
	d := sermonDeps(t, time.Date(2026, 9, 25, 6, 0, 0, 0, time.UTC))
	if _, err := Sermons(context.Background(), d, f.client()); err != nil {
		t.Fatal(err)
	}
	before, _, err := d.Store.Read(store.SermonTextPath("2026-09-25-cuma"))
	if err != nil {
		t.Fatal(err)
	}
	f.set(func(f *fakeSites) {
		f.articles["/25-eylul-2026-cuma-hutbesi"] = articlePage(t, "2026-09-25T12:00:00+03:00",
			"TEBLİĞ\r\n\r\nKısa metin.\r\n\r\nDin Hizmetleri Genel Müdürlüğü")
	})
	res, err := Sermons(context.Background(), d, f.client())
	if err != nil || res.Rejected != 1 || res.Written != 0 {
		t.Fatalf("res=%v err=%v", res, err)
	}
	after, _, _ := d.Store.Read(store.SermonTextPath("2026-09-25-cuma"))
	if !bytes.Equal(before, after) {
		t.Fatal("previous text must be kept")
	}
	if top := readSermonIndex(t, d).Sermons[0]; top.ID != "2026-09-25-cuma" || top.ModifiedAt != "2026-09-25T11:28:09+03:00" {
		t.Fatalf("index top = %+v", top)
	}
}

func TestSermons_UnreadableNewSermonIsNotListed(t *testing.T) {
	f := newFakeSites(t)
	f.set(func(f *fakeSites) {
		f.articles["/18-eylul-2026-cuma-hutbesi"] = articlePage(t, "x", "BAŞLIK\n\nKısa.")
		f.articles["/11-eylul-2026-cuma-hutbesi"] = []byte("<html>yapı değişti</html>")
	})
	d := sermonDeps(t, time.Date(2026, 10, 1, 19, 0, 0, 0, time.UTC))
	res, err := Sermons(context.Background(), d, f.client())
	if err != nil || res.Rejected != 2 || res.Written != 18 {
		t.Fatalf("res=%v err=%v", res, err)
	}
	idx := readSermonIndex(t, d)
	if len(idx.Sermons) != 18 {
		t.Fatalf("count = %d", len(idx.Sermons))
	}
	for _, s := range idx.Sermons {
		if s.ID == "2026-09-18-cuma" || s.ID == "2026-09-11-cuma" {
			t.Fatalf("%s has no text and must not be listed", s.ID)
		}
	}
	if d.Store.Exists(store.SermonTextPath("2026-09-18-cuma")) {
		t.Fatal("short text must not be written")
	}
}

func TestSermons_FeedFailureKeepsFiles(t *testing.T) {
	f := newFakeSites(t)
	d := sermonDeps(t, time.Date(2026, 10, 1, 19, 0, 0, 0, time.UTC))
	if _, err := Sermons(context.Background(), d, f.client()); err != nil {
		t.Fatal(err)
	}
	indexBefore, _, _ := d.Store.Read(store.SermonIndexPath())
	filesBefore := sermonFiles(t, d)
	d.Now = func() time.Time { return time.Date(2026, 10, 2, 19, 0, 0, 0, time.UTC) }

	f.set(func(f *fakeSites) { f.rssStatus = http.StatusInternalServerError })
	if _, err := Sermons(context.Background(), d, f.client()); err == nil {
		t.Fatal("RSS 500 must fail the job")
	}
	f.set(func(f *fakeSites) {
		f.rssStatus = 0
		f.rss = []byte(`<?xml version="1.0"?><rss version="2.0"><channel><item><title>Duyuru</title></item></channel></rss>`)
	})
	if _, err := Sermons(context.Background(), d, f.client()); err == nil {
		t.Fatal("feed without sermons must fail the job")
	}
	indexAfter, _, _ := d.Store.Read(store.SermonIndexPath())
	if !bytes.Equal(indexBefore, indexAfter) || strings.Join(filesBefore, ",") != strings.Join(sermonFiles(t, d), ",") {
		t.Fatal("existing files must be untouched")
	}
}

func TestSermons_KeepsTwentyAndDeletesDroppedTexts(t *testing.T) {
	f := newFakeSites(t)
	d := sermonDeps(t, time.Date(2026, 10, 1, 19, 0, 0, 0, time.UTC))
	if _, err := Sermons(context.Background(), d, f.client()); err != nil {
		t.Fatal(err)
	}
	if !d.Store.Exists(store.SermonTextPath("2026-05-22-cuma")) {
		t.Fatal("oldest text should exist after first run")
	}
	_ = d.Store.WriteJSON(store.SermonTextPath("2026-01-02-cuma"), sermon.Text{ID: "2026-01-02-cuma"}) // eski artık
	_ = d.Store.WriteJSON("sermons/notes.json", map[string]string{"x": "y"})                           // kimlik değil: dokunulmaz

	newer := `<item><title><![CDATA[2 Ekim 2026 - Cuma Hutbesi]]></title>` +
		`<link>https://www.diyanethaber.com.tr/2-ekim-2026-cuma-hutbesi</link>` +
		`<description><![CDATA[Diyanet İşleri Başkanlığınca hazırlanan 2 Ekim 2026 tarihli ve "Sabır" konulu Cuma hutbesi yayınlandı.]]></description></item>`
	f.set(func(f *fakeSites) { f.rss = bytes.Replace(f.rss, []byte("<item>"), []byte(newer+"\n<item>"), 1) })
	d.Now = func() time.Time { return time.Date(2026, 10, 1, 21, 0, 0, 0, time.UTC) } // TR 2 Ekim 00:00
	res, err := Sermons(context.Background(), d, f.client())
	if err != nil {
		t.Fatalf("res=%v err=%v", res, err)
	}
	idx := readSermonIndex(t, d)
	if len(idx.Sermons) != 20 || idx.Sermons[0].ID != "2026-10-02-cuma" || idx.Sermons[0].Title != "Sabır" || idx.Sermons[19].ID != "2026-05-27-bayram" {
		t.Fatalf("count=%d first=%+v last=%+v", len(idx.Sermons), idx.Sermons[0], idx.Sermons[len(idx.Sermons)-1])
	}
	if f.hit("dh:/22-mayis-2026-cuma-hutbesi") != 1 {
		t.Fatalf("21st item must not be fetched again: %v", f.snapshot())
	}
	for _, gone := range []string{"2026-05-22-cuma", "2026-01-02-cuma"} {
		if d.Store.Exists(store.SermonTextPath(gone)) {
			t.Fatalf("%s should be deleted", gone)
		}
	}
	if !d.Store.Exists("sermons/notes.json") || !d.Store.Exists(store.SermonTextPath("2026-10-02-cuma")) {
		t.Fatal("unrelated file and new text must exist")
	}
	if got := len(sermonFiles(t, d)); got != 22 { // 20 metin + index.json + notes.json
		t.Fatalf("files = %d: %v", got, sermonFiles(t, d))
	}
}

func TestSermons_RetriesMissingPDFsOnlyForRecentSermons(t *testing.T) {
	f := newFakeSites(t)
	f.set(func(f *fakeSites) { f.detailsDown["1318"] = true })
	d := sermonDeps(t, time.Date(2026, 9, 26, 10, 0, 0, 0, time.UTC))
	res, err := Sermons(context.Background(), d, f.client())
	if err != nil || res.Errors == 0 {
		t.Fatalf("res=%v err=%v", res, err)
	}
	if top := readSermonIndex(t, d).Sermons[0]; len(top.PDFs) != 0 {
		t.Fatalf("pdfs should be empty: %+v", top.PDFs)
	}

	f.set(func(f *fakeSites) { f.detailsDown["1318"] = false })
	f.reset()
	if _, err := Sermons(context.Background(), d, f.client()); err != nil {
		t.Fatal(err)
	}
	if top := readSermonIndex(t, d).Sermons[0]; top.PDFs["en"].Title != "Our Responsibility to Convey Islam" || top.PDFs["ar"].URL == "" {
		t.Fatalf("pdfs should be found on retry: %+v", top.PDFs)
	}
	if f.hit("din:/") != 1 || f.count("din:/Detay/") != 1 {
		t.Fatalf("only the recent sermon is looked up again: %v", f.snapshot())
	}

	// 7 günden eski hutbe için ikinci çalışmada aranmaz.
	old := sermonDeps(t, time.Date(2026, 10, 5, 10, 0, 0, 0, time.UTC))
	f.set(func(f *fakeSites) { f.detailsDown["1318"] = true })
	if _, err := Sermons(context.Background(), old, f.client()); err != nil {
		t.Fatal(err)
	}
	f.set(func(f *fakeSites) { f.detailsDown["1318"] = false })
	f.reset()
	if _, err := Sermons(context.Background(), old, f.client()); err != nil {
		t.Fatal(err)
	}
	if f.count("din:") != 0 || len(readSermonIndex(t, old).Sermons[0].PDFs) != 0 {
		t.Fatalf("old sermon must not be looked up again: hits=%v", f.snapshot())
	}
}
