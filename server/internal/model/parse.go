package model

import (
	"fmt"
	"strconv"
	"strings"
	"time"
)

var turkishMonths = map[string]time.Month{
	"ocak": time.January, "şubat": time.February, "mart": time.March, "nisan": time.April,
	"mayıs": time.May, "haziran": time.June, "temmuz": time.July, "ağustos": time.August,
	"eylül": time.September, "ekim": time.October, "kasım": time.November, "aralık": time.December,
}

// ParseTurkishDate "15 Eylül 2026 Salı" ya da "01 Ocak 2027" biçimini UTC gün başına çevirir.
func ParseTurkishDate(s string) (time.Time, error) {
	parts := strings.Fields(s)
	if len(parts) < 3 {
		return time.Time{}, fmt.Errorf("turkish date %q: expected 'day month year [weekday]'", s)
	}
	day, err := strconv.Atoi(parts[0])
	if err != nil {
		return time.Time{}, fmt.Errorf("turkish date %q: day: %w", s, err)
	}
	month, ok := turkishMonths[strings.ToLower(parts[1])]
	if !ok {
		return time.Time{}, fmt.Errorf("turkish date %q: unknown month %q", s, parts[1])
	}
	year, err := strconv.Atoi(parts[2])
	if err != nil {
		return time.Time{}, fmt.Errorf("turkish date %q: year: %w", s, err)
	}
	t := time.Date(year, month, day, 0, 0, 0, 0, time.UTC)
	if t.Day() != day || t.Month() != month { // 32 Eylül gibi taşmaları yakala
		return time.Time{}, fmt.Errorf("turkish date %q: invalid day of month", s)
	}
	return t, nil
}

// ClockMinutes "HH:MM" ya da "HH:MM:SS" duvar saatini gün başından itibaren dakikaya çevirir.
func ClockMinutes(s string) (int, error) {
	parts := strings.Split(strings.TrimSpace(s), ":")
	if len(parts) < 2 {
		return 0, fmt.Errorf("clock %q: expected HH:MM", s)
	}
	h, err := strconv.Atoi(parts[0])
	if err != nil || h < 0 || h > 23 {
		return 0, fmt.Errorf("clock %q: bad hour", s)
	}
	m, err := strconv.Atoi(parts[1])
	if err != nil || m < 0 || m > 59 {
		return 0, fmt.Errorf("clock %q: bad minute", s)
	}
	return h*60 + m, nil
}

// NormalizeClock "06:11:00" → "06:11"; "5:11" → "05:11".
func NormalizeClock(s string) (string, error) {
	mins, err := ClockMinutes(s)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%02d:%02d", mins/60, mins%60), nil
}
