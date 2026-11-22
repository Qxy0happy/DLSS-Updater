// Package update implements dlss.v1.Update: it replaces selected game DLLs
// with files from the configured DLL source directory, one file at a time. For
// every real replacement it writes a .dlsss backup first, swaps the file in
// atomically, verifies the version afterwards and records the result in one
// store transaction.
package update

import (
	"context"
	"errors"
	"io/fs"
	"log/slog"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync/atomic"
	"syscall"
	"time"

	"golang.org/x/sys/unix"
	"google.golang.org/protobuf/types/known/timestamppb"

	dlssv1 "github.com/Qxy0happy/DLSS-Updater/backend/gen/dlss/v1"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/contract"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/fileops"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/logging"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/peversion"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/store"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/streams"
)

// RunState is the process-wide update flag Daemon.GetStatus reports.
type RunState interface {
	SetUpdateRunning(bool)
}

// Item reason tokens carried by UpdateItemFinished. They are item outcomes,
// not gRPC status reasons; both share the stable spelling.
const (
	reasonUpToDate         = "UP_TO_DATE"
	reasonBelowMinimum     = "BELOW_MINIMUM"
	reasonTargetMissing    = string(contract.ReasonTargetMissing)
	reasonSourceMissing    = string(contract.ReasonSourceMissing)
	reasonPermissionDenied = string(contract.ReasonPermissionDenied)
	reasonVersionMismatch  = string(contract.ReasonVersionMismatch)
	reasonMetadataStale    = string(contract.ReasonMetadataStale)
	reasonInternal         = string(contract.ReasonInternal)
)

// Server implements dlss.v1.Update. It owns the one-update-at-a-time rule and
// processes items serially in request order.
type Server struct {
	dlssv1.UnimplementedUpdateServer

	store     *store.Store
	state     RunState
	sourceDir string
	logger    *slog.Logger
	running   atomic.Bool

	now         func() time.Time
	readVersion func(string) string
	// verifyVersion re-reads a target after replacement. The integration build
	// can override it to force a deterministic verification failure.
	verifyVersion func(string) string
}

// NewServer builds the Update service. A nil logger discards update logs.
func NewServer(st *store.Store, state RunState, sourceDir string, logger *slog.Logger) *Server {
	if logger == nil {
		logger = slog.New(slog.DiscardHandler)
	}
	return &Server{
		store:         st,
		state:         state,
		sourceDir:     sourceDir,
		logger:        logger,
		now:           func() time.Time { return time.Now().UTC() },
		readVersion:   peversion.Read,
		verifyVersion: postReplaceVersion,
	}
}

// itemResult is the observable outcome of processing one requested DLL.
type itemResult struct {
	outcome  dlssv1.UpdateOutcome
	reason   string
	backupID string
	version  string
}

// StartUpdate replaces the requested DLLs in order and streams one event per
// transition. A second concurrent call fails with UPDATE_IN_PROGRESS before
// any event is sent.
func (s *Server) StartUpdate(req *dlssv1.StartUpdateRequest, stream dlssv1.Update_StartUpdateServer) error {
	if !s.running.CompareAndSwap(false, true) {
		return contract.Detail{
			Reason:    contract.ReasonUpdateInProgress,
			Retryable: true,
		}.Err("An update is already running. Wait for it to finish before starting another.")
	}
	ctx := stream.Context()
	logger := logging.From(ctx, s.logger)
	startedAt := s.now()
	s.state.SetUpdateRunning(true)
	defer func() {
		s.running.Store(false)
		s.state.SetUpdateRunning(false)
	}()

	ids := req.GetDllIds()
	if err := stream.Send(&dlssv1.UpdateEvent{Event: &dlssv1.UpdateEvent_Started{
		Started: &dlssv1.UpdateStarted{
			ItemCount: int32(len(ids)),
			StartedAt: timestamppb.New(startedAt),
		},
	}}); err != nil {
		return streams.Error(ctx, "The update stream could not be written.")
	}
	logger.InfoContext(ctx, "update started", "items", len(ids))

	var succeeded, skipped, failed int32
	for index, rawID := range ids {
		// Cancellation is only observed between files; the item below either
		// completes atomically or leaves its target untouched.
		if ctx.Err() != nil {
			return s.finishCancelled(ctx, stream, startedAt, succeeded, skipped, failed)
		}
		// The stream context may be cancelled at any moment; item bookkeeping
		// must still finish so a completed replacement is persisted.
		itemCtx := context.WithoutCancel(ctx)
		dll, lookupErr := s.lookup(itemCtx, rawID)
		if err := stream.Send(&dlssv1.UpdateEvent{Event: &dlssv1.UpdateEvent_ItemStarted{
			ItemStarted: &dlssv1.UpdateItemStarted{
				DllId:    rawID,
				Filename: dll.Filename,
				Index:    int32(index + 1),
				Total:    int32(len(ids)),
			},
		}}); err != nil {
			return streams.Error(ctx, "The update stream could not be written.")
		}

		itemStart := s.now()
		result := s.applyItem(itemCtx, logger, dll, lookupErr)
		switch result.outcome {
		case dlssv1.UpdateOutcome_UPDATE_OUTCOME_UPDATED:
			succeeded++
		case dlssv1.UpdateOutcome_UPDATE_OUTCOME_SKIPPED:
			skipped++
		case dlssv1.UpdateOutcome_UPDATE_OUTCOME_FAILED:
			failed++
		}
		if err := stream.Send(&dlssv1.UpdateEvent{Event: &dlssv1.UpdateEvent_ItemFinished{
			ItemFinished: &dlssv1.UpdateItemFinished{
				DllId:            rawID,
				Outcome:          result.outcome,
				Reason:           result.reason,
				BackupId:         result.backupID,
				ResultingVersion: result.version,
				DurationMs:       s.now().Sub(itemStart).Milliseconds(),
			},
		}}); err != nil {
			return streams.Error(ctx, "The update stream could not be written.")
		}
		logger.InfoContext(ctx, "update item finished",
			"dll_id", rawID,
			"outcome", result.outcome.String(),
			"reason", result.reason,
			"duration_ms", s.now().Sub(itemStart).Milliseconds())
	}

	if err := stream.Send(&dlssv1.UpdateEvent{Event: &dlssv1.UpdateEvent_Finished{
		Finished: &dlssv1.UpdateFinished{
			Succeeded:  succeeded,
			Skipped:    skipped,
			Failed:     failed,
			Cancelled:  false,
			DurationMs: s.now().Sub(startedAt).Milliseconds(),
		},
	}}); err != nil {
		return streams.Error(ctx, "The update stream could not be written.")
	}
	logger.InfoContext(ctx, "update finished",
		"succeeded", succeeded, "skipped", skipped, "failed", failed)
	return nil
}

// lookup resolves one requested id to its stored DLL row. A missing row stays
// a per-item TARGET_MISSING; a broken store is reported as INTERNAL.
func (s *Server) lookup(ctx context.Context, rawID string) (store.DLL, error) {
	id, err := strconv.ParseInt(strings.TrimSpace(rawID), 10, 64)
	if err != nil || id <= 0 {
		return store.DLL{}, store.ErrNotFound
	}
	dll, err := s.store.GetDLL(ctx, id)
	if errors.Is(err, store.ErrNotFound) {
		return store.DLL{}, store.ErrNotFound
	}
	if err != nil {
		logging.From(ctx, s.logger).ErrorContext(ctx, "read DLL for update", "dll_id", rawID, "error", err)
		return store.DLL{}, err
	}
	return dll, nil
}

// applyItem validates, backs up, replaces, verifies and records one DLL.
func (s *Server) applyItem(ctx context.Context, logger *slog.Logger, dll store.DLL, lookupErr error) itemResult {
	if lookupErr != nil {
		if errors.Is(lookupErr, store.ErrNotFound) {
			return failure(reasonTargetMissing)
		}
		return failure(reasonInternal)
	}

	target := dll.Path
	info, err := os.Stat(target)
	if err != nil || !info.Mode().IsRegular() {
		return failure(reasonTargetMissing)
	}
	if err := unix.Access(filepath.Dir(target), unix.W_OK); err != nil {
		return failure(reasonPermissionDenied)
	}
	sourcePath, ok := findSource(s.sourceDir, dll.Filename)
	if !ok {
		return failure(reasonSourceMissing)
	}

	targetVersion := s.readVersion(target)
	sourceVersion := s.readVersion(sourcePath)
	if belowMinimum(dll.Filename, targetVersion) {
		return itemResult{
			outcome: dlssv1.UpdateOutcome_UPDATE_OUTCOME_SKIPPED,
			reason:  reasonBelowMinimum,
			version: targetVersion,
		}
	}
	if compareVersions(targetVersion, sourceVersion) >= 0 {
		return itemResult{
			outcome: dlssv1.UpdateOutcome_UPDATE_OUTCOME_SKIPPED,
			reason:  reasonUpToDate,
			version: targetVersion,
		}
	}

	game, err := s.store.GetGame(ctx, dll.GameID)
	if err != nil {
		logger.ErrorContext(ctx, "read game for update", "dll_id", dll.ID, "error", err)
		return failure(reasonInternal)
	}

	backupPath := backupPathFor(target)
	if err := fileops.AtomicCopy(target, backupPath, 0o600); err != nil {
		return failure(fileReason(err, reasonTargetMissing))
	}
	if err := fileops.AtomicCopy(sourcePath, target, info.Mode().Perm()); err != nil {
		return failure(fileReason(err, reasonSourceMissing))
	}

	if verified := s.verifyVersion(target); verified != sourceVersion {
		logger.ErrorContext(ctx, "update verification failed",
			"path", target, "expected", sourceVersion, "got", verified)
		if err := fileops.AtomicCopy(backupPath, target, info.Mode().Perm()); err != nil {
			// The target was not restored, so the backup stays as the only
			// copy of the original bytes.
			logger.ErrorContext(ctx, "restore backup after verification failure",
				"path", target, "error", err)
			return failure(reasonInternal)
		}
		removeRollbackBackup(ctx, logger, backupPath)
		return itemResult{
			outcome: dlssv1.UpdateOutcome_UPDATE_OUTCOME_FAILED,
			reason:  reasonVersionMismatch,
			version: targetVersion,
		}
	}

	backupInfo, err := os.Stat(backupPath)
	if err != nil {
		logger.ErrorContext(ctx, "stat backup", "path", backupPath, "error", err)
		return itemResult{
			outcome: dlssv1.UpdateOutcome_UPDATE_OUTCOME_FAILED,
			reason:  reasonMetadataStale,
			version: sourceVersion,
		}
	}
	backup, err := s.store.RecordUpdate(ctx, store.UpdateRecordInput{
		GameDLLID:         dll.ID,
		GameName:          game.Name,
		DLLType:           dll.Type,
		DLLFilename:       dll.Filename,
		BackupPath:        backupPath,
		OriginalVersion:   targetVersion,
		PostUpdateVersion: sourceVersion,
		SizeBytes:         backupInfo.Size(),
		UpdatedAt:         s.now(),
	})
	if err != nil {
		// The file is already replaced; never roll it back because metadata
		// failed. The client rescans to refresh stale rows.
		logger.ErrorContext(ctx, "record update metadata", "path", target, "error", err)
		return itemResult{
			outcome: dlssv1.UpdateOutcome_UPDATE_OUTCOME_FAILED,
			reason:  reasonMetadataStale,
			version: sourceVersion,
		}
	}
	return itemResult{
		outcome:  dlssv1.UpdateOutcome_UPDATE_OUTCOME_UPDATED,
		backupID: strconv.FormatInt(backup.ID, 10),
		version:  sourceVersion,
	}
}

func failure(reason string) itemResult {
	return itemResult{outcome: dlssv1.UpdateOutcome_UPDATE_OUTCOME_FAILED, reason: reason}
}

// fileReason maps a filesystem error to an item reason. Permission failures
// keep their own reason; a vanished source or target falls back to the reason
// the caller knows for its context; every other write failure (out of space,
// I/O error, read-only mount reported as EROFS) is an internal error, never a
// misleading SOURCE_MISSING.
func fileReason(err error, fallback string) string {
	switch {
	case errors.Is(err, fs.ErrPermission), errors.Is(err, syscall.EROFS):
		return reasonPermissionDenied
	case errors.Is(err, fs.ErrNotExist):
		return fallback
	default:
		return reasonInternal
	}
}

// removeRollbackBackup deletes the .dlsss file after the target was restored
// from it. The file is redundant and has no store row; failing to remove it
// leaves a stray file but does not change the item outcome.
func removeRollbackBackup(ctx context.Context, logger *slog.Logger, backupPath string) {
	if err := os.Remove(backupPath); err != nil {
		if !errors.Is(err, fs.ErrNotExist) {
			logger.WarnContext(ctx, "remove redundant backup after rollback",
				"path", backupPath, "error", err)
		}
		return
	}
	if err := fileops.SyncDir(filepath.Dir(backupPath)); err != nil {
		logger.WarnContext(ctx, "sync directory after backup removal",
			"path", backupPath, "error", err)
	}
}

// finishCancelled makes one best-effort attempt to deliver the cancelled
// summary. A client that cancelled the stream has already closed it, so gRPC
// normally rejects that send; the persisted rows are the durable evidence.
func (s *Server) finishCancelled(ctx context.Context, stream dlssv1.Update_StartUpdateServer, startedAt time.Time, succeeded, skipped, failed int32) error {
	logging.From(ctx, s.logger).InfoContext(ctx, "update cancelled",
		"succeeded", succeeded, "skipped", skipped, "failed", failed)
	return streams.Cancelled(ctx, func() error {
		return stream.Send(&dlssv1.UpdateEvent{Event: &dlssv1.UpdateEvent_Finished{
			Finished: &dlssv1.UpdateFinished{
				Succeeded:  succeeded,
				Skipped:    skipped,
				Failed:     failed,
				Cancelled:  true,
				DurationMs: s.now().Sub(startedAt).Milliseconds(),
			},
		}})
	}, "Update cancelled.")
}
