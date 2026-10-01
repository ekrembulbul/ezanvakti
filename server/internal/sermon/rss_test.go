package sermon

import (
	"os"
	"strings"
	"testing"
	"time"
)

func openFixture(t *testing.T, name string) *os.File {
	t.Helper()
	f, err := os.Open("testdata/" + name)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = f.Close() })
	return f
}

func itemOn(t *testing.T, items []FeedItem, date string) FeedItem {
	t.Helper()
	for _, it := range items {
		if it.Date.Format("2006-01-02") == date {
			return it
		}
	}
	t.Fatalf("no item on %s", date)
	return FeedItem{}
}

func TestParseFeed_CumaAndBayramItems(t *testing.T) {
	items, err := ParseFeed(openFixture(t, "diyanethaber_rss.xml"))
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 20 {
		t.Fatalf("items = %d want 20", len(items))
	}
	first := items[0]
	if first.Date.Format("2006-01-02") != "2026-09-25" || first.Kind != KindCuma || first.Title != "Tebliğ Sorumluluğumuz" ||
		first.Link != "https://www.diyanethaber.com.tr/25-eylul-2026-cuma-hutbesi" {
		t.Fatalf("first = %+v", first)
	}
	if june := itemOn(t, items, "2026-06-05"); june.Kind != KindCuma || june.Title != "Duyarlılık" {
		t.Fatalf("05 Haziran = %+v", june)
	}
	if quran := itemOn(t, items, "2026-07-17"); quran.Title != "Kur'an-ı Kerim" {
		t.Fatalf("17 Temmuz = %+v", quran)
	}
	bayram := itemOn(t, items, "2026-05-27")
	if bayram.Kind != KindBayram || bayram.Title != "Kurban Bayramı Hutbesi" ||
		bayram.Link != "https://www.diyanethaber.com.tr/kurban-bayrami-hutbesi-27-mayis-2026" {
		t.Fatalf("bayram = %+v", bayram)
	}
	if ID(first.Date, first.Kind) != "2026-09-25-cuma" || ID(bayram.Date, bayram.Kind) != "2026-05-27-bayram" {
		t.Fatal("ID format")
	}
}

func TestParseFeed_SkipsUndatedAndUnknownItems(t *testing.T) {
	const feed = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom"><channel>
<item><title>Hutbe Arşivi</title><link>https://www.diyanethaber.com.tr/a</link><description>tarihsiz</description></item>
<item><title>2 Ekim 2026 - Kandil Mesajı</title><link>https://www.diyanethaber.com.tr/b</link><description>tür yok</description></item>
<item><title>31 Şubat 2026 - Cuma Hutbesi</title><link>https://www.diyanethaber.com.tr/c</link><description>geçersiz gün</description></item>
<item><title><![CDATA[ 2 Ekim 2026 - Cuma Hutbesi ]]></title><link>https://www.diyanethaber.com.tr/2-ekim-2026-cuma-hutbesi</link>
<atom:link rel="self" href="https://www.diyanethaber.com.tr/2-ekim-2026-cuma-hutbesi"/>
<description><![CDATA[2 Ekim 2026 tarihli ve “Sabır” konulu Cuma hutbesi yayınlandı.]]></description></item>
<item><title>2 Ekim 2026 - Cuma Hutbesi</title><link></link><description>bağlantısız</description></item>
</channel></rss>`
	items, err := ParseFeed(strings.NewReader(feed))
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 1 {
		t.Fatalf("items = %+v", items)
	}
	want := FeedItem{Date: time.Date(2026, 10, 2, 0, 0, 0, 0, time.UTC), Kind: KindCuma, Title: "Sabır",
		Link: "https://www.diyanethaber.com.tr/2-ekim-2026-cuma-hutbesi"}
	if items[0] != want {
		t.Fatalf("got %+v want %+v", items[0], want)
	}
}

func TestParseFeed_InvalidXMLIsError(t *testing.T) {
	if _, err := ParseFeed(strings.NewReader("<rss><channel><item>")); err == nil {
		t.Fatal("expected error")
	}
}

func TestValidID(t *testing.T) {
	for _, ok := range []string{"2026-09-25-cuma", "2026-05-27-bayram"} {
		if !ValidID(ok) {
			t.Errorf("%q should be valid", ok)
		}
	}
	for _, bad := range []string{"", "../x", "2026-09-25", "2026-09-25-kandil", "index", "2026-09-25-cuma/../x", "2026-9-25-cuma"} {
		if ValidID(bad) {
			t.Errorf("%q should be invalid", bad)
		}
	}
}
