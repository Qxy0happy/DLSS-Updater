package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"
)

// CreateBackup records a new active backup. Any other active backup of the
// same DLL becomes inactive in the same transaction; the backup file is not
// touched.
func (s *Store) CreateBackup(ctx context.Context, in BackupInput) (Backup, error) {
	if in.BackupPath == "" {
		return Backup{}, errors.New("store: backup path must not be empty")
	}
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return Backup{}, fmt.Errorf("store: create backup: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

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
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, NULL, ?)`,
		in.GameDLLID, in.GameName, in.DLLType, in.DLLFilename, in.BackupPath,
		in.OriginalVersion, in.SizeBytes, stamp(in.CreatedAt), boolInt(in.WasAdded),
		nullableString(in.PostUpdateVersion))
	if err != nil {
		return Backup{}, fmt.Errorf("store: create backup %s: %w", in.BackupPath, err)
	}
	id, err := res.LastInsertId()
	if err != nil {
		return Backup{}, fmt.Errorf("store: create backup %s: %w", in.BackupPath, err)
	}
	if err := tx.Commit(); err != nil {
		return Backup{}, fmt.Errorf("store: create backup %s: %w", in.BackupPath, err)
	}
	return s.GetBackup(ctx, id)
}

// SetBackupActive activates or deactivates a backup. Activating one backup
// deactivates any other active backup of the same DLL.
func (s *Store) SetBackupActive(ctx context.Context, id int64, active bool) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("store: set backup %d active=%v: %w", id, active, err)
	}
	defer func() { _ = tx.Rollback() }()

	if active {
		if _, err := tx.ExecContext(ctx, `
			UPDATE dll_backups SET is_active = 0
			WHERE is_active = 1 AND id <> ?
			  AND game_dll_id = (SELECT game_dll_id FROM dll_backups WHERE id = ?)`,
			id, id); err != nil {
			return fmt.Errorf("store: deactivate other backups of %d: %w", id, err)
		}
	}
	res, err := tx.ExecContext(ctx, `UPDATE dll_backups SET is_active = ? WHERE id = ?`, boolInt(active), id)
	if err != nil {
		return fmt.Errorf("store: set backup %d active=%v: %w", id, active, err)
	}
	n, err := res.RowsAffected()
	if err != nil {
		return fmt.Errorf("store: set backup %d active=%v: %w", id, active, err)
	}
	if n == 0 {
		return fmt.Errorf("store: backup %d: %w", id, ErrNotFound)
	}
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("store: set backup %d active=%v: %w", id, active, err)
	}
	return nil
}

// RestoreInput is the metadata of one completed file restore: the backup row
// becomes inactive with restored_at set, and the linked DLL takes the version
// read from the restored file. A zero RestoredAt means now.
type RestoreInput struct {
	BackupID   int64
	GameDLLID  int64
	Version    string
	RestoredAt time.Time
}

// RecordRestore commits a completed restore in one transaction: the backup
// becomes inactive with restored_at, and the DLL gets the restored version
// with missing_at cleared so an orphan resurrection is consistent. Either
// update failing rolls the transaction back.
func (s *Store) RecordRestore(ctx context.Context, in RestoreInput) (Backup, error) {
	restoredAt := stamp(in.RestoredAt)
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return Backup{}, fmt.Errorf("store: record restore of backup %d: %w", in.BackupID, err)
	}
	defer func() { _ = tx.Rollback() }()

	res, err := tx.ExecContext(ctx, `
		UPDATE dll_backups SET is_active = 0, restored_at = ?
		WHERE id = ? AND game_dll_id = ?`,
		restoredAt, in.BackupID, in.GameDLLID)
	if err != nil {
		return Backup{}, fmt.Errorf("store: mark backup %d restored: %w", in.BackupID, err)
	}
	n, err := res.RowsAffected()
	if err != nil {
		return Backup{}, fmt.Errorf("store: mark backup %d restored: %w", in.BackupID, err)
	}
	if n == 0 {
		return Backup{}, fmt.Errorf("store: backup %d: %w", in.BackupID, ErrNotFound)
	}

	res, err = tx.ExecContext(ctx, `
		UPDATE game_dlls SET current_version = ?, missing_at = NULL WHERE id = ?`,
		in.Version, in.GameDLLID)
	if err != nil {
		return Backup{}, fmt.Errorf("store: update restored DLL %d: %w", in.GameDLLID, err)
	}
	n, err = res.RowsAffected()
	if err != nil {
		return Backup{}, fmt.Errorf("store: update restored DLL %d: %w", in.GameDLLID, err)
	}
	if n == 0 {
		return Backup{}, fmt.Errorf("store: DLL %d: %w", in.GameDLLID, ErrNotFound)
	}

	if err := tx.Commit(); err != nil {
		return Backup{}, fmt.Errorf("store: record restore of backup %d: %w", in.BackupID, err)
	}
	return s.GetBackup(ctx, in.BackupID)
}

// ListBackups returns backups newest first. Active backups only unless the
// filter asks for inactive ones as well.
func (s *Store) ListBackups(ctx context.Context, filter BackupFilter) ([]Backup, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT `+backupColumns+`
		FROM dll_backups b
		JOIN game_dlls d ON d.id = b.game_dll_id
		WHERE (? = 0 OR d.game_id = ?)
		  AND (? = 1 OR b.is_active = 1)
		ORDER BY b.created_at DESC, b.id DESC`,
		filter.GameID, filter.GameID, boolInt(filter.IncludeInactive))
	if err != nil {
		return nil, fmt.Errorf("store: list backups: %w", err)
	}
	defer rows.Close()

	backups := []Backup{}
	for rows.Next() {
		b, err := scanBackup(rows)
		if err != nil {
			return nil, fmt.Errorf("store: list backups: %w", err)
		}
		backups = append(backups, b)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("store: list backups: %w", err)
	}
	return backups, nil
}

// GetBackup returns one backup record.
func (s *Store) GetBackup(ctx context.Context, id int64) (Backup, error) {
	row := s.db.QueryRowContext(ctx, `
		SELECT `+backupColumns+`
		FROM dll_backups b
		JOIN game_dlls d ON d.id = b.game_dll_id
		WHERE b.id = ?`, id)
	b, err := scanBackup(row)
	if errors.Is(err, sql.ErrNoRows) {
		return Backup{}, fmt.Errorf("store: backup %d: %w", id, ErrNotFound)
	}
	if err != nil {
		return Backup{}, fmt.Errorf("store: get backup %d: %w", id, err)
	}
	return b, nil
}

// DeleteBackup removes the backup record. Deleting the .dlsss file is the
// caller's responsibility and happens first.
func (s *Store) DeleteBackup(ctx context.Context, id int64) error {
	res, err := s.db.ExecContext(ctx, `DELETE FROM dll_backups WHERE id = ?`, id)
	if err != nil {
		return fmt.Errorf("store: delete backup %d: %w", id, err)
	}
	n, err := res.RowsAffected()
	if err != nil {
		return fmt.Errorf("store: delete backup %d: %w", id, err)
	}
	if n == 0 {
		return fmt.Errorf("store: backup %d: %w", id, ErrNotFound)
	}
	return nil
}

const backupColumns = `
	b.id, d.game_id, b.game_dll_id, b.game_name, b.dll_type, b.dll_filename,
	b.backup_path, d.dll_path, b.original_version, b.backup_size, b.created_at,
	b.is_active, b.was_added, b.restored_at, b.post_update_version`

func scanBackup(sc scanner) (Backup, error) {
	var (
		b          Backup
		createdAt  int64
		active     int
		wasAdded   int
		restoredAt sql.NullInt64
		postUpdate sql.NullString
	)
	if err := sc.Scan(&b.ID, &b.GameID, &b.GameDLLID, &b.GameName, &b.DLLType, &b.DLLFilename,
		&b.BackupPath, &b.TargetPath, &b.OriginalVersion, &b.SizeBytes, &createdAt,
		&active, &wasAdded, &restoredAt, &postUpdate); err != nil {
		return Backup{}, err
	}
	b.CreatedAt = timestamp(createdAt)
	b.IsActive = active != 0
	b.WasAdded = wasAdded != 0
	if restoredAt.Valid {
		at := timestamp(restoredAt.Int64)
		b.RestoredAt = &at
	}
	b.PostUpdateVersion = postUpdate.String
	return b, nil
}

func boolInt(v bool) int {
	if v {
		return 1
	}
	return 0
}

func nullableString(v string) any {
	if v == "" {
		return nil
	}
	return v
}
