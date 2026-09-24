package main

import (
	"bytes"
	"strings"
	"testing"
)

func TestRun_VersionPrintsVersionAndExitsZero(t *testing.T) {
	version = "1.2.3+test"
	var out, errOut bytes.Buffer
	code := run([]string{"version"}, &out, &errOut)
	if code != 0 {
		t.Fatalf("exit code = %d, want 0 (stderr: %s)", code, errOut.String())
	}
	if got := strings.TrimSpace(out.String()); got != "1.2.3+test" {
		t.Fatalf("stdout = %q, want %q", got, "1.2.3+test")
	}
}

func TestRun_NoArgsPrintsUsageAndExitsTwo(t *testing.T) {
	var out, errOut bytes.Buffer
	if code := run(nil, &out, &errOut); code != 2 {
		t.Fatalf("exit code = %d, want 2", code)
	}
	if !strings.Contains(errOut.String(), "Kullanım") {
		t.Fatalf("stderr should contain usage, got %q", errOut.String())
	}
}

func TestRun_UnknownCommandExitsTwo(t *testing.T) {
	var out, errOut bytes.Buffer
	if code := run([]string{"bogus"}, &out, &errOut); code != 2 {
		t.Fatalf("exit code = %d, want 2", code)
	}
}
