VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)

.PHONY: build test vet fmt smoke docker

build:
	CGO_ENABLED=0 go build -trimpath -ldflags="-s -w -X main.version=$(VERSION)" -o vakit ./cmd/vakit

test:
	go test ./...

vet:
	gofmt -l . && go vet ./...

fmt:
	gofmt -w .

docker:
	docker build -f deploy/Dockerfile --build-arg VERSION=$(VERSION) -t vakit-api:$(VERSION) .

# Ağ gerektirir: web kaynağıyla tek ilçe uçtan uca (sync → serve → curl).
smoke: build
	@set -e; export VAKIT_DATA_DIR=$$(mktemp -d) VAKIT_SOURCE=web VAKIT_SYNC_INTERVAL=1s VAKIT_ADDR=127.0.0.1:18080; \
	./vakit sync places; \
	./vakit sync prayer-times --year $$(date +%Y) --year $$(( $$(date +%Y) + 1 )) --batch 2; \
	./vakit sync verify; \
	./vakit serve & PID=$$!; sleep 1; \
	curl -fsS http://127.0.0.1:18080/v1/health | head -c 400; echo; \
	curl -fsS -o /dev/null -w "tr/cities %{http_code} %{size_download}B\n" http://127.0.0.1:18080/v1/places/tr/cities; \
	kill $$PID; echo smoke ok
