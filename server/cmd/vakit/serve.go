package main

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"vakit/internal/config"
	"vakit/internal/httpapi"
	"vakit/internal/store"
)

const (
	readHeaderTimeout = 5 * time.Second
	writeTimeout      = 15 * time.Second
	idleTimeout       = 60 * time.Second
	maxHeaderBytes    = 16 << 10
	shutdownGrace     = 10 * time.Second
)

func runServe(_ []string, stdout, stderr io.Writer) int {
	cfg, err := config.FromEnv(os.Getenv)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 2
	}
	logger := httpapi.NewLogger(stdout, cfg.LogLevel)
	handler := httpapi.NewHandler(store.New(cfg.DataDir), httpapi.Options{Version: version, StartedAt: time.Now()}, logger)
	srv := &http.Server{
		Addr: cfg.Addr, Handler: handler,
		ReadHeaderTimeout: readHeaderTimeout, WriteTimeout: writeTimeout, IdleTimeout: idleTimeout,
		MaxHeaderBytes: maxHeaderBytes,
	}
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	errCh := make(chan error, 1)
	go func() { errCh <- srv.ListenAndServe() }()
	logger.Info("serve started", "addr", cfg.Addr, "data_dir", cfg.DataDir, "version", version)
	select {
	case err := <-errCh:
		if !errors.Is(err, http.ErrServerClosed) {
			logger.Error("serve failed", "err", err.Error())
			return 1
		}
	case <-ctx.Done():
		shutdownCtx, cancel := context.WithTimeout(context.Background(), shutdownGrace)
		defer cancel()
		if err := srv.Shutdown(shutdownCtx); err != nil {
			logger.Error("shutdown failed", "err", err.Error())
			return 1
		}
		logger.Info("serve stopped")
	}
	return 0
}
