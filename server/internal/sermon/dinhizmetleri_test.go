package sermon

import (
	"strings"
	"testing"
	"time"
)

func day(y int, m time.Month, d int) time.Time { return time.Date(y, m, d, 0, 0, 0, 0, time.UTC) }

func TestFindDetailURL(t *testing.T) {
	cases := []struct {
		date time.Time
		kind Kind
		want string // bağlantıda geçmesi gereken parça; boşsa bulunmamalı
	}{
		{day(2026, 9, 25), KindCuma, "/Detay/1318/25092026-cuma-hutbesi-tebliğ-sorumluluğumuz-(sesli-hutbe-türkçe-ingilizce-arapça)"},
		{day(2026, 9, 18), KindCuma, "/Detay/1315/"},
		{day(2026, 9, 4), KindCuma, "/Detay/1310/"},
		{day(2026, 3, 20), KindBayram, "/Detay/1251/"},
		{day(2026, 3, 20), KindCuma, "/Detay/1252/"},
		{day(2026, 5, 27), KindBayram, "/Detay/1284/"}, // "27052026-kurban-bayramı-hutbesi-…"
		{day(2026, 10, 2), KindCuma, ""},
		{day(2026, 9, 25), KindBayram, ""},
	}
	for _, c := range cases {
		got, err := FindDetailURL(openFixture(t, "dinhizmetleri_home.html"), c.date, c.kind)
		if err != nil {
			t.Fatal(err)
		}
		if c.want == "" {
			if got != "" {
				t.Errorf("%s %s: got %q want none", c.date.Format("2006-01-02"), c.kind, got)
			}
			continue
		}
		if !strings.Contains(got, c.want) {
			t.Errorf("%s %s: got %q want …%s…", c.date.Format("2006-01-02"), c.kind, got, c.want)
		}
	}
}

const testBase = "https://dinhizmetleri.diyanet.gov.tr"

func TestParsePDFs_TitleOrderMapsLanguages(t *testing.T) {
	pdfs, err := ParsePDFs(openFixture(t, "dinhizmetleri_detay_1318.html"), testBase, "Tebliğ Sorumluluğumuz")
	if err != nil {
		t.Fatal(err)
	}
	if len(pdfs) != 2 {
		t.Fatalf("pdfs = %+v (yalnız en ve ar dönmeli)", pdfs)
	}
	wantEN := PDF{Title: "Our Responsibility to Convey Islam", URL: testBase + "/Documents/Our%20Responsibility%20to%20Convey%20Islam.pdf"}
	if pdfs["en"] != wantEN {
		t.Fatalf("en = %+v", pdfs["en"])
	}
	ar := pdfs["ar"]
	// Fixture'daki dosya adı, harekeler kaynaktaki sırasıyla (şedde, sonra fetha).
	const arTitle = "مَسْؤُولِيَّتُنَا " +
		"فِي التَّبْلِيغِ"
	if ar.Title != arTitle || !strings.HasPrefix(ar.URL, testBase+"/Documents/%D9") ||
		!strings.HasSuffix(ar.URL, ".pdf") || strings.Contains(ar.URL, " ") {
		t.Fatalf("ar = %+v", ar)
	}
}

func TestParsePDFs_EightLanguageBayram(t *testing.T) {
	pdfs, err := ParsePDFs(openFixture(t, "dinhizmetleri_detay_1251.html"), testBase, "Ramazan Bayramı")
	if err != nil {
		t.Fatal(err)
	}
	if pdfs["en"].Title != "Eid al_fitr" || pdfs["en"].URL != testBase+"/Documents/Eid%20al_fitr.pdf" {
		t.Fatalf("en = %+v", pdfs["en"])
	}
	if pdfs["ar"].Title != "عِيدِ الْفِطْرِ" {
		t.Fatalf("ar = %+v", pdfs["ar"])
	}
}

func detailPage(title string, docs ...string) string {
	var b strings.Builder
	b.WriteString("<html><head><title>" + title + "</title></head><body>")
	for _, d := range docs {
		b.WriteString(`<a href="` + d + `">x</a>`)
	}
	b.WriteString("</body></html>")
	return b.String()
}

func TestParsePDFs_FallbackWhenTitleDoesNotMatchDocuments(t *testing.T) {
	// Başlıkta dil listesi yok: Arap harfli → ar, TR başlık → tr, kalan tek Latin ad → en.
	page := detailPage("02.10.2026 Cuma Hutbesi: Sabır",
		"/Documents/Sesli Hutbe (Sabır).mp3", "/Documents/Sabır.pdf", "/Documents/Sabır.doc",
		"https://dinhizmetleri.diyanet.gov.tr/Documents/Patience%20in%20Islam.pdf", "/Documents/الصبر.pdf")
	pdfs, err := ParsePDFs(strings.NewReader(page), testBase+"/", "Sabır")
	if err != nil {
		t.Fatal(err)
	}
	if pdfs["en"] != (PDF{Title: "Patience in Islam", URL: testBase + "/Documents/Patience%20in%20Islam.pdf"}) || pdfs["ar"].Title != "الصبر" {
		t.Fatalf("pdfs = %+v", pdfs)
	}

	// Sayı tutmuyor ve birden fazla Latin ad var: en belirsiz, verilmez.
	page = detailPage("Bayram Hutbesi: Kurban Bayramı (Sesli Hutbe, Türkçe, İngilizce)",
		"/Documents/Kurban Bayramı.pdf", "/Documents/Eid al-Adha.pdf", "/Documents/Aid al-Adha.pdf", "/Documents/عيد الأضحى.pdf")
	pdfs, err = ParsePDFs(strings.NewReader(page), testBase, "KURBAN BAYRAMI")
	if err != nil {
		t.Fatal(err)
	}
	if _, ok := pdfs["en"]; ok || pdfs["ar"].Title != "عيد الأضحى" {
		t.Fatalf("pdfs = %+v", pdfs)
	}

	// Başlık sırası Arapça'yı Latin ada düşürüyorsa sıraya güvenilmez, geri düşülür.
	page = detailPage("Cuma Hutbesi: Sabır (Türkçe, Arapça, İngilizce)",
		"/Documents/Sabır.pdf", "/Documents/Patience.pdf", "/Documents/الصبر.pdf")
	pdfs, err = ParsePDFs(strings.NewReader(page), testBase, "Sabır")
	if err != nil {
		t.Fatal(err)
	}
	if pdfs["en"].Title != "Patience" || pdfs["ar"].Title != "الصبر" {
		t.Fatalf("pdfs = %+v", pdfs)
	}
}

func TestParsePDFs_NoDocumentsIsEmpty(t *testing.T) {
	pdfs, err := ParsePDFs(strings.NewReader(detailPage("Duyuru")), testBase, "x")
	if err != nil || len(pdfs) != 0 {
		t.Fatalf("pdfs=%v err=%v", pdfs, err)
	}
}

// Canlı sayfada kenar çubuğunda başka /Documents/ PDF'leri (raporlar) de var; yalnız
// hutbe ekleri (document-link) sayılmalı, yoksa dil sırası kayar ve en düşer (1 Ekim 2026).
func TestParsePDFs_IgnoresSidebarDocuments(t *testing.T) {
	pdfs, err := ParsePDFs(openFixture(t, "dinhizmetleri_detay_1318_live.html"), testBase, "Tebliğ Sorumluluğumuz")
	if err != nil {
		t.Fatal(err)
	}
	if pdfs["en"].Title != "Our Responsibility to Convey Islam" {
		t.Fatalf("en = %+v", pdfs["en"])
	}
	if !strings.HasSuffix(pdfs["ar"].URL, ".pdf") || len(pdfs) != 2 {
		t.Fatalf("pdfs = %+v", pdfs)
	}
}
