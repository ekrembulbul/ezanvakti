package model

import (
	"fmt"
	"strconv"
	"strings"
)

// HijriMonths, Diyanet'in kullandığı yazımla kanonik ay adlarıdır (index+1 = ay).
var HijriMonths = [12]string{
	"Muharrem", "Safer", "Rebiulevvel", "Rebiulahir", "Cemaziyelevvel", "Cemaziyelahir",
	"Recep", "Şaban", "Ramazan", "Şevval", "Zilkade", "Zilhicce",
}

// foldTR, ay adı karşılaştırması için küçük harfe indirir ve şapkalı/noktalı
// varyantları (Rebiülahir, Zilkâde) kanonik yazıma yaklaştırır.
func foldTR(s string) string {
	s = strings.ToLower(strings.TrimSpace(s))
	return strings.NewReplacer("ü", "u", "â", "a", "î", "i", "û", "u").Replace(s)
}

func HijriMonthNumber(name string) (int, bool) {
	want := foldTR(name)
	for i, m := range HijriMonths {
		if foldTR(m) == want {
			return i + 1, true
		}
	}
	return 0, false
}

// ParseHijriLong "4 Rebiulahir 1448" biçimini ayrıştırır (web tablosu ve API hijriDateLong).
func ParseHijriLong(s string) (Hijri, error) {
	parts := strings.Fields(s)
	if len(parts) != 3 {
		return Hijri{}, fmt.Errorf("hijri long %q: expected 'day month year'", s)
	}
	day, err := strconv.Atoi(parts[0])
	if err != nil {
		return Hijri{}, fmt.Errorf("hijri long %q: day: %w", s, err)
	}
	month, ok := HijriMonthNumber(parts[1])
	if !ok {
		return Hijri{}, fmt.Errorf("hijri long %q: unknown month %q", s, parts[1])
	}
	year, err := strconv.Atoi(parts[2])
	if err != nil {
		return Hijri{}, fmt.Errorf("hijri long %q: year: %w", s, err)
	}
	return newHijri(day, month, year)
}

// ParseHijriShort "4.4.1448" biçimini ayrıştırır (API hijriDateShort).
func ParseHijriShort(s string) (Hijri, error) {
	parts := strings.Split(strings.TrimSpace(s), ".")
	if len(parts) != 3 {
		return Hijri{}, fmt.Errorf("hijri short %q: expected 'd.m.y'", s)
	}
	nums := [3]int{}
	for i, p := range parts {
		n, err := strconv.Atoi(p)
		if err != nil {
			return Hijri{}, fmt.Errorf("hijri short %q: %w", s, err)
		}
		nums[i] = n
	}
	return newHijri(nums[0], nums[1], nums[2])
}

func newHijri(day, month, year int) (Hijri, error) {
	if day < 1 || day > 30 {
		return Hijri{}, fmt.Errorf("hijri day %d out of range 1-30", day)
	}
	if month < 1 || month > 12 {
		return Hijri{}, fmt.Errorf("hijri month %d out of range 1-12", month)
	}
	if year < 1300 || year > 1700 {
		return Hijri{}, fmt.Errorf("hijri year %d implausible", year)
	}
	return Hijri{Day: day, Month: month, Year: year, MonthName: HijriMonths[month-1]}, nil
}
