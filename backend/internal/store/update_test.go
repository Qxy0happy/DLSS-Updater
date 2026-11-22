package store_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/Qxy0happy/DLSS-Updater/backend/internal/store"
)

func TestRecordUpdateCommitsVersionBackupAndHistory(t *testing.T) {
	dir := t.TempDir()
	s := openStore(t, dir)
	ctx := context.Background()

	g := mustGame(t, s, gameInput("Game", "/games/record"))
	d := mustDLL(t, s, dllInput(g.ID, "/games/record/nvngx_dlss.dll"))
	old := mustBackup(t, s, backupInput(d.ID, g.Name, "/games/record/nvngx_dlss.dlsss", t0))

	updated, err := s.RecordUpdate(ctx, store.UpdateRecordInput{
		GameDLLID:         d.ID,
		GameName:          g.Name,
		DLLType:           "dlss",
		DLLFilename:       "nvngx_dlss.dll",
		BackupPath:        "/games/record/nvngx_dlss.dlsss",
		OriginalVersion:   "2.4.2.0",
		PostUpdateVersion: "3.7.10.0",
		SizeBytes:         8192,
		UpdatedAt:         t1,
	})
	if err != nil {
		t.Fatalf("RecordUpdate: %v", err)
	}
	if !updated.IsActive || updated.PostUpdateVersion != "3.7.10.0" {
		t.Errorf("new backup = %+v, want active with post_update_version 3.7.10.0", updated)
	}
	if updated.SizeBytes != 8192 || updated.OriginalVersion != "2.4.2.0" {
		t.Errorf("new backup = %+v, want the recorded size and original version", updated)
	}
	if !updated.CreatedAt.Equal(t1.Truncate(time.Millisecond)) {
		t.Errorf("created_at = %v, want %v", updated.CreatedAt, t1.Truncate(time.Millisecond))
	}

	oldAfter, err := s.GetBackup(ctx, old.ID)
	if err != nil {
		t.Fatalf("GetBackup(old): %v", err)
	}
	if oldAfter.IsActive {
		t.Error("the previous active backup stayed active")
	}

	dllAfter, err := s.GetDLL(ctx, d.ID)
	if err != nil {
		t.Fatalf("GetDLL: %v", err)
	}
	if dllAfter.CurrentVersion != "3.7.10.0" {
		t.Errorf("current_version = %q, want 3.7.10.0", dllAfter.CurrentVersion)
	}

	active, err := s.ListBackups(ctx, store.BackupFilter{})
	if err != nil {
		t.Fatalf("ListBackups: %v", err)
	}
	if len(active) != 1 || active[0].ID != updated.ID {
		t.Errorf("active backups = %+v, want only %d", active, updated.ID)
	}

	db := rawDB(t, dir)
	var (
		success             int
		fromVersion, toVers string
		updatedAt           int64
	)
	if err := db.QueryRow(`SELECT success, from_version, to_version, updated_at
		FROM update_history WHERE game_dll_id = ?`, d.ID).
		Scan(&success, &fromVersion, &toVers, &updatedAt); err != nil {
		t.Fatalf("read history row: %v", err)
	}
	if success != 1 || fromVersion != "2.4.2.0" || toVers != "3.7.10.0" {
		t.Errorf("history = success %d %q -> %q", success, fromVersion, toVers)
	}
	if want := t1.UnixMilli(); updatedAt != want {
		t.Errorf("history updated_at = %d, want %d", updatedAt, want)
	}
}

func TestRecordUpdateRollsBackEverythingWhenTheDLLIsMissing(t *testing.T) {
	dir := t.TempDir()
	s := openStore(t, dir)
	ctx := context.Background()

	g := mustGame(t, s, gameInput("Game", "/games/rollback"))
	d := mustDLL(t, s, dllInput(g.ID, "/games/rollback/nvngx_dlss.dll"))

	_, err := s.RecordUpdate(ctx, store.UpdateRecordInput{
		GameDLLID:         d.ID + 999,
		GameName:          g.Name,
		DLLType:           "dlss",
		DLLFilename:       "nvngx_dlss.dll",
		BackupPath:        "/games/rollback/nvngx_dlss.dlsss",
		OriginalVersion:   "2.4.2.0",
		PostUpdateVersion: "3.7.10.0",
		SizeBytes:         8192,
		UpdatedAt:         t1,
	})
	if !errors.Is(err, store.ErrNotFound) {
		t.Fatalf("RecordUpdate error = %v, want ErrNotFound", err)
	}

	backups, err := s.ListBackups(ctx, store.BackupFilter{IncludeInactive: true})
	if err != nil {
		t.Fatalf("ListBackups: %v", err)
	}
	if len(backups) != 0 {
		t.Errorf("rolled-back transaction left %d backups", len(backups))
	}

	db := rawDB(t, dir)
	var history int
	if err := db.QueryRow(`SELECT COUNT(*) FROM update_history`).Scan(&history); err != nil {
		t.Fatalf("count history: %v", err)
	}
	if history != 0 {
		t.Errorf("rolled-back transaction left %d history rows", history)
	}
}
