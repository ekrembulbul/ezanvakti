package awqat

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

type tokenPair struct {
	AccessToken  string    `json:"accessToken"`
	RefreshToken string    `json:"refreshToken"`
	AccessExp    time.Time `json:"accessExp"`
}

func (t tokenPair) empty() bool { return t.AccessToken == "" || t.RefreshToken == "" }

// jwtExpiry, imzayı doğrulamadan payload'daki exp claim'ini okur; süre yönetimi için yeter.
func jwtExpiry(token string) (time.Time, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return time.Time{}, errors.New("awqat: token is not a JWT")
	}
	payload, err := base64.RawURLEncoding.DecodeString(strings.TrimRight(parts[1], "="))
	if err != nil {
		return time.Time{}, fmt.Errorf("awqat: jwt payload: %w", err)
	}
	var claims struct {
		Exp int64 `json:"exp"`
	}
	if err := json.Unmarshal(payload, &claims); err != nil || claims.Exp == 0 {
		return time.Time{}, errors.New("awqat: jwt has no exp claim")
	}
	return time.Unix(claims.Exp, 0).UTC(), nil
}

func loadTokenFile(path string) (tokenPair, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return tokenPair{}, err
	}
	var t tokenPair
	if err := json.Unmarshal(data, &t); err != nil {
		return tokenPair{}, fmt.Errorf("awqat: token file: %w", err)
	}
	return t, nil
}

// saveTokenFile 0600 ile yazar; token sızıntısına karşı dizin izinleri de 0700.
func saveTokenFile(path string, t tokenPair) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	data, err := json.Marshal(t)
	if err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}
