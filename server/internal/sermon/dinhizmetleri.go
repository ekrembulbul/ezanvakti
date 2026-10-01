package sermon

import (
	"fmt"
	"io"
	"net/url"
	"path"
	"regexp"
	"slices"
	"strings"
	"time"
	"unicode"

	"golang.org/x/net/html"
	"golang.org/x/net/html/atom"
)

// Din Hizmetleri hutbe sayfası: /Detay/{id}/{ddmmyyyy}-cuma-hutbesi-… ; bayramda
// "{ddmmyyyy}-bayram-hutbesi-…" ya da "{ddmmyyyy}-kurban-bayramı-hutbesi-…".
var detailLinkPattern = regexp.MustCompile(`(?:^|/)Detay/(\d+)/([^/?#]+)`)

// Başlıktaki dil adları (Din Hizmetleri sayfa başlığı Türkçe yazar).
var languageCodes = map[string]string{
	"türkçe": "tr", "ingilizce": "en", "arapça": "ar", "almanca": "de", "fransızca": "fr",
	"ispanyolca": "es", "italyanca": "it", "rusça": "ru",
}

// FindDetailURL, Din Hizmetleri ana sayfasında verilen gün ve türdeki hutbe sayfasına giden
// ilk bağlantıyı (HTML entity'leri çözülmüş haliyle) döner; yoksa "".
func FindDetailURL(home io.Reader, date time.Time, kind Kind) (string, error) {
	doc, err := html.Parse(home)
	if err != nil {
		return "", fmt.Errorf("sermon: home html: %w", err)
	}
	prefix := date.Format("02012006") + "-"
	found := ""
	eachLink(doc, func(href string) bool {
		m := detailLinkPattern.FindStringSubmatch(href)
		if m == nil {
			return true
		}
		slug := lowerTR(unescapePath(m[2]))
		if strings.HasPrefix(slug, prefix) && slugMatchesKind(slug[len(prefix):], kind) {
			found = href
			return false
		}
		return true
	})
	return found, nil
}

func slugMatchesKind(rest string, kind Kind) bool {
	switch kind {
	case KindCuma:
		return strings.HasPrefix(rest, "cuma-hutbesi")
	case KindBayram:
		if strings.HasPrefix(rest, "cuma-") {
			return false
		}
		// "bayram-hutbesi", "kurban-bayramı-hutbesi", "ramazan-bayramı-hutbesi": ilk üç sözcük içinde.
		words := strings.SplitN(rest, "-", 5)
		for i := 0; i+1 < len(words) && i <= 2; i++ {
			if strings.HasPrefix(words[i], "bayram") && words[i+1] == "hutbesi" {
				return true
			}
		}
	}
	return false
}

// ParsePDFs, hutbe sayfasındaki /Documents/*.pdf eklerini dillere ayırır ve yalnız en ile ar'ı
// döner. Önce <title> sonundaki parantezli dil listesi ("Sesli Hutbe" hariç) belge sırasıyla
// eşlenir; sayı tutmazsa ya da eşleme yazı sistemiyle çelişirse ada bakılır: Arap harfli → ar,
// Türkçe başlığa eşit ya da Türkçeye özgü harfli → tr, kalan tek Latin ad → en (birden fazlaysa
// en verilmez). Başlık dosya adıdır; URL base + yol, yol parçaları url.PathEscape ile kodlanır.
func ParsePDFs(detail io.Reader, base string, trTitle string) (map[string]PDF, error) {
	doc, err := html.Parse(detail)
	if err != nil {
		return nil, fmt.Errorf("sermon: detail html: %w", err)
	}
	base = strings.TrimRight(base, "/")
	langs := titleLanguages(pageTitle(doc))
	var docs []PDF
	seen := map[string]bool{}
	eachAttachment(doc, func(href string) bool {
		p := documentPath(href)
		if p == "" || !strings.EqualFold(path.Ext(p), ".pdf") || seen[p] {
			return true
		}
		seen[p] = true
		name := path.Base(p)
		docs = append(docs, PDF{Title: strings.TrimSpace(strings.TrimSuffix(name, path.Ext(name))), URL: base + escapePath(p)})
		return true
	})
	out := map[string]PDF{}
	if len(langs) > 0 && len(langs) == len(docs) {
		for i, lang := range langs {
			if lang == "en" || lang == "ar" {
				out[lang] = docs[i]
			}
		}
		en, hasEN := out["en"]
		ar, hasAR := out["ar"]
		if (!hasAR || hasScript(ar.Title, unicode.Arabic)) && (!hasEN || isLatin(en.Title)) {
			return out, nil
		}
		out = map[string]PDF{}
	}
	var latin []PDF
	for _, d := range docs {
		switch {
		case hasScript(d.Title, unicode.Arabic):
			if _, ok := out["ar"]; !ok {
				out["ar"] = d
			}
		case lowerTR(d.Title) == lowerTR(strings.TrimSpace(trTitle)) || strings.ContainsAny(d.Title, "ğĞşŞıİ"):
			// Türkçe ek; uygulama Türkçe metni kendisi gösterir.
		case isLatin(d.Title):
			latin = append(latin, d)
		}
	}
	if len(latin) == 1 {
		out["en"] = latin[0]
	}
	return out, nil
}

// titleLanguages, "… (Sesli Hutbe, Türkçe, İngilizce, Arapça)" listesini dil kodlarına çevirir.
// Bilinmeyen dil sırayı korumak için "?ad" olarak kalır.
func titleLanguages(title string) []string {
	title = strings.TrimSpace(title)
	open := strings.LastIndex(title, "(")
	if open < 0 || !strings.HasSuffix(title, ")") {
		return nil
	}
	var langs []string
	for _, part := range strings.Split(title[open+1:len(title)-1], ",") {
		name := lowerTR(strings.TrimSpace(part))
		if name == "" || strings.Contains(name, "sesli") {
			continue
		}
		code, ok := languageCodes[name]
		if !ok {
			code = "?" + name
		}
		langs = append(langs, code)
	}
	return langs
}

func pageTitle(doc *html.Node) string {
	var title string
	var walk func(*html.Node) bool
	walk = func(n *html.Node) bool {
		if n.Type == html.ElementNode && n.DataAtom == atom.Title {
			title = textContent(n)
			return false
		}
		for c := n.FirstChild; c != nil; c = c.NextSibling {
			if !walk(c) {
				return false
			}
		}
		return true
	}
	walk(doc)
	return title
}

// documentPath, ek bağlantısının çözülmüş yolunu ("/Documents/Ad.pdf") döner; ek değilse "".
func documentPath(href string) string {
	p := strings.TrimSpace(href)
	if i := strings.Index(p, "://"); i >= 0 {
		rest := p[i+3:]
		slash := strings.Index(rest, "/")
		if slash < 0 {
			return ""
		}
		p = rest[slash:]
	}
	if i := strings.IndexAny(p, "?#"); i >= 0 {
		p = p[:i]
	}
	const prefix = "/documents/"
	if len(p) <= len(prefix) || !strings.EqualFold(p[:len(prefix)], prefix) {
		return ""
	}
	return unescapePath(p)
}

func escapePath(p string) string {
	parts := strings.Split(p, "/")
	for i, s := range parts {
		parts[i] = url.PathEscape(s)
	}
	return strings.Join(parts, "/")
}

// unescapePath, yüzde kodlu yolu çözer; çözülemezse olduğu gibi döner.
func unescapePath(p string) string {
	if u, err := url.PathUnescape(p); err == nil {
		return u
	}
	return p
}

func hasScript(s string, table *unicode.RangeTable) bool {
	for _, r := range s {
		if unicode.Is(table, r) {
			return true
		}
	}
	return false
}

// isLatin: en az bir harf içerir ve bütün harfleri Latin alfabesinden.
func isLatin(s string) bool {
	letters := 0
	for _, r := range s {
		if !unicode.IsLetter(r) {
			continue
		}
		if !unicode.Is(unicode.Latin, r) {
			return false
		}
		letters++
	}
	return letters > 0
}

// eachLink, belge sırasıyla her <a href> değeri için fn'i çağırır; fn false dönerse durur.
// eachAttachment, hutbenin ek bağlantılarını (class="document-link") gezer. Sayfanın kenar
// çubuğunda da /Documents/ altında rapor PDF'leri var (mutlak adresle); onlar sayılırsa dil
// sırası kayar (1 Ekim 2026 canlı sayfası). Sınıf hiç yoksa (site değişirse) sayfadaki tüm
// bağlantılara düşülür; dil eşlemesi o zaman ParsePDFs'in ad kurallarına kalır.
func eachAttachment(doc *html.Node, fn func(href string) bool) {
	var marked []string
	var all []string
	var walk func(*html.Node)
	walk = func(n *html.Node) {
		if n.Type == html.ElementNode && n.DataAtom == atom.A {
			href := strings.TrimSpace(attr(n, "href"))
			if href != "" {
				if slices.Contains(strings.Fields(attr(n, "class")), "document-link") {
					marked = append(marked, href)
				}
				all = append(all, href)
			}
		}
		for c := n.FirstChild; c != nil; c = c.NextSibling {
			walk(c)
		}
	}
	walk(doc)
	links := marked
	if len(links) == 0 {
		links = all
	}
	for _, href := range links {
		if !fn(href) {
			return
		}
	}
}

func eachLink(doc *html.Node, fn func(href string) bool) {
	var walk func(*html.Node) bool
	walk = func(n *html.Node) bool {
		if n.Type == html.ElementNode && n.DataAtom == atom.A {
			if href := attr(n, "href"); href != "" && !fn(href) {
				return false
			}
		}
		for c := n.FirstChild; c != nil; c = c.NextSibling {
			if !walk(c) {
				return false
			}
		}
		return true
	}
	walk(doc)
}
