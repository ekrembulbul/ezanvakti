// Package sermon, Diyanet'in cuma ve bayram hutbelerini okur: Türkçe metin Diyanet Haber
// RSS'i ve hutbe sayfasından (JSON-LD articleBody), İngilizce/Arapça PDF bağlantıları Din
// Hizmetleri GM sitesinden. Metne dokunulmaz; yalnız paragraf, dipnot ve imza ayrılır.
package sermon

import (
	"regexp"
	"strings"
	"time"
	"unicode"
)

type Kind string

const (
	KindCuma   Kind = "cuma"
	KindBayram Kind = "bayram"
)

// SchemaVersion, yayımlanan dizin dosyasının sürümü.
const SchemaVersion = 1

const dateLayout = "2006-01-02"

// PDF, Din Hizmetleri'ndeki bir çeviri eki: başlık dosya adıdır (uzantısız).
type PDF struct {
	Title string `json:"title"`
	URL   string `json:"url"`
}

// Summary, GET /v1/sermons dizinindeki bir hutbe. PDFs anahtarları dil kodu (en, ar).
type Summary struct {
	ID         string         `json:"id"`
	Date       string         `json:"date"`
	Kind       Kind           `json:"kind"`
	Title      string         `json:"title"`
	SourceURL  string         `json:"sourceUrl"`
	ModifiedAt string         `json:"modifiedAt"`
	PDFs       map[string]PDF `json:"pdfs"`
}

type Footnote struct {
	N    int    `json:"n"`
	Text string `json:"text"`
}

// Text, GET /v1/sermons/{id} ile sunulan Türkçe hutbe metni.
type Text struct {
	ID         string     `json:"id"`
	Date       string     `json:"date"`
	Kind       Kind       `json:"kind"`
	Title      string     `json:"title"`
	Heading    string     `json:"heading"`
	Paragraphs []string   `json:"paragraphs"`
	Footnotes  []Footnote `json:"footnotes"`
	Signature  string     `json:"signature"`
	SourceURL  string     `json:"sourceUrl"`
	ModifiedAt string     `json:"modifiedAt"`
}

// Index, GET /v1/sermons gövdesi: tarih azalan, en çok 20 hutbe.
type Index struct {
	SchemaVersion int       `json:"schemaVersion"`
	UpdatedAt     time.Time `json:"updatedAt"`
	Sermons       []Summary `json:"sermons"`
}

var idPattern = regexp.MustCompile(`^\d{4}-\d{2}-\d{2}-(cuma|bayram)$`)

// ID, hutbe kimliği: "{YYYY-MM-DD}-{tür}".
func ID(date time.Time, kind Kind) string { return date.Format(dateLayout) + "-" + string(kind) }

// ValidID, kimliğin biçimini doğrular; dosya yolu yalnız geçerli kimlikten üretilir.
func ValidID(id string) bool { return idPattern.MatchString(id) }

func lowerTR(s string) string { return strings.ToLowerSpecial(unicode.TurkishCase, s) }
