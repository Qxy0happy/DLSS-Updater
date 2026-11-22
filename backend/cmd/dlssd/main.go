// Command dlssd is the Go sidecar of DLSS Updater.
//
// It listens on an explicit Unix socket, owns an explicit data directory and
// never guesses a user location. Daemon, Scan, Library, Update and Backup are
// registered here.
package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"google.golang.org/grpc"

	dlssv1 "github.com/Qxy0happy/DLSS-Updater/backend/gen/dlss/v1"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/backup"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/buildinfo"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/config"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/contract"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/daemon"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/library"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/logging"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/scan"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/store"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/update"
)

const (
	usage = "usage: dlssd [--version] | dlssd --data-dir <dir> --socket <path> --dll-source-dir <dir>"
	// gracefulTimeout bounds GracefulStop before the server is force-stopped.
	gracefulTimeout = 2 * time.Second
)

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintf(os.Stderr, "dlssd: %v\n", err)
		if errors.Is(err, daemon.ErrAlreadyRunning) || errors.Is(err, daemon.ErrSocketInUse) {
			os.Exit(1)
		}
		os.Exit(2)
	}
}

func run(args []string) error {
	// --version must not require the three paths: it is what a package build
	// and a user check run before any data directory exists.
	if len(args) == 1 && (args[0] == "--version" || args[0] == "-version") {
		fmt.Println(buildinfo.Version)
		return nil
	}
	cfg, err := config.Parse(args)
	if err != nil {
		return fmt.Errorf("%w\n%s", err, usage)
	}
	if err := daemon.PrepareDataDir(cfg.DataDir); err != nil {
		return err
	}
	if err := daemon.ValidateDLLSourceDir(cfg.DLLSourceDir); err != nil {
		return fmt.Errorf("%w\n%s", err, usage)
	}
	startTime := time.Now().UTC()

	logger, logCloser, err := logging.Open(cfg.DataDir)
	if err != nil {
		return err
	}
	defer func() { _ = logCloser.Close() }()

	lock, err := daemon.AcquireLock(cfg.DataDir)
	if err != nil {
		if errors.Is(err, daemon.ErrAlreadyRunning) {
			return fmt.Errorf("%s: %w", contract.ReasonAlreadyRunning, err)
		}
		return err
	}
	defer func() { _ = lock.Release() }()

	ctx := context.Background()
	st, err := store.Open(ctx, cfg.DataDir)
	if err != nil {
		return err
	}
	defer func() { _ = st.Close() }()

	if err := daemon.SetParentDeathSignal(); err != nil {
		return fmt.Errorf("set parent death signal: %w", err)
	}

	ln, err := daemon.ListenUnix(cfg.SocketPath)
	if err != nil {
		return err
	}
	defer func() {
		if err := daemon.CleanupSocket(cfg.SocketPath); err != nil {
			logger.Error("cleanup socket", "error", err, "path", cfg.SocketPath)
		}
	}()

	state := &daemon.RuntimeState{}
	service := daemon.NewService(state, startTime, logger)
	server := grpc.NewServer(
		grpc.ChainUnaryInterceptor(logging.UnaryInterceptor(logger)),
		grpc.ChainStreamInterceptor(logging.StreamInterceptor(logger)),
	)
	dlssv1.RegisterDaemonServer(server, service)
	dlssv1.RegisterScanServer(server, scan.NewServer(st, state, logger))
	dlssv1.RegisterLibraryServer(server, library.NewServer(st, cfg.DLLSourceDir))
	dlssv1.RegisterUpdateServer(server, update.NewServer(st, state, cfg.DLLSourceDir, logger))
	dlssv1.RegisterBackupServer(server, backup.NewServer(st, state, logger))

	serveErr := make(chan error, 1)
	go func() { serveErr <- server.Serve(ln) }()

	signalCtx, stopSignals := signal.NotifyContext(ctx, syscall.SIGTERM, syscall.SIGINT)
	defer stopSignals()

	logger.Info("dlssd started",
		"pid", os.Getpid(),
		"data_dir", cfg.DataDir,
		"socket", cfg.SocketPath,
		"dll_source_dir", cfg.DLLSourceDir,
		"version", buildinfo.Version,
	)

	select {
	case <-signalCtx.Done():
		logger.Info("signal received; stopping")
	case <-service.ShutdownRequested():
		logger.Info("shutdown rpc received; stopping")
		// Let the unary response reach the client before the transport closes.
		time.Sleep(100 * time.Millisecond)
	case err := <-serveErr:
		if err != nil && !errors.Is(err, grpc.ErrServerStopped) {
			return fmt.Errorf("serve: %w", err)
		}
		return nil
	}

	stopped := make(chan struct{})
	go func() {
		server.GracefulStop()
		close(stopped)
	}()
	select {
	case <-stopped:
	case <-time.After(gracefulTimeout):
		logger.Warn("graceful stop timed out; forcing stop", "timeout", gracefulTimeout)
		server.Stop()
		<-stopped
	}
	if err := daemon.CleanupSocket(cfg.SocketPath); err != nil {
		logger.Error("cleanup socket", "error", err, "path", cfg.SocketPath)
	}
	logger.Info("dlssd stopped")
	return nil
}
