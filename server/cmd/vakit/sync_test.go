package main

import (
	"bytes"
	"flag"
	"strings"
	"testing"
	"time"
)

func TestIntList_ParsesRepeatedAndCommaSeparated(t *testing.T) {
	var years intList
	fs := flag.NewFlagSet("x", flag.ContinueOnError)
	fs.Var(&years, "year", "")
	if err := fs.Parse([]string{"--year", "2026", "--year", "2027,2028"}); err != nil {
		t.Fatal(err)
	}
	if len(years) != 3 || years[2] != 2028 {
		t.Fatalf("%v", years)
	}
	if err := fs.Parse([]string{"--year", "abc"}); err == nil {
		t.Fatal("expected parse error")
	}
}

func TestDefaultYears_CurrentAndNext(t *testing.T) {
	got := defaultYears(time.Date(2026, 9, 16, 0, 0, 0, 0, time.UTC))
	if len(got) != 2 || got[0] != 2026 || got[1] != 2027 {
		t.Fatalf("%v", got)
	}
}

func TestRunSync_UnknownJobIsUsageError(t *testing.T) {
	var out, errOut bytes.Buffer
	if code := runSync([]string{"bogus"}, &out, &errOut); code != 2 || !strings.Contains(errOut.String(), "bilinmeyen iş") {
		t.Fatalf("code=%d stderr=%s", code, errOut.String())
	}
	if code := runSync(nil, &out, &errOut); code != 2 {
		t.Fatalf("code=%d", code)
	}
}

func TestRunSync_VerifyOnEmptyDataDirSucceeds(t *testing.T) {
	t.Setenv("VAKIT_DATA_DIR", t.TempDir())
	var out, errOut bytes.Buffer
	if code := runSync([]string{"verify"}, &out, &errOut); code != 0 {
		t.Fatalf("code=%d stderr=%s stdout=%s", code, errOut.String(), out.String())
	}
}

func TestRunSync_QuotaRequiresAwqatSource(t *testing.T) {
	t.Setenv("VAKIT_DATA_DIR", t.TempDir())
	t.Setenv("VAKIT_SOURCE", "web")
	var out, errOut bytes.Buffer
	if code := runSync([]string{"quota"}, &out, &errOut); code != 2 || !strings.Contains(errOut.String(), "resmî API") {
		t.Fatalf("code=%d stderr=%s", code, errOut.String())
	}
}
