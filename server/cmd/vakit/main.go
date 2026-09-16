// Command vakit: Diyanet vakit verisini çeken (sync) ve sunan (serve) tek binary.
package main

import (
	"fmt"
	"io"
	"os"
)

// version -ldflags "-X main.version=<sürüm>" ile doldurulur.
var version = "dev"

const usage = `vakit — Diyanet vakit verisi sunucusu

Kullanım:
  vakit serve                  HTTP sunucusunu başlatır (VAKIT_ADDR, VAKIT_DATA_DIR)
  vakit sync <iş> [flags]      Diyanet'ten veri çeker: places | prayer-times | religious-days | daily-content | quota | verify
  vakit version                sürümü yazar
`

func main() {
	os.Exit(run(os.Args[1:], os.Stdout, os.Stderr))
}

func run(args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		fmt.Fprint(stderr, usage)
		return 2
	}
	switch args[0] {
	case "serve":
		return runServe(args[1:], stdout, stderr)
	case "version":
		fmt.Fprintln(stdout, version)
		return 0
	default:
		fmt.Fprintf(stderr, "bilinmeyen komut: %q\n\n%s", args[0], usage)
		return 2
	}
}
