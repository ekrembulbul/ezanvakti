# syntax=docker/dockerfile:1
FROM golang:1.27-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
ARG VERSION=dev
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w -X main.version=${VERSION}" -o /out/vakit ./cmd/vakit

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/vakit /vakit
VOLUME ["/data"]
ENV VAKIT_DATA_DIR=/data VAKIT_ADDR=0.0.0.0:8080
EXPOSE 8080
ENTRYPOINT ["/vakit"]
CMD ["serve"]
