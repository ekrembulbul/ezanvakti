package sermon

import (
	"encoding/xml"
	"fmt"
	"io"
	"regexp"
	"strings"
	"time"

	"vakit/internal/model"
)

// FeedItem, Diyanet Haber hutbe RSS'indeki bir kayıt. Date hutbe günüdür (UTC gün başı;
// yalnız tarih anlamlı), Title hutbenin konusu.
type FeedItem struct {
	Date  time.Time
	Kind  Kind
	Title string
	Link  string
}

type rssLink struct {
	XMLName xml.Name
	Value   string `xml:",chardata"`
}

type rssDoc struct {
	Channel struct {
		Items []struct {
			Title string `xml:"title"`
			// Öğede <atom:link> de var; yerel adı aynı olduğundan hepsi toplanır, ad alanı boş olan seçilir.
			Links       []rssLink `xml:"link"`
			Description string    `xml:"description"`
		} `xml:"item"`
	} `xml:"channel"`
}

var (
	titleDatePattern = regexp.MustCompile(`(\d{1,2})\s+(\p{L}+)\s+(\d{4})`)
	// Açıklamadaki konu: `… tarihli ve "Tebliğ Sorumluluğumuz" konulu …` (düz ya da tipografik tırnak).
	quotedTopicPattern = regexp.MustCompile(`["“”]([^"“”]+)["“”]`)
)

// ParseFeed, RSS'i ayrıştırır. Başlık "25 Eylül 2026 - Cuma Hutbesi" ya da "Kurban Bayramı
// Hutbesi - 27 Mayıs 2026" biçimindedir; tarihi, türü ya da bağlantısı çözülemeyen kayıt atlanır.
// Sıra akıştaki sıradır.
func ParseFeed(r io.Reader) ([]FeedItem, error) {
	var doc rssDoc
	if err := xml.NewDecoder(r).Decode(&doc); err != nil {
		return nil, fmt.Errorf("sermon: rss: %w", err)
	}
	var items []FeedItem
	for _, raw := range doc.Channel.Items {
		title := strings.TrimSpace(raw.Title)
		loc := titleDatePattern.FindStringIndex(title)
		if loc == nil {
			continue
		}
		date, err := model.ParseTurkishDate(title[loc[0]:loc[1]])
		if err != nil {
			continue
		}
		rest := strings.Trim(title[:loc[0]]+" "+title[loc[1]:], " -–—")
		rest = strings.Join(strings.Fields(rest), " ")
		var kind Kind
		switch lower := lowerTR(rest); {
		case strings.Contains(lower, "bayram"):
			kind = KindBayram
		case strings.Contains(lower, "cuma"):
			kind = KindCuma
		default:
			continue
		}
		link := ""
		for _, l := range raw.Links {
			if l.XMLName.Space == "" && strings.TrimSpace(l.Value) != "" {
				link = strings.TrimSpace(l.Value)
				break
			}
		}
		if link == "" {
			continue
		}
		topic := rest
		if m := quotedTopicPattern.FindStringSubmatch(raw.Description); m != nil && strings.TrimSpace(m[1]) != "" {
			topic = strings.TrimSpace(m[1])
		}
		items = append(items, FeedItem{Date: date, Kind: kind, Title: topic, Link: link})
	}
	return items, nil
}
