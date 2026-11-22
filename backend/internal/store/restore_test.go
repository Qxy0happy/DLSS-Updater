package store_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/Qxy0happy/DLSS-Updater/backend/internal/store"
)

func TestRecordRestoreUpdatesVersionAndMarksTheBackupRestored(t *testing.T) {
	dir := t.TempDir()
	s := openStore(t, dir)
	ctx := context.Background()

	g := mustGame(t, s, gameInput("Game", "/games/restore"))
	d := mustDLL(t, s, dllInput(g.ID, "/games/restore/nvngx_dlss.dll"))
	if err := s.UpdateDLLVersion(ctx, d.ID, "3.7.10.0"); err != nil {
		t.Fatalf("UpdateDLLVersion: %v", err)
	}
	if err := s.SetDLLMissing(ctx, d.ID, t0); err != nil {
		t.Fatalf("SetDLLMissing: %v", err)
	}
	b := mustBackup(t, s, backupInput(d.ID, g.Name, "/games/restore/nvngx_dlss.dlsss", t0))

	restored, err := s.RecordRestore(ctx, store.RestoreInput{
		BackupID:   b.ID,
		GameDLLID:  d.ID,
		Version:    "2.4.2.0",
		RestoredAt: t2,
	})
	if err != nil {
		t.Fatalf("RecordRestore: %v", err)
	}
	if restored.IsActive {
		t.Error("restored backup is still active")
	}
	if restored.RestoredAt == nil || !restored.RestoredAt.Equal(t2.Truncate(time.Millisecond)) {
		t.Errorf("restored_at = %v, want %v", restored.RestoredAt, t2.Truncate(time.Millisecond))
	}
	if got := restored.TargetPath; got != d.Path {
		t.Errorf("target path = %q, want %q", got, d.Path)
	}

	dllAfter, err := s.GetDLL(ctx, d.ID)
	if err != nil {
		t.Fatalf("GetDLL: %v", err)
	}
	if dllAfter.CurrentVersion != "2.4.2.0" {
		t.Errorf("current_version = %q, want 2.4.2.0", dllAfter.CurrentVersion)
	}
	if dllAfter.MissingAt != nil {
		t.Errorf("missing_at = %v, want nil", dllAfter.MissingAt)
	}

	if active, err := s.ListBackups(ctx, store.BackupFilter{}); err != nil {
		t.Fatalf("ListBackups: %v", err)
	} else if len(active) != 0 {
		t.Errorf("active backups = %+v, want none", active)
	}
}

func TestRecordRestoreRollsBackWhenTheDLLIsMissing(t *testing.T) {
	dir := t.TempDir()
	s := openStore(t, dir)
	ctx := context.Background()

	g := mustGame(t, s, gameInput("Game", "/games/restore-rollback"))
	d := mustDLL(t, s, dllInput(g.ID, "/games/restore-rollback/nvngx_dlss.dll"))
	b := mustBackup(t, s, backupInput(d.ID, g.Name, "/games/restore-rollback/nvngx_dlss.dlsss", t0))

	_, err := s.RecordRestore(ctx, store.RestoreInput{
		BackupID:   b.ID,
		GameDLLID:  d.ID + 999,
		Version:    "2.4.2.0",
		RestoredAt: t2,
	})
	if !errors.Is(err, store.ErrNotFound) {
		t.Fatalf("RecordRestore error = %v, want ErrNotFound", err)
	}

	after, err := s.GetBackup(ctx, b.ID)
	if err != nil {
		t.Fatalf("GetBackup: %v", err)
	}
	if !after.IsActive {
		t.Error("rolled-back transaction deactivated the backup")
	}
	if after.RestoredAt != nil {
		t.Errorf("rolled-back transaction set restored_at = %v", after.RestoredAt)
	}
}
