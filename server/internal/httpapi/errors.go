package httpapi

import (
	"encoding/json"
	"net/http"
)

type apiError struct {
	Status  int
	Code    string
	Message string
}

func errInvalidParam(msg string) *apiError {
	return &apiError{Status: http.StatusBadRequest, Code: "INVALID_PARAMETER", Message: msg}
}

var (
	errNotFound = &apiError{Status: http.StatusNotFound, Code: "NOT_FOUND", Message: "resource is not published"}
	errMethod   = &apiError{Status: http.StatusMethodNotAllowed, Code: "METHOD_NOT_ALLOWED", Message: "only GET and HEAD are supported"}
	errInternal = &apiError{Status: http.StatusInternalServerError, Code: "INTERNAL", Message: "internal error"}
)

// writeError, spec VAK.1 hata zarfını yazar: {"error":{"code","message"}}.
func writeError(w http.ResponseWriter, e *apiError) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(e.Status)
	_ = json.NewEncoder(w).Encode(map[string]any{"error": map[string]string{"code": e.Code, "message": e.Message}})
}
