package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"
)

// UpdateRecordInput is the metadata of one successful DLL replacement. It is
// committed by RecordUpdate in a single transaction together with the backup
// row and the update-history row.
type UpdateRecordInput struct {
	GameDLLID int64
	GameName  string
	DLLType   string
	// DLLFilename is the original DLL file name, for example "nvngx_dlss.dll".
	DLLFilename string
	// BackupPath is the .dlsss file already written beside the target.
	BackupPath string
	// OriginalVersion is the target version read before the replacement.
	OriginalVersion string
	// PostUpdateVersion is the version now present on disk.
	PostUpdateVersion string
	// SizeBytes is the size of the backup file.
	SizeBytes int64
	// UpdatedAt is when the replacement happened; zero means now.
	UpdatedAt time.Time
}

// GetDLL returns one DLL row by its integer id.
func (s *Store) GetDLL(ctx context.Context, id int64) (DLL, error) {
	return s.dllByID(ctx, id)
}

// RecordUpdate persists one successful DLL replacement in a single
// transaction: the previous active backup of the DLL becomes inactive (its
// file is untouched), a new active backup row is inserted with the
// post-update version, the DLL's current version moves to the new version, and
// an update-history row is appended. A missing DLL row rolls the whole
// transaction back.
func (s *Store) RecordUpdate(ctx context.Context, in UpdateRecordInput) (Backup, error) {
	if in.BackupPath == "" {
		return Backup{}, errors.New("store: backup path must not be empty")
	}
	updatedAt := stamp(in.UpdatedAt)

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return Backup{}, fmt.Errorf("store: record update for DLL %d: %w", in.GameDLLID, err)
	}
	defer func() { _ = tx.Rollback() }()

	var dllExists int64
	if err := tx.QueryRowContext(ctx, `SELECT id FROM game_dlls WHERE id = ?`, in.GameDLLID).Scan(&dllExists); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return Backup{}, fmt.Errorf("store: DLL %d: %w", in.GameDLLID, ErrNotFound)
		}
		return Backup{}, fmt.Errorf("store: read DLL %d: %w", in.GameDLLID, err)
	}

	if _, err := tx.ExecContext(ctx, `
		UPDATE dll_backups SET is_active = 0
		WHERE game_dll_id = ? AND is_active = 1`, in.GameDLLID); err != nil {
		return Backup{}, fmt.Errorf("store: deactivate previous backups of DLL %d: %w", in.GameDLLID, err)
	}

	res, err := tx.ExecContext(ctx, `
		INSERT INTO dll_backups (
			game_dll_id, game_name, dll_type, dll_filename, backup_path,
			original_version, backup_size, created_at, is_active, was_added,
			restored_at, post_update_version)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, 0, NULL, ?)`,
		in.GameDLLID, in.GameName, in.DLLType, in.DLLFilename, in.BackupPath,
		in.OriginalVersion, in.SizeBytes, updatedAt, in.PostUpdateVersion)
	if err != nil {
		return Backup{}, fmt.Errorf("store: record backup %s: %w", in.BackupPath, err)
	}
	backupID, err := res.LastInsertId()
	if err != nil {
		return Backup{}, fmt.Errorf("store: record backup %s: %w", in.BackupPath, err)
	}

	res, err = tx.ExecContext(ctx, `
		UPDATE game_dlls SET current_version = ? WHERE id = ?`,
		in.PostUpdateVersion, in.GameDLLID)
	if err != nil {
		return Backup{}, fmt.Errorf("store: update DLL %d version: %w", in.GameDLLID, err)
	}
	affected, err := res.RowsAffected()
	if err != nil {
		return Backup{}, fmt.Errorf("store: update DLL %d version: %w", in.GameDLLID, err)
	}
	if affected == 0 {
		return Backup{}, fmt.Errorf("store: DLL %d: %w", in.GameDLLID, ErrNotFound)
	}

	if _, err := tx.ExecContext(ctx, `
		INSERT INTO update_history (game_dll_id, success, from_version, to_version, updated_at)
		VALUES (?, 1, ?, ?, ?)`,
		in.GameDLLID, in.OriginalVersion, in.PostUpdateVersion, updatedAt); err != nil {
		return Backup{}, fmt.Errorf("store: record update history for DLL %d: %w", in.GameDLLID, err)
	}

	if err := tx.Commit(); err != nil {
		return Backup{}, fmt.Errorf("store: record update for DLL %d: %w", in.GameDLLID, err)
	}
	return s.GetBackup(ctx, backupID)
}
