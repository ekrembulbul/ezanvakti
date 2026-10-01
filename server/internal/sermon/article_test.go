package sermon

import (
	"strings"
	"testing"
)

func TestParseArticle_CumaSermon(t *testing.T) {
	heading, paragraphs, footnotes, signature, modifiedAt, err := ParseArticle(openFixture(t, "diyanethaber_2026-09-25.html"))
	if err != nil {
		t.Fatal(err)
	}
	if heading != "TEBLİĞ SORUMLULUĞUMUZ" {
		t.Fatalf("heading = %q", heading)
	}
	if len(paragraphs) == 0 || paragraphs[0] != "Muhterem Müslümanlar!" {
		t.Fatalf("paragraphs = %q", paragraphs)
	}
	if last := paragraphs[len(paragraphs)-1]; !strings.HasPrefix(last, "Hutbemizi Rahmet Elçisi") {
		t.Fatalf("last paragraph = %q", last)
	}
	for _, p := range paragraphs {
		if strings.HasPrefix(p, "[") || p == signature || p != strings.TrimSpace(p) {
			t.Fatalf("paragraph leaked footnote/signature/space: %q", p)
		}
	}
	if len(footnotes) != 6 {
		t.Fatalf("footnotes = %+v", footnotes)
	}
	if footnotes[2] != (Footnote{N: 3, Text: "Nahl, 16/125."}) {
		t.Fatalf("footnotes[2] = %+v", footnotes[2])
	}
	if footnotes[0] != (Footnote{N: 1, Text: "İbn Sa’d, Tabakât, I, 219, 220."}) {
		t.Fatalf("footnotes[0] = %+v", footnotes[0])
	}
	if signature != "Din Hizmetleri Genel Müdürlüğü" {
		t.Fatalf("signature = %q", signature)
	}
	if modifiedAt != "2026-09-25T11:28:09+03:00" {
		t.Fatalf("modifiedAt = %q", modifiedAt)
	}
}

func TestParseArticle_BayramDropsLinksAfterSignature(t *testing.T) {
	heading, paragraphs, footnotes, signature, modifiedAt, err := ParseArticle(openFixture(t, "diyanethaber_bayram_2026-05-27.html"))
	if err != nil {
		t.Fatal(err)
	}
	if heading != "KURBAN BAYRAMI" || signature != "Din Hizmetleri Genel Müdürlüğü" || modifiedAt != "2026-05-24T21:20:07+03:00" {
		t.Fatalf("heading=%q signature=%q modifiedAt=%q", heading, signature, modifiedAt)
	}
	if len(footnotes) != 4 || footnotes[3] != (Footnote{N: 4, Text: "Ebû Dâvûd, Zekât, 38."}) {
		t.Fatalf("footnotes = %+v", footnotes)
	}
	last := paragraphs[len(paragraphs)-1]
	if last == "Bayram Namazı nasıl kılınır?" || !strings.HasPrefix(last, "Hutbemizi, Allah Resûlü") {
		t.Fatalf("last paragraph = %q", last)
	}
	for _, p := range paragraphs {
		if strings.Contains(p, "nasıl kılınır?") || strings.Contains(p, "nasıl okunur?") || p != strings.TrimSpace(p) {
			t.Fatalf("junk or untrimmed paragraph: %q", p)
		}
	}
}

func TestParseArticle_WithoutFootnotesStopsAtSignature(t *testing.T) {
	const page = `<html><head>
<script type="application/ld+json">{"@type":"BreadcrumbList","itemListElement":[]}</script>
<script type="application/ld+json">{"@graph":[{"@type":["NewsArticle"],"dateModified":"2026-10-01T10:00:00+03:00",
"articleBody":"BAŞLIK\r\n\r\nBirinci paragraf.\r\n \r\nİkinci paragraf.\r\n\r\nDin Hizmetleri Genel Müdürlüğü\r\n\r\nİlgili haber bağlantısı"}]}</script>
</head><body></body></html>`
	heading, paragraphs, footnotes, signature, modifiedAt, err := ParseArticle(strings.NewReader(page))
	if err != nil {
		t.Fatal(err)
	}
	if heading != "BAŞLIK" || len(paragraphs) != 2 || paragraphs[1] != "İkinci paragraf." || footnotes == nil || len(footnotes) != 0 ||
		signature != "Din Hizmetleri Genel Müdürlüğü" || modifiedAt != "2026-10-01T10:00:00+03:00" {
		t.Fatalf("heading=%q paragraphs=%q footnotes=%v signature=%q modifiedAt=%q", heading, paragraphs, footnotes, signature, modifiedAt)
	}
}

func TestParseArticle_DropsTrailingBlocksAfterLastFootnoteWithoutSignature(t *testing.T) {
	const page = `<script type="application/ld+json">{"@type":"NewsArticle","dateModified":"x",
"articleBody":"BAŞLIK\n\nParagraf.[1]\n\n[1] Kaynak, 1.\n\nNamaz nasıl kılınır?"}</script>`
	_, paragraphs, footnotes, signature, _, err := ParseArticle(strings.NewReader(page))
	if err != nil {
		t.Fatal(err)
	}
	if len(paragraphs) != 1 || len(footnotes) != 1 || signature != "" {
		t.Fatalf("paragraphs=%q footnotes=%v signature=%q", paragraphs, footnotes, signature)
	}
}

func TestParseArticle_MissingArticleIsError(t *testing.T) {
	for _, page := range []string{
		`<html><head><title>x</title></head></html>`,
		`<script type="application/ld+json">{"@type":"WebPage"}</script>`,
		`<script type="application/ld+json">{"@type":"NewsArticle","articleBody":"  \r\n "}</script>`,
		`<script type="application/ld+json">{bozuk</script>`,
	} {
		if _, _, _, _, _, err := ParseArticle(strings.NewReader(page)); err == nil {
			t.Errorf("expected error for %q", page)
		}
	}
}
