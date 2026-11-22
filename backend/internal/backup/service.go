// Package backup implements dlss.v1.Backup: it lists the `.dlsss` records the
// update path created, puts a backup back in place of its target, and removes
// backups the user no longer needs.
//
// Restore follows the same discipline as update: a safety copy of the current
// target is made first, the backup is copied through a mode-preserving
// temporary file and atomically renamed over the target, the version is read
// back, and any failure after the replacement is rolled back from the safety
// copy. Metadata is committed in one transaction after the file is in place; a
// metadata failure never undoes a successful file restore.
package backup

import (
	"context"
	"errors"
	"io/fs"
	"log/slog"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"google.golang.org/protobuf/types/known/timestamppb"

	dlssv1 "github.com/Qxy0happy/DLSS-Updater/backend/gen/dlss/v1"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/contract"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/fileops"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/logging"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/peversion"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/protomap"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/store"
)

// RunState reports whether a file-modifying update is running. Restoring a
// backup while an update writes the same targets is unsafe, so the restore is
// refused with an actionable reason instead of racing it.
type RunState interface {
	UpdateRunning() bool
}

// Server implements dlss.v1.Backup.
type Server struct {
	dlssv1.UnimplementedBackupServer

	store  *store.Store
	state  RunState
	logger *slog.Logger

	// mu serializes restore and delete. The daemon serves RPCs concurrently
	// and both operations move the same files; one at a time keeps the
	// file-then-record ordering meaningful.
	mu sync.Mutex

	now         func() time.Time
	readVersion func(string) string
}

// NewServer builds the Backup service. A nil logger discards backup logs.
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

// ListBackups returns active backups by default and the whole history when
// asked. Every record carries its target's current existence so the client can
// group orphaned backups. A record whose target is gone is still listed.
func (s *Server) ListBackups(ctx context.Context, req *dlssv1.ListBackupsRequest) (*dlssv1.ListBackupsResponse, error) {
	logger := logging.From(ctx, s.logger)
	filter := store.BackupFilter{IncludeInactive: req.GetIncludeInactive()}
	if raw := strings.TrimSpace(req.GetGameId()); raw != "" {
		id, err := strconv.ParseInt(raw, 10, 64)
		if err != nil || id <= 0 {
			return nil, contract.Detail{
				Reason: contract.ReasonTargetMissing,
			}.Err("Game " + strconv.Quote(raw) + " was not found.")
		}
		filter.GameID = id
	}

	backups, err := s.store.ListBackups(ctx, filter)
	if err != nil {
		logger.ErrorContext(ctx, "list backups", "game_id", filter.GameID, "error", err)
		return nil, contract.Detail{
			Reason:    contract.ReasonInternal,
			Retryable: true,
		}.Err("The backup list could not be read.")
	}
	resp := &dlssv1.ListBackupsResponse{Backups: make([]*dlssv1.BackupRecord, 0, len(backups))}
	for _, b := range backups {
		resp.Backups = append(resp.Backups, s.protoRecord(b))
	}
	return resp, nil
}

// RestoreBackup puts one backup back in place of its target. The backup file
// and its recorded size are validated before the target is touched; the
// target's parent directory must already exist.
func (s *Server) RestoreBackup(ctx context.Context, req *dlssv1.RestoreBackupRequest) (*dlssv1.RestoreBackupResponse, error) {
	logger := logging.From(ctx, s.logger)
	id, err := parseID(req.GetBackupId())
	if err != nil {
		return nil, missingBackup(req.GetBackupId())
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	if s.state != nil && s.state.UpdateRunning() {
		return nil, contract.Detail{
			Reason:    contract.ReasonUpdateInProgress,
			Retryable: true,
		}.Err("An update is running. Wait for it to finish before restoring a backup.")
	}

	b, err := s.store.GetBackup(ctx, id)
	if errors.Is(err, store.ErrNotFound) {
		return nil, missingBackup(req.GetBackupId())
	}
	if err != nil {
		logger.ErrorContext(ctx, "read backup", "backup_id", id, "error", err)
		return nil, contract.Detail{
			Reason:    contract.ReasonInternal,
			Retryable: true,
		}.Err("The backup record could not be read.")
	}
	logger.InfoContext(ctx, "restore started", "backup_id", id, "path", b.TargetPath)
	return s.restore(ctx, logger, b)
}

func (s *Server) restore(ctx context.Context, logger *slog.Logger, b store.Backup) (*dlssv1.RestoreBackupResponse, error) {
	backupInfo, err := os.Stat(b.BackupPath)
	switch {
	case errors.Is(err, fs.ErrNotExist):
		return nil, contract.Detail{
			Reason: contract.ReasonBackupMissing,
			Path:   b.BackupPath,
		}.Err("The backup file is missing. It may have been deleted.")
	case err != nil:
		return nil, s.fileError(err, b.BackupPath, "The backup file could not be read.")
	case !backupInfo.Mode().IsRegular():
		return nil, contract.Detail{
			Reason: contract.ReasonBackupCorrupt,
			Path:   b.BackupPath,
		}.Err("The backup path does not hold a regular file.")
	}
	if backupInfo.Size() != b.SizeBytes {
		logger.ErrorContext(ctx, "backup size mismatch",
			"path", b.BackupPath, "expected", b.SizeBytes, "actual", backupInfo.Size())
		return nil, contract.Detail{
			Reason: contract.ReasonBackupCorrupt,
			Path:   b.BackupPath,
		}.Err("The backup file size does not match its record. It may be corrupted.")
	}

	target := b.TargetPath
	if target == "" {
		return nil, contract.Detail{
			Reason: contract.ReasonInternal,
		}.Err("The backup is not linked to a target file.")
	}
	folder := filepath.Dir(target)
	folderInfo, err := os.Stat(folder)
	switch {
	case errors.Is(err, fs.ErrNotExist):
		return nil, contract.Detail{
			Reason: contract.ReasonTargetFolderMissing,
			Path:   folder,
		}.Err("The folder that holds the target DLL is missing. The game may have been uninstalled or moved.")
	case err != nil:
		return nil, s.fileError(err, folder, "The target folder could not be read.")
	case !folderInfo.IsDir():
		return nil, contract.Detail{
			Reason: contract.ReasonTargetFolderMissing,
			Path:   folder,
		}.Err("The folder that holds the target DLL is missing. The game may have been uninstalled or moved.")
	}

	targetInfo, err := os.Stat(target)
	targetExists := err == nil
	switch {
	case err != nil && !errors.Is(err, fs.ErrNotExist):
		return nil, s.fileError(err, target, "The target DLL could not be read.")
	case targetExists && !targetInfo.Mode().IsRegular():
		return nil, contract.Detail{
			Reason: contract.ReasonTargetMissing,
			Path:   target,
		}.Err("The target path does not hold a regular file.")
	}

	// The restored file keeps the target's permissions; an orphan has no
	// target to copy them from, so the backup's own mode is used.
	mode := backupInfo.Mode().Perm()
	if targetExists {
		mode = targetInfo.Mode().Perm()
	}

	safetyPath := ""
	if targetExists {
		safetyPath, err = fileops.SafetyCopy(target, mode)
		if err != nil {
			return nil, s.fileError(err, target, "A safety copy of the current DLL could not be created.")
		}
		defer func() { _ = os.Remove(safetyPath) }()
	}

	if err := fileops.AtomicCopy(b.BackupPath, target, mode); err != nil {
		s.rollback(logger, target, safetyPath, mode)
		return nil, s.fileError(err, target, "The backup could not be put back. The target was left unchanged.")
	}
	if err := postReplaceCheck(target); err != nil {
		logger.ErrorContext(ctx, "restore verification failed", "path", target, "error", err)
		s.rollback(logger, target, safetyPath, mode)
		return nil, contract.Detail{
			Reason: contract.ReasonInternal,
			Path:   target,
		}.Err("The restored file failed verification. The previous file was put back.")
	}

	version := s.readVersion(target)
	restored, err := s.store.RecordRestore(ctx, store.RestoreInput{
		BackupID:   b.ID,
		GameDLLID:  b.GameDLLID,
		Version:    version,
		RestoredAt: s.now(),
	})
	if err != nil {
		// The file is already restored; never roll it back because metadata
		// failed. A rescan refreshes the stale rows.
		logger.ErrorContext(ctx, "record restore metadata", "path", target, "error", err)
		return nil, contract.Detail{
			Reason:    contract.ReasonMetadataStale,
			Path:      target,
			Retryable: true,
		}.Err("The file was restored, but its metadata could not be saved. Rescan the library.")
	}
	dll, err := s.store.GetDLL(ctx, b.GameDLLID)
	if err != nil {
		logger.ErrorContext(ctx, "read restored DLL", "dll_id", b.GameDLLID, "error", err)
		return nil, contract.Detail{
			Reason:    contract.ReasonMetadataStale,
			Path:      target,
			Retryable: true,
		}.Err("The file was restored, but its metadata could not be read. Rescan the library.")
	}
	logger.InfoContext(ctx, "restore finished", "backup_id", b.ID, "path", target)
	return &dlssv1.RestoreBackupResponse{
		Dll:    protomap.DLL(dll),
		Backup: s.protoRecord(restored),
	}, nil
}

// rollback puts the pre-restore bytes back. An orphan had no target, so a
// rollback removes whatever the failed replacement may have created.
func (s *Server) rollback(logger *slog.Logger, target, safetyPath string, mode os.FileMode) {
	if safetyPath == "" {
		if err := os.Remove(target); err != nil && !errors.Is(err, fs.ErrNotExist) {
			logger.Error("remove partially restored target", "path", target, "error", err)
			return
		}
		if err := fileops.SyncDir(filepath.Dir(target)); err != nil {
			logger.Error("sync target directory after rollback", "path", target, "error", err)
		}
		return
	}
	if err := fileops.AtomicCopy(safetyPath, target, mode); err != nil {
		logger.Error("roll target back from safety copy", "path", target, "error", err)
	}
}

// DeleteBackup removes the `.dlsss` file first and only then deletes the record,
// so a failed file delete never leaves a silent "record gone, file remains"
// state. A file that is already gone still allows the record to be removed; a
// deleted backup never reappears in the history list.
func (s *Server) DeleteBackup(ctx context.Context, req *dlssv1.DeleteBackupRequest) (*dlssv1.DeleteBackupResponse, error) {
	logger := logging.From(ctx, s.logger)
	id, err := parseID(req.GetBackupId())
	if err != nil {
		return nil, missingBackup(req.GetBackupId())
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	if s.state != nil && s.state.UpdateRunning() {
		return nil, contract.Detail{
			Reason:    contract.ReasonUpdateInProgress,
			Retryable: true,
		}.Err("An update is running. Wait for it to finish before deleting a backup.")
	}

	b, err := s.store.GetBackup(ctx, id)
	if errors.Is(err, store.ErrNotFound) {
		return nil, missingBackup(req.GetBackupId())
	}
	if err != nil {
		logger.ErrorContext(ctx, "read backup", "backup_id", id, "error", err)
		return nil, contract.Detail{
			Reason:    contract.ReasonInternal,
			Retryable: true,
		}.Err("The backup record could not be read.")
	}

	if err := os.Remove(b.BackupPath); err != nil && !errors.Is(err, fs.ErrNotExist) {
		logger.ErrorContext(ctx, "delete backup file", "path", b.BackupPath, "error", err)
		return nil, s.fileError(err, b.BackupPath, "The backup file could not be deleted.")
	}
	if err := s.store.DeleteBackup(ctx, b.ID); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			// A concurrent delete removed the row; the file is gone either way.
			return &dlssv1.DeleteBackupResponse{}, nil
		}
		logger.ErrorContext(ctx, "delete backup record", "backup_id", b.ID, "error", err)
		return nil, contract.Detail{
			Reason:    contract.ReasonMetadataStale,
			Path:      b.BackupPath,
			Retryable: true,
		}.Err("The backup file was deleted, but its record could not be removed. Rescan the library.")
	}
	logger.InfoContext(ctx, "backup deleted", "backup_id", b.ID, "path", b.BackupPath)
	return &dlssv1.DeleteBackupResponse{}, nil
}

// fileError maps a filesystem failure to the stable reason set.
func (s *Server) fileError(err error, path, message string) error {
	reason := contract.ReasonInternal
	if errors.Is(err, fs.ErrPermission) || errors.Is(err, syscall.EROFS) {
		reason = contract.ReasonPermissionDenied
	}
	return contract.Detail{Reason: reason, Path: path}.Err(message)
}

func (s *Server) protoRecord(b store.Backup) *dlssv1.BackupRecord {
	record := &dlssv1.BackupRecord{
		Id:              strconv.FormatInt(b.ID, 10),
		GameId:          strconv.FormatInt(b.GameID, 10),
		DllId:           strconv.FormatInt(b.GameDLLID, 10),
		GameName:        b.GameName,
		DllFilename:     b.DLLFilename,
		DllType:         b.DLLType,
		BackupPath:      b.BackupPath,
		OriginalVersion: b.OriginalVersion,
		SizeBytes:       b.SizeBytes,
		CreatedAt:       timestamppb.New(b.CreatedAt),
		IsActive:        b.IsActive,
		TargetExists:    fileops.Exists(b.TargetPath),
	}
	if b.RestoredAt != nil {
		record.RestoredAt = timestamppb.New(*b.RestoredAt)
	}
	return record
}

func parseID(raw string) (int64, error) {
	id, err := strconv.ParseInt(strings.TrimSpace(raw), 10, 64)
	if err != nil || id <= 0 {
		return 0, errInvalidID
	}
	return id, nil
}

var errInvalidID = errors.New("backup: invalid id")

func missingBackup(raw string) error {
	return contract.Detail{
		Reason: contract.ReasonBackupMissing,
	}.Err("Backup " + strconv.Quote(raw) + " was not found.")
}
