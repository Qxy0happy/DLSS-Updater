package scan

import (
	"context"
	"log/slog"
	"sync/atomic"
	"time"

	"google.golang.org/protobuf/types/known/timestamppb"

	dlssv1 "github.com/Qxy0happy/DLSS-Updater/backend/gen/dlss/v1"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/contract"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/logging"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/peversion"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/protomap"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/store"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/streams"
)

// RunState is the process-wide scan flag Daemon.GetStatus reports.
type RunState interface {
	SetScanRunning(bool)
}

// Server implements dlss.v1.Scan. It owns the one-scan-at-a-time rule and
// persists each game in its own store transaction.
type Server struct {
	dlssv1.UnimplementedScanServer

	store   *store.Store
	state   RunState
	logger  *slog.Logger
	running atomic.Bool

	now         func() time.Time
	readVersion func(string) string
}

// NewServer builds the Scan service. A nil logger discards scan logs.
func NewServer(st *store.Store, state RunState, logger *slog.Logger) *Server {
	if logger == nil {
		logger = slog.New(slog.DiscardHandler)
	}
	return &Server{
		store:       st,
		state:       state,
		logger:      logger,
		now:         func() time.Time { return time.Now().UTC() },
		readVersion: peversion.Read,
	}
}

// StartScan streams one scan of the requested sources. A second concurrent
// call fails with SCAN_IN_PROGRESS before any event is sent.
func (s *Server) StartScan(req *dlssv1.StartScanRequest, stream dlssv1.Scan_StartScanServer) error {
	if !s.running.CompareAndSwap(false, true) {
		return contract.Detail{
			Reason:    contract.ReasonScanInProgress,
			Retryable: true,
		}.Err("A scan is already running. Wait for it to finish before starting another.")
	}
	ctx := stream.Context()
	logger := logging.From(ctx, s.logger)
	startedAt := s.now()
	s.state.SetScanRunning(true)
	defer func() {
		s.running.Store(false)
		s.state.SetScanRunning(false)
	}()

	sources := sourcesFromRequest(req)
	if len(sources) == 0 {
		message := "Choose a Steam folder or add a custom game folder before scanning."
		logger.ErrorContext(ctx, "scan rejected: no sources")
		_ = stream.Send(&dlssv1.ScanEvent{Event: &dlssv1.ScanEvent_Failed{
			Failed: &dlssv1.ScanFailed{Reason: string(contract.ReasonScanRootInvalid), Message: message},
		}})
		return contract.Detail{Reason: contract.ReasonScanRootInvalid}.Err(message)
	}

	plan, err := buildScanPlan(ctx, sources)
	if err != nil {
		logger.ErrorContext(ctx, "scan sources rejected", "sources", len(sources), "error", err)
		path := ""
		if len(plan.Warnings) > 0 {
			path = plan.Warnings[0].Path
		}
		message := "None of the selected scan sources can be read. Choose a folder that exists and is readable."
		_ = stream.Send(&dlssv1.ScanEvent{Event: &dlssv1.ScanEvent_Failed{
			Failed: &dlssv1.ScanFailed{Reason: string(contract.ReasonScanRootInvalid), Message: message},
		}})
		return contract.Detail{Reason: contract.ReasonScanRootInvalid, Path: path}.Err(message)
	}
	logger.InfoContext(ctx, "scan started", "sources", len(sources), "units", len(plan.Units))

	if err := stream.Send(&dlssv1.ScanEvent{Event: &dlssv1.ScanEvent_Started{
		Started: &dlssv1.ScanStarted{SteamRoot: plan.SteamRoot, StartedAt: timestamppb.New(startedAt)},
	}}); err != nil {
		return streams.Error(ctx, "The scan stream could not be written.")
	}
	for _, w := range plan.Warnings {
		if err := sendWarning(stream, w); err != nil {
			return streams.Error(ctx, "The scan stream could not be written.")
		}
	}

	var (
		gamesFound int32
		dllsFound  int32
		seenGames  = realPathSet{}
		seenDLLs   = realPathSet{}
	)
	// One progress event per source/game is more detail than a UI can use; the
	// emitter keeps the first event immediate, coalesces the rest by time and
	// drops exact duplicates, and is flushed before the summary.
	progress := newProgressEmitter(func(p *dlssv1.ScanLibraryProgress) error {
		return stream.Send(&dlssv1.ScanEvent{Event: &dlssv1.ScanEvent_LibraryProgress{LibraryProgress: p}})
	}, s.now)
	report := func(unit scanUnit, currentGame string) error {
		return progress.send(&dlssv1.ScanLibraryProgress{
			LibraryPath:  unit.Path,
			LibraryIndex: int32(unit.SourceIndex),
			LibraryCount: int32(unit.SourceCount),
			CurrentGame:  currentGame,
			GamesFound:   gamesFound,
			DllsFound:    dllsFound,
		})
	}

	for _, unit := range plan.Units {
		if ctx.Err() != nil {
			return s.finishCancelled(ctx, stream, progress, startedAt, gamesFound, dllsFound)
		}
		if err := report(unit, ""); err != nil {
			return streams.Error(ctx, "The scan stream could not be written.")
		}

		for _, g := range unit.Games {
			if ctx.Err() != nil {
				return s.finishCancelled(ctx, stream, progress, startedAt, gamesFound, dllsFound)
			}
			if !seenGames.add(g.InstallPath) {
				continue
			}
			if err := report(unit, g.Name); err != nil {
				return streams.Error(ctx, "The scan stream could not be written.")
			}

			files, fileWarnings, err := findDLLs(ctx, g.InstallPath, seenDLLs, plan.Protected)
			for _, w := range fileWarnings {
				if sendErr := sendWarning(stream, w); sendErr != nil {
					return streams.Error(ctx, "The scan stream could not be written.")
				}
			}
			if err != nil {
				if ctx.Err() != nil {
					return s.finishCancelled(ctx, stream, progress, startedAt, gamesFound, dllsFound)
				}
				if warnErr := sendWarning(stream, warning{
					Path:    g.InstallPath,
					Message: "This game directory is missing or unreadable; the game is skipped.",
				}); warnErr != nil {
					return streams.Error(ctx, "The scan stream could not be written.")
				}
				logger.WarnContext(ctx, "game directory skipped", "path", g.InstallPath, "error", err)
				continue
			}
			if ctx.Err() != nil {
				return s.finishCancelled(ctx, stream, progress, startedAt, gamesFound, dllsFound)
			}
			if len(files) == 0 && unit.Kind == sourceCustomFolder {
				if warnErr := sendWarning(stream, warning{
					Path:    g.InstallPath,
					Message: "No known technology DLLs were found in this folder.",
				}); warnErr != nil {
					return streams.Error(ctx, "The scan stream could not be written.")
				}
			}

			gameTime := s.now()
			inputs := make([]store.DLLInput, 0, len(files))
			for _, file := range files {
				inputs = append(inputs, store.DLLInput{
					Type:       file.Type,
					Filename:   file.Filename,
					Path:       file.Path,
					Version:    s.readVersion(file.Path),
					DetectedAt: gameTime,
				})
			}
			synced, err := s.store.SyncGame(ctx, store.GameInput{
				AppID:       g.AppID,
				Name:        g.Name,
				Path:        g.InstallPath,
				LibraryPath: g.LibraryRoot,
				ScannedAt:   gameTime,
			}, inputs, gameTime)
			if err != nil {
				if ctx.Err() != nil {
					return s.finishCancelled(ctx, stream, progress, startedAt, gamesFound, dllsFound)
				}
				logger.ErrorContext(ctx, "persist scanned game", "path", g.InstallPath, "error", err)
				message := "The scan result could not be saved. Rescan once the data directory is writable."
				_ = stream.Send(&dlssv1.ScanEvent{Event: &dlssv1.ScanEvent_Failed{
					Failed: &dlssv1.ScanFailed{Reason: string(contract.ReasonMetadataStale), Message: message},
				}})
				return contract.Detail{
					Reason:    contract.ReasonMetadataStale,
					Path:      g.InstallPath,
					Retryable: true,
				}.Err(message)
			}

			gamesFound++
			dllsFound += int32(len(synced.DLLs))
			if err := stream.Send(&dlssv1.ScanEvent{Event: &dlssv1.ScanEvent_GameFound{
				GameFound: protomap.Game(synced),
			}}); err != nil {
				return streams.Error(ctx, "The scan stream could not be written.")
			}
			if err := report(unit, ""); err != nil {
				return streams.Error(ctx, "The scan stream could not be written.")
			}
		}
	}

	if err := progress.flush(); err != nil {
		return streams.Error(ctx, "The scan stream could not be written.")
	}
	if err := stream.Send(&dlssv1.ScanEvent{Event: &dlssv1.ScanEvent_Finished{
		Finished: &dlssv1.ScanFinished{
			GameCount:  gamesFound,
			DllCount:   dllsFound,
			Cancelled:  false,
			DurationMs: s.now().Sub(startedAt).Milliseconds(),
		},
	}}); err != nil {
		return streams.Error(ctx, "The scan stream could not be written.")
	}
	logger.InfoContext(ctx, "scan finished",
		"games", gamesFound, "dlls", dllsFound,
		"duration_ms", s.now().Sub(startedAt).Milliseconds())
	return nil
}

// finishCancelled makes one best-effort attempt to deliver the cancelled
// summary. A client that cancelled the stream has already closed it, so gRPC
// normally rejects that send; the persisted rows are the durable evidence.
func (s *Server) finishCancelled(ctx context.Context, stream dlssv1.Scan_StartScanServer, progress *progressEmitter, startedAt time.Time, games, dlls int32) error {
	logging.From(ctx, s.logger).InfoContext(ctx, "scan cancelled", "games", games, "dlls", dlls)
	_ = progress.flush()
	return streams.Cancelled(ctx, func() error {
		return stream.Send(&dlssv1.ScanEvent{Event: &dlssv1.ScanEvent_Finished{
			Finished: &dlssv1.ScanFinished{
				GameCount:  games,
				DllCount:   dlls,
				Cancelled:  true,
				DurationMs: s.now().Sub(startedAt).Milliseconds(),
			},
		}})
	}, "Scan cancelled.")
}

func sendWarning(stream dlssv1.Scan_StartScanServer, w warning) error {
	return stream.Send(&dlssv1.ScanEvent{Event: &dlssv1.ScanEvent_Warning{
		Warning: &dlssv1.ScanWarning{Path: w.Path, Message: w.Message},
	}})
}
