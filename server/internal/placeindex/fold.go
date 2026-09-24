package placeindex

import (
	"regexp"
	"strings"
	"unicode"
)

var parenSuffix = regexp.MustCompile(`\s*\([^)]*\)\s*$`)

// lowerTR: Türkçe kurallarıyla küçük harf (İ→i, I→ı); Go'nun ToLower'ı I→i yapar.
func lowerTR(s string) string {
	s = strings.NewReplacer("İ", "i", "I", "ı").Replace(s)
	return strings.ToLower(s)
}

// foldASCII: arama anahtarı — Türkçe harfler ASCII'ye, harf/rakam dışı atılır.
// Diyanet "CUBUK", OSM "Çubuk" ve kullanıcının "cubuk"u aynı anahtara düşer.
func foldASCII(s string) string {
	s = lowerTR(s)
	s = strings.NewReplacer("ç", "c", "ğ", "g", "ı", "i", "ö", "o", "ş", "s", "ü", "u", "â", "a", "î", "i", "û", "u").Replace(s)
	var b strings.Builder
	for _, r := range s {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
			b.WriteRune(r)
		}
	}
	return b.String()
}

// titleTR: "BÜYÜK ORHAN" → "Büyük Orhan"; ayırıcı ek "(B)" atılır; nokta sonrası da büyütülür.
func titleTR(s string) string {
	s = lowerTR(strings.TrimSpace(parenSuffix.ReplaceAllString(s, "")))
	var b strings.Builder
	capitalise := true
	for _, r := range s {
		if capitalise && unicode.IsLetter(r) {
			switch r {
			case 'i':
				b.WriteRune('İ')
			case 'ı':
				b.WriteRune('I')
			default:
				b.WriteRune(unicode.ToUpper(r))
			}
			capitalise = false
			continue
		}
		b.WriteRune(r)
		capitalise = r == ' ' || r == '.' || r == '-'
	}
	return b.String()
}
