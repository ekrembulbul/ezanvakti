package sermon

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"regexp"
	"strconv"
	"strings"
	"unicode/utf8"

	"golang.org/x/net/html"
	"golang.org/x/net/html/atom"
)

var footnotePattern = regexp.MustCompile(`(?s)^\[(\d+)\]\s*(.*)$`)

// İmza bloğu ("Din Hizmetleri Genel Müdürlüğü"): kısa, noktalamasız, kurum adıyla biter.
var signatureSuffixes = []string{"müdürlüğü", "başkanlığı", "müftülüğü"}

const maxSignatureRunes = 80

// ParseArticle, Diyanet Haber hutbe sayfasındaki JSON-LD NewsArticle kaydının articleBody
// alanını bloklara (boş satırla ayrılmış) böler: ilk blok başlık, "[n] …" blokları dipnot,
// dipnotlardan sonraki imza bloğu imza. İmzadan (imza yoksa son dipnottan) sonrası atılır;
// sayfa oraya ilgisiz bağlantı metinleri ekleyebiliyor. Metnin kendisi değiştirilmez.
func ParseArticle(r io.Reader) (heading string, paragraphs []string, footnotes []Footnote, signature, modifiedAt string, err error) {
	doc, err := html.Parse(r)
	if err != nil {
		return "", nil, nil, "", "", fmt.Errorf("sermon: article html: %w", err)
	}
	body, modifiedAt, err := newsArticle(doc)
	if err != nil {
		return "", nil, nil, "", "", err
	}
	blocks := splitBlocks(body)
	if len(blocks) < 2 {
		return "", nil, nil, "", "", errors.New("sermon: articleBody has no paragraphs")
	}
	heading = blocks[0]
	paragraphs = []string{}
	footnotes = []Footnote{}
	for _, b := range blocks[1:] {
		if m := footnotePattern.FindStringSubmatch(b); m != nil {
			n, _ := strconv.Atoi(m[1])
			footnotes = append(footnotes, Footnote{N: n, Text: strings.TrimSpace(m[2])})
			continue
		}
		if isSignature(b) {
			signature = b
			break
		}
		if len(footnotes) > 0 {
			break // dipnotlardan sonra imza dışında gelen her şey sayfa artığı
		}
		paragraphs = append(paragraphs, b)
	}
	if len(paragraphs) == 0 {
		return "", nil, nil, "", "", errors.New("sermon: articleBody has no paragraphs")
	}
	return heading, paragraphs, footnotes, signature, modifiedAt, nil
}

// splitBlocks, satır sonlarını \n'e indirir ve boş (yalnız boşluk içeren) satırlarla ayrılmış
// blokları kırpılmış olarak döner.
func splitBlocks(body string) []string {
	body = strings.ReplaceAll(body, "\r\n", "\n")
	body = strings.ReplaceAll(body, "\r", "\n")
	var blocks, cur []string
	flush := func() {
		if b := strings.TrimSpace(strings.Join(cur, "\n")); b != "" {
			blocks = append(blocks, b)
		}
		cur = cur[:0]
	}
	for _, line := range strings.Split(body, "\n") {
		if strings.TrimSpace(line) == "" {
			flush()
			continue
		}
		cur = append(cur, line)
	}
	flush()
	return blocks
}

func isSignature(b string) bool {
	if utf8.RuneCountInString(b) > maxSignatureRunes || strings.ContainsAny(b, ".!?:;\n") {
		return false
	}
	lower := lowerTR(b)
	for _, s := range signatureSuffixes {
		if strings.HasSuffix(lower, s) {
			return true
		}
	}
	return false
}

// newsArticle, sayfadaki application/ld+json betiklerinde @type NewsArticle olan kaydı bulur
// (dizi ve @graph biçimleri dahil) ve articleBody ile dateModified döner.
func newsArticle(doc *html.Node) (body, modified string, err error) {
	var found map[string]any
	var walk func(*html.Node)
	walk = func(n *html.Node) {
		if found != nil {
			return
		}
		if n.Type == html.ElementNode && n.DataAtom == atom.Script && attr(n, "type") == "application/ld+json" {
			var v any
			if json.Unmarshal([]byte(textContent(n)), &v) == nil {
				found = findNewsArticle(v)
			}
			return
		}
		for c := n.FirstChild; c != nil; c = c.NextSibling {
			walk(c)
		}
	}
	walk(doc)
	if found == nil {
		return "", "", errors.New("sermon: NewsArticle JSON-LD not found")
	}
	body, _ = found["articleBody"].(string)
	modified, _ = found["dateModified"].(string)
	if strings.TrimSpace(body) == "" {
		return "", "", errors.New("sermon: NewsArticle has empty articleBody")
	}
	return body, modified, nil
}

func findNewsArticle(v any) map[string]any {
	switch t := v.(type) {
	case []any:
		for _, e := range t {
			if m := findNewsArticle(e); m != nil {
				return m
			}
		}
	case map[string]any:
		if hasType(t["@type"], "NewsArticle") {
			return t
		}
		if g, ok := t["@graph"]; ok {
			return findNewsArticle(g)
		}
	}
	return nil
}

func hasType(v any, want string) bool {
	switch t := v.(type) {
	case string:
		return t == want
	case []any:
		for _, e := range t {
			if s, ok := e.(string); ok && s == want {
				return true
			}
		}
	}
	return false
}

func attr(n *html.Node, key string) string {
	for _, a := range n.Attr {
		if a.Namespace == "" && strings.EqualFold(a.Key, key) {
			return a.Val
		}
	}
	return ""
}

func textContent(n *html.Node) string {
	var b strings.Builder
	var walk func(*html.Node)
	walk = func(n *html.Node) {
		if n.Type == html.TextNode {
			b.WriteString(n.Data)
		}
		for c := n.FirstChild; c != nil; c = c.NextSibling {
			walk(c)
		}
	}
	walk(n)
	return b.String()
}
