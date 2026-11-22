package daemon

import (
	"context"
	"log/slog"
	"os"
	"sync"
	"time"

	"google.golang.org/protobuf/types/known/timestamppb"

	dlssv1 "github.com/Qxy0happy/DLSS-Updater/backend/gen/dlss/v1"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/buildinfo"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/contract"
)

// Service implements dlss.v1.Daemon: the startup handshake, the live operation
// flags and orderly shutdown. The data services are registered beside it in
// cmd/dlssd.
type Service struct {
	dlssv1.UnimplementedDaemonServer

	state     *RuntimeState
	startTime time.Time
	logger    *slog.Logger

	shutdownOnce sync.Once
	shutdownCh   chan struct{}
}

// NewService builds the Daemon service. state may be nil, in which case the
// service owns a fresh idle state.
func NewService(state *RuntimeState, startTime time.Time, logger *slog.Logger) *Service {
	if state == nil {
		state = &RuntimeState{}
	}
	if logger == nil {
		logger = slog.New(slog.DiscardHandler)
	}
	return &Service{
		state:      state,
		startTime:  startTime,
		logger:     logger,
		shutdownCh: make(chan struct{}),
	}
}

// GetStatus is the startup handshake: contract version, build version, pid and
// the current operation flags.
func (s *Service) GetStatus(ctx context.Context, _ *dlssv1.GetStatusRequest) (*dlssv1.Status, error) {
	return &dlssv1.Status{
		ProtoVersion:  contract.ProtoVersion,
		AppVersion:    buildinfo.Version,
		Pid:           int32(os.Getpid()),
		StartTime:     timestamppb.New(s.startTime),
		ScanRunning:   s.state.ScanRunning(),
		UpdateRunning: s.state.UpdateRunning(),
	}, nil
}

// Shutdown asks the process to stop after the response is delivered. It only
// signals the supervisor; main owns the GracefulStop timeout so an open stream
// cannot hold the process forever.
func (s *Service) Shutdown(ctx context.Context, _ *dlssv1.ShutdownRequest) (*dlssv1.ShutdownResponse, error) {
	s.logger.InfoContext(ctx, "shutdown requested")
	s.shutdownOnce.Do(func() { close(s.shutdownCh) })
	return &dlssv1.ShutdownResponse{}, nil
}

// ShutdownRequested closes when Daemon.Shutdown has been called.
func (s *Service) ShutdownRequested() <-chan struct{} { return s.shutdownCh }
