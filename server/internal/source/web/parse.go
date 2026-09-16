package web

import (
	"errors"
	"fmt"
	"strconv"
	"strings"

	"golang.org/x/net/html"

	"vakit/internal/model"
)

var expectedHeader = []string{"Miladi Tarih", "Hicri Tarih", "İmsak", "Güneş", "Öğle", "İkindi", "Akşam", "Yatsı"}

func isElement(name string) func(*html.Node) bool {
	return func(n *html.Node) bool { return n.Type == html.ElementNode && n.Data == name }
}

func attr(n *html.Node, key string) string {
	for _, a := range n.Attr {
		if a.Key == key {
			return a.Val
		}
	}
	return ""
}

func hasClass(n *html.Node, class string) bool {
	for _, c := range strings.Fields(attr(n, "class")) {
		if c == class {
			return true
		}
	}
	return false
}

func findAll(n *html.Node, pred func(*html.Node) bool) []*html.Node {
	var out []*html.Node
	var walk func(*html.Node)
	walk = func(x *html.Node) {
		if pred(x) {
			out = append(out, x)
		}
		for c := x.FirstChild; c != nil; c = c.NextSibling {
			walk(c)
		}
	}
	walk(n)
	return out
}

func text(n *html.Node) string {
	var b strings.Builder
	var walk func(*html.Node)
	walk = func(x *html.Node) {
		if x.Type == html.TextNode {
			b.WriteString(x.Data)
		}
		for c := x.FirstChild; c != nil; c = c.NextSibling {
			walk(c)
		}
	}
	walk(n)
	return strings.Join(strings.Fields(b.String()), " ")
}

func parseCountryOptions(doc *html.Node) ([]model.Country, error) {
	selects := findAll(doc, func(n *html.Node) bool { return isElement("select")(n) && hasClass(n, "country-select") })
	if len(selects) == 0 {
		return nil, errors.New("web: country select not found on page")
	}
	var out []model.Country
	for _, opt := range findAll(selects[0], isElement("option")) {
		id, err := strconv.Atoi(strings.TrimSpace(attr(opt, "value")))
		if err != nil {
			continue // "Ülke seçin" gibi yer tutucu seçenekler
		}
		name := text(opt)
		out = append(out, model.Country{ID: id, Name: name, NameEn: name})
	}
	if len(out) == 0 {
		return nil, errors.New("web: country select has no numeric options")
	}
	return out, nil
}

func isPrayerTable(n *html.Node) bool {
	return isElement("table")(n) && (attr(n, "aria-describedby") == "table-caption-monthly" || attr(n, "id") == "yourTable")
}

func tableRows(t *html.Node) [][]string {
	var rows [][]string
	for _, tr := range findAll(t, isElement("tr")) {
		var cells []string
		for c := tr.FirstChild; c != nil; c = c.NextSibling {
			if c.Type == html.ElementNode && (c.Data == "td" || c.Data == "th") {
				cells = append(cells, text(c))
			}
		}
		if len(cells) > 0 {
			rows = append(rows, cells)
		}
	}
	return rows
}

// parsePrayerTables aylık + yıllık tabloları okur; başlık beklenenden farklıysa ErrUnexpectedTable.
func parsePrayerTables(doc *html.Node) ([]model.Day, error) {
	tables := findAll(doc, isPrayerTable)
	if len(tables) == 0 {
		return nil, fmt.Errorf("%w: no monthly/yearly table found", ErrUnexpectedTable)
	}
	var out []model.Day
	for _, t := range tables {
		rows := tableRows(t)
		if len(rows) == 0 || !equalStrings(rows[0], expectedHeader) {
			var got []string
			if len(rows) > 0 {
				got = rows[0]
			}
			return nil, fmt.Errorf("%w: got %q", ErrUnexpectedTable, got)
		}
		for i, cells := range rows[1:] {
			day, err := rowToDay(cells)
			if err != nil {
				return nil, fmt.Errorf("row %d: %w", i+1, err)
			}
			out = append(out, day)
		}
	}
	return out, nil
}

func equalStrings(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

func rowToDay(cells []string) (model.Day, error) {
	if len(cells) != len(expectedHeader) {
		return model.Day{}, fmt.Errorf("%w: row has %d cells", ErrUnexpectedTable, len(cells))
	}
	date, err := model.ParseTurkishDate(cells[0])
	if err != nil {
		return model.Day{}, err
	}
	hijri, err := model.ParseHijriLong(cells[1])
	if err != nil {
		return model.Day{}, err
	}
	var clocks [6]string
	for i := range clocks {
		c, err := model.NormalizeClock(cells[2+i])
		if err != nil {
			return model.Day{}, fmt.Errorf("%s: %w", model.ClockNames[i], err)
		}
		clocks[i] = c
	}
	return model.Day{Date: date.Format(model.DateLayout), Hijri: hijri,
		Fajr: clocks[0], Sunrise: clocks[1], Dhuhr: clocks[2], Asr: clocks[3], Maghrib: clocks[4], Isha: clocks[5]}, nil
}
