package sermon

import (
	"encoding/json"
	"testing"
	"time"
)

// Uygulama bu alan adlarına göre ayrıştırır (plan: JSON sözleşmesi).
func TestJSONContract(t *testing.T) {
	idx := Index{SchemaVersion: 1, UpdatedAt: time.Date(2026, 10, 1, 19, 0, 4, 0, time.UTC), Sermons: []Summary{{
		ID: "2026-09-25-cuma", Date: "2026-09-25", Kind: KindCuma, Title: "Tebliğ Sorumluluğumuz",
		SourceURL: "https://www.diyanethaber.com.tr/25-eylul-2026-cuma-hutbesi", ModifiedAt: "2026-09-25T11:28:09+03:00",
		PDFs: map[string]PDF{"en": {Title: "T", URL: "U"}},
	}}}
	got, _ := json.Marshal(idx)
	want := `{"schemaVersion":1,"updatedAt":"2026-10-01T19:00:04Z","sermons":[{"id":"2026-09-25-cuma","date":"2026-09-25","kind":"cuma",` +
		`"title":"Tebliğ Sorumluluğumuz","sourceUrl":"https://www.diyanethaber.com.tr/25-eylul-2026-cuma-hutbesi",` +
		`"modifiedAt":"2026-09-25T11:28:09+03:00","pdfs":{"en":{"title":"T","url":"U"}}}]}`
	if string(got) != want {
		t.Fatalf("index json:\n got %s\nwant %s", got, want)
	}

	text := Text{ID: "2026-09-25-cuma", Date: "2026-09-25", Kind: KindCuma, Title: "T", Heading: "H", Paragraphs: []string{"p"},
		Footnotes: []Footnote{{N: 1, Text: "f"}}, Signature: "S", SourceURL: "u", ModifiedAt: "m"}
	got, _ = json.Marshal(text)
	want = `{"id":"2026-09-25-cuma","date":"2026-09-25","kind":"cuma","title":"T","heading":"H","paragraphs":["p"],` +
		`"footnotes":[{"n":1,"text":"f"}],"signature":"S","sourceUrl":"u","modifiedAt":"m"}`
	if string(got) != want {
		t.Fatalf("text json:\n got %s\nwant %s", got, want)
	}
}
