package httpapi

import (
	"net/http"
	"strings"
	"testing"
)

func TestPrivacyPage(t *testing.T) {
	h, _ := newTestHandler(t)

	rec := get(t, h, http.MethodGet, "/privacy", nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	if ct := rec.Header().Get("Content-Type"); ct != "text/html; charset=utf-8" {
		t.Fatalf("Content-Type = %q", ct)
	}
	if !strings.Contains(rec.Body.String(), "Gizlilik Politikası") {
		t.Fatal("body does not contain the policy title")
	}

	head := get(t, h, http.MethodHead, "/privacy", nil)
	if head.Code != http.StatusOK || head.Body.Len() != 0 {
		t.Fatalf("HEAD status = %d, body = %d bytes", head.Code, head.Body.Len())
	}

	post := get(t, h, http.MethodPost, "/privacy", nil)
	if post.Code != http.StatusMethodNotAllowed {
		t.Fatalf("POST status = %d, want 405", post.Code)
	}
}
