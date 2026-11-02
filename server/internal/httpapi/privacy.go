package httpapi

import (
	_ "embed"
	"net/http"
	"strconv"
)

// privacyHTML: mağaza kayıtlarında verilen gizlilik politikası adresinin içeriği.
// Metnin tek kaynağı bu dosyadır; değişiklik sunucu dağıtımıyla yayına çıkar.
//
//go:embed privacy.html
var privacyHTML []byte

const cachePrivacy = "public, max-age=3600"

func privacy(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet && r.Method != http.MethodHead {
		w.Header().Set("Allow", "GET, HEAD")
		writeError(w, errMethod)
		return
	}
	hdr := w.Header()
	hdr.Set("Content-Type", "text/html; charset=utf-8")
	hdr.Set("Cache-Control", cachePrivacy)
	hdr.Set("X-Content-Type-Options", "nosniff")
	hdr.Set("Content-Length", strconv.Itoa(len(privacyHTML)))
	w.WriteHeader(http.StatusOK)
	if r.Method == http.MethodHead {
		return
	}
	_, _ = w.Write(privacyHTML)
}
