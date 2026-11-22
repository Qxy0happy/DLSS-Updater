package store_test

import (
	"context"
	"database/sql"
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/Qxy0happy/DLSS-Updater/backend/internal/store"
	_ "modernc.org/sqlite"
)

var (
	t0 = time.Date(2026, 11, 22, 10, 0, 0, 123456789, time.UTC)
	t1 = t0.Add(time.Minute)
	t2 = t1.Add(time.Minute)
)

func openStore(t *testing.T, dir string) *store.Store {
	t.Helper()
	s, err := store.Open(context.Background(), dir)
	if err != nil {
		t.Fatalf("store.Open(%s): %v", dir, err)
	}
	t.Cleanup(func() {
		if err := s.Close(); err != nil {
			t.Errorf("close store: %v", err)
		}
	})
	return s
}

func mustGame(t *testing.T, s *store.Store, in store.GameInput) store.Game {
	t.Helper()
	g, err := s.UpsertGame(context.Background(), in)
	if err != nil {
		t.Fatalf("UpsertGame(%+v): %v", in, err)
	}
	return g
}

func mustDLL(t *testing.T, s *store.Store, in store.DLLInput) store.DLL {
	t.Helper()
	d, err := s.UpsertDLL(context.Background(), in)
	if err != nil {
		t.Fatalf("UpsertDLL(%+v): %v", in, err)
	}
	return d
}

func mustBackup(t *testing.T, s *store.Store, in store.BackupInput) store.Backup {
	t.Helper()
	b, err := s.CreateBackup(context.Background(), in)
	if err != nil {
		t.Fatalf("CreateBackup(%+v): %v", in, err)
	}
	return b
}

func gameInput(name, path string) store.GameInput {
	return store.GameInput{
		AppID:       1091500,
		Name:        name,
		Path:        path,
		LibraryPath: filepath.Dir(filepath.Dir(path)),
		ScannedAt:   t0,
	}
}

func dllInput(gameID int64, path string) store.DLLInput {
	return store.DLLInput{
		GameID:     gameID,
		Type:       "dlss",
		Filename:   filepath.Base(path),
		Path:       path,
		Version:    "2.4.2.0",
		DetectedAt: t0,
	}
}

func backupInput(dllID int64, gameName, path string, createdAt time.Time) store.BackupInput {
	return store.BackupInput{
		GameDLLID:         dllID,
		GameName:          gameName,
		DLLType:           "dlss",
		DLLFilename:       "nvngx_dlss.dll",
		BackupPath:        path,
		OriginalVersion:   "2.4.2.0",
		SizeBytes:         4096,
		CreatedAt:         createdAt,
		PostUpdateVersion: "3.7.10.0",
	}
}

func rawDB(t *testing.T, dataDir string) *sql.DB {
	t.Helper()
	path := filepath.Join(dataDir, "db.sqlite3")
	db, err := sql.Open("sqlite", "file:"+path+"?_pragma=foreign_keys(1)")
	if err != nil {
		t.Fatalf("open raw sqlite: %v", err)
	}
	t.Cleanup(func() { _ = db.Close() })
	return db
}

func TestOpenCreatesSchemaV1FromEmptyDirectory(t *testing.T) {
	dir := t.TempDir()
	openStore(t, dir)

	dbPath := filepath.Join(dir, "db.sqlite3")
	if _, err := os.Stat(dbPath); err != nil {
		t.Fatalf("db.sqlite3 was not created: %v", err)
	}
	if _, err := os.Stat(dbPath + "-wal"); err != nil {
		t.Fatalf("WAL sidecar missing while the store is open: %v", err)
	}

	db := rawDB(t, dir)
	var mode string
	if err := db.QueryRow("PRAGMA journal_mode").Scan(&mode); err != nil {
		t.Fatalf("read journal_mode: %v", err)
	}
	if mode != "wal" {
		t.Errorf("journal_mode = %q, want wal", mode)
	}

	have := map[string]bool{}
	rows, err := db.Query("SELECT name FROM sqlite_master WHERE type='table'")
	if err != nil {
		t.Fatalf("list tables: %v", err)
	}
	defer rows.Close()
	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil {
			t.Fatalf("scan table name: %v", err)
		}
		have[name] = true
	}
	if err := rows.Err(); err != nil {
		t.Fatalf("iterate tables: %v", err)
	}
	for _, want := range []string{"schema_meta", "games", "game_dlls", "dll_backups", "update_history"} {
		if !have[want] {
			t.Errorf("table %q missing (have %v)", want, have)
		}
	}

	var version int
	if err := db.QueryRow("SELECT version FROM schema_meta WHERE id = 1").Scan(&version); err != nil {
		t.Fatalf("read schema version: %v", err)
	}
	if version != store.SchemaVersion {
		t.Errorf("schema version = %d, want %d", version, store.SchemaVersion)
	}
}

func TestReopenPreservesGamesAndTimestamps(t *testing.T) {
	dir := t.TempDir()

	s := openStore(t, dir)
	g := mustGame(t, s, gameInput("Cyberpunk 2077", "/games/Cyberpunk 2077"))
	d := mustDLL(t, s, dllInput(g.ID, "/games/Cyberpunk 2077/bin/x64/nvngx_dlss.dll"))
	if err := s.Close(); err != nil {
		t.Fatalf("close store: %v", err)
	}

	reopened := openStore(t, dir)
	got, err := reopened.GetGame(context.Background(), g.ID)
	if err != nil {
		t.Fatalf("GetGame after reopen: %v", err)
	}
	if got.Name != g.Name || got.Path != g.Path || got.AppID != g.AppID || got.LibraryPath != g.LibraryPath {
		t.Errorf("game = %+v, want %+v", got, g)
	}
	if !got.CreatedAt.Equal(g.CreatedAt) {
		t.Errorf("created_at = %v, want %v", got.CreatedAt, g.CreatedAt)
	}
	if !got.LastScannedAt.Equal(t0.Truncate(time.Millisecond)) {
		t.Errorf("last_scanned_at = %v, want %v", got.LastScannedAt, t0.Truncate(time.Millisecond))
	}
	if len(got.DLLs) != 1 || got.DLLs[0].ID != d.ID {
		t.Fatalf("DLLs = %+v, want the single DLL %d", got.DLLs, d.ID)
	}
	if got.DLLs[0].MissingAt != nil {
		t.Errorf("missing_at = %v, want nil", got.DLLs[0].MissingAt)
	}
	if !got.DLLs[0].DetectedAt.Equal(t0.Truncate(time.Millisecond)) {
		t.Errorf("detected_at = %v, want %v", got.DLLs[0].DetectedAt, t0.Truncate(time.Millisecond))
	}
	if got.DLLs[0].CurrentVersion != "2.4.2.0" {
		t.Errorf("current_version = %q, want 2.4.2.0", got.DLLs[0].CurrentVersion)
	}
}

func TestUpsertGameKeepsOneRowPerPath(t *testing.T) {
	dir := t.TempDir()
	s := openStore(t, dir)

	first := mustGame(t, s, gameInput("Old Name", "/games/same"))
	second := mustGame(t, s, store.GameInput{
		AppID:       42,
		Name:        "New Name",
		Path:        "/games/same",
		LibraryPath: "/library",
		ScannedAt:   t1,
	})
	if first.ID != second.ID {
		t.Errorf("same path produced ids %d and %d", first.ID, second.ID)
	}
	if !second.CreatedAt.Equal(first.CreatedAt) {
		t.Errorf("created_at changed on upsert: %v -> %v", first.CreatedAt, second.CreatedAt)
	}
	if !second.LastScannedAt.Equal(t1.Truncate(time.Millisecond)) {
		t.Errorf("last_scanned_at = %v, want %v", second.LastScannedAt, t1.Truncate(time.Millisecond))
	}

	games, err := s.ListGames(context.Background())
	if err != nil {
		t.Fatalf("ListGames: %v", err)
	}
	if len(games) != 1 {
		t.Fatalf("ListGames returned %d games, want 1", len(games))
	}
	if games[0].Name != "New Name" || games[0].AppID != 42 {
		t.Errorf("game = %+v, want the upserted values", games[0])
	}
}

func TestSchemaRejectsDuplicatePathsAndDanglingForeignKeys(t *testing.T) {
	dir := t.TempDir()
	s := openStore(t, dir)
	g := mustGame(t, s, gameInput("Game", "/games/path"))

	db := rawDB(t, dir)
	_, err := db.Exec(`INSERT INTO games (app_id, name, path, library_path, created_at, last_scanned_at)
		VALUES (1, 'Duplicate', ?, '/library', 0, 0)`, g.Path)
	if err == nil {
		t.Fatal("duplicate games.path was accepted")
	}
	_, err = db.Exec(`INSERT INTO game_dlls (game_id, dll_type, filename, dll_path, current_version, detected_at)
		VALUES (999999, 'dlss', 'nvngx_dlss.dll', '/games/path/nvngx_dlss.dll', '0.0.0', 0)`)
	if err == nil {
		t.Fatal("dangling game_dlls.game_id was accepted; foreign_keys is off")
	}

	d := mustDLL(t, s, dllInput(g.ID, "/games/path/nvngx_dlss.dll"))
	_, err = db.Exec(`INSERT INTO game_dlls (game_id, dll_type, filename, dll_path, current_version, detected_at)
		VALUES (?, 'dlss', 'other.dll', ?, '0.0.0', 0)`, g.ID, d.Path)
	if err == nil {
		t.Fatal("duplicate game_dlls.dll_path was accepted")
	}
}

func TestDeleteGameCascadesToDLLsBackupsAndHistory(t *testing.T) {
	dir := t.TempDir()
	s := openStore(t, dir)
	ctx := context.Background()

	g := mustGame(t, s, gameInput("Game", "/games/cascade"))
	d := mustDLL(t, s, dllInput(g.ID, "/games/cascade/nvngx_dlss.dll"))
	b, err := s.RecordUpdate(ctx, store.UpdateRecordInput{
		GameDLLID:         d.ID,
		GameName:          g.Name,
		DLLType:           "dlss",
		DLLFilename:       "nvngx_dlss.dll",
		BackupPath:        "/games/cascade/nvngx_dlss.dlsss",
		OriginalVersion:   "2.4.2.0",
		PostUpdateVersion: "3.7.10.0",
		SizeBytes:         4096,
		UpdatedAt:         t0,
	})
	if err != nil {
		t.Fatalf("RecordUpdate: %v", err)
	}

	if err := s.DeleteGame(context.Background(), g.ID); err != nil {
		t.Fatalf("DeleteGame: %v", err)
	}
	if _, err := s.GetGame(context.Background(), g.ID); !errors.Is(err, store.ErrNotFound) {
		t.Errorf("GetGame after delete = %v, want ErrNotFound", err)
	}
	if _, err := s.GetBackup(context.Background(), b.ID); !errors.Is(err, store.ErrNotFound) {
		t.Errorf("GetBackup after cascade = %v, want ErrNotFound", err)
	}

	db := rawDB(t, dir)
	for table, want := range map[string]int{"game_dlls": 0, "dll_backups": 0, "update_history": 0} {
		var n int
		if err := db.QueryRow("SELECT COUNT(*) FROM " + table).Scan(&n); err != nil {
			t.Fatalf("count %s: %v", table, err)
		}
		if n != want {
			t.Errorf("%s has %d rows after cascade, want %d", table, n, want)
		}
	}

	if err := s.DeleteGame(context.Background(), g.ID); !errors.Is(err, store.ErrNotFound) {
		t.Errorf("second DeleteGame = %v, want ErrNotFound", err)
	}
}

func TestDLLMissingAtTransitions(t *testing.T) {
	dir := t.TempDir()
	s := openStore(t, dir)
	ctx := context.Background()

	g := mustGame(t, s, gameInput("Game", "/games/missing"))
	in := dllInput(g.ID, "/games/missing/nvngx_dlss.dll")
	d := mustDLL(t, s, in)
	if d.MissingAt != nil {
		t.Fatalf("new DLL has missing_at = %v", d.MissingAt)
	}

	if err := s.SetDLLMissing(ctx, d.ID, t1); err != nil {
		t.Fatalf("SetDLLMissing: %v", err)
	}
	got := mustGameDLL(t, s, g.ID)
	if got.MissingAt == nil || !got.MissingAt.Equal(t1.Truncate(time.Millisecond)) {
		t.Fatalf("missing_at = %v, want %v", got.MissingAt, t1.Truncate(time.Millisecond))
	}

	in.Version = "3.7.10.0"
	in.DetectedAt = t2
	updated := mustDLL(t, s, in)
	if updated.ID != d.ID {
		t.Errorf("upsert produced a new row: %d -> %d", d.ID, updated.ID)
	}
	if updated.MissingAt != nil {
		t.Errorf("missing_at = %v after rediscovery, want nil", updated.MissingAt)
	}
	if updated.CurrentVersion != "3.7.10.0" {
		t.Errorf("current_version = %q, want 3.7.10.0", updated.CurrentVersion)
	}

	if err := s.SetDLLMissing(ctx, d.ID, t2); err != nil {
		t.Fatalf("SetDLLMissing again: %v", err)
	}
	if err := s.ClearDLLMissing(ctx, d.ID); err != nil {
		t.Fatalf("ClearDLLMissing: %v", err)
	}
	if got := mustGameDLL(t, s, g.ID); got.MissingAt != nil {
		t.Errorf("missing_at = %v after ClearDLLMissing, want nil", got.MissingAt)
	}

	if err := s.UpdateDLLVersion(ctx, d.ID, "3.8.11.0"); err != nil {
		t.Fatalf("UpdateDLLVersion: %v", err)
	}
	if got := mustGameDLL(t, s, g.ID); got.CurrentVersion != "3.8.11.0" {
		t.Errorf("current_version = %q, want 3.8.11.0", got.CurrentVersion)
	}

	if err := s.SetDLLMissing(ctx, 999999, t1); !errors.Is(err, store.ErrNotFound) {
		t.Errorf("SetDLLMissing(unknown) = %v, want ErrNotFound", err)
	}
	if err := s.UpdateDLLVersion(ctx, 999999, "1.0.0.0"); !errors.Is(err, store.ErrNotFound) {
		t.Errorf("UpdateDLLVersion(unknown) = %v, want ErrNotFound", err)
	}
}

func mustGameDLL(t *testing.T, s *store.Store, gameID int64) store.DLL {
	t.Helper()
	g, err := s.GetGame(context.Background(), gameID)
	if err != nil {
		t.Fatalf("GetGame(%d): %v", gameID, err)
	}
	if len(g.DLLs) != 1 {
		t.Fatalf("game has %d DLLs, want 1", len(g.DLLs))
	}
	return g.DLLs[0]
}

func TestListGamesIncludesDLLsPerGame(t *testing.T) {
	dir := t.TempDir()
	s := openStore(t, dir)
	ctx := context.Background()

	first := mustGame(t, s, gameInput("Alpha", "/games/alpha"))
	second := mustGame(t, s, store.GameInput{
		AppID: 620, Name: "Beta", Path: "/games/beta", LibraryPath: "/library", ScannedAt: t0,
	})
	mustDLL(t, s, dllInput(first.ID, "/games/alpha/nvngx_dlss.dll"))
	dllB := mustDLL(t, s, store.DLLInput{
		GameID: second.ID, Type: "xess", Filename: "libxess.dll",
		Path: "/games/beta/libxess.dll", Version: "2.0.0.0", DetectedAt: t0,
	})

	games, err := s.ListGames(ctx)
	if err != nil {
		t.Fatalf("ListGames: %v", err)
	}
	if len(games) != 2 {
		t.Fatalf("ListGames returned %d games, want 2", len(games))
	}
	for _, g := range games {
		switch g.ID {
		case first.ID:
			if len(g.DLLs) != 1 || g.DLLs[0].Filename != "nvngx_dlss.dll" {
				t.Errorf("alpha DLLs = %+v", g.DLLs)
			}
		case second.ID:
			if len(g.DLLs) != 1 || g.DLLs[0].ID != dllB.ID {
				t.Errorf("beta DLLs = %+v", g.DLLs)
			}
		default:
			t.Errorf("unexpected game %+v", g)
		}
	}

	if _, err := s.GetGame(ctx, 999999); !errors.Is(err, store.ErrNotFound) {
		t.Errorf("GetGame(unknown) = %v, want ErrNotFound", err)
	}
}

func TestBackupLifecycle(t *testing.T) {
	dir := t.TempDir()
	s := openStore(t, dir)
	ctx := context.Background()

	g := mustGame(t, s, gameInput("Game", "/games/backups"))
	d := mustDLL(t, s, dllInput(g.ID, "/games/backups/nvngx_dlss.dll"))

	old := mustBackup(t, s, backupInput(d.ID, g.Name, "/games/backups/nvngx_dlss.dlsss", t0))
	if !old.IsActive {
		t.Fatal("new backup is not active")
	}
	if old.GameID != g.ID || old.GameDLLID != d.ID {
		t.Errorf("backup ids = game %d dll %d, want %d %d", old.GameID, old.GameDLLID, g.ID, d.ID)
	}
	if old.SizeBytes != 4096 || old.PostUpdateVersion != "3.7.10.0" {
		t.Errorf("backup = %+v, want size 4096 and post_update_version 3.7.10.0", old)
	}
	if old.OriginalVersion != "2.4.2.0" || old.DLLFilename != "nvngx_dlss.dll" || old.DLLType != "dlss" {
		t.Errorf("backup = %+v, want the original version and DLL identity kept", old)
	}
	if old.WasAdded {
		t.Error("backup was_added = true, want false")
	}
	if old.RestoredAt != nil {
		t.Errorf("restored_at = %v, want nil", old.RestoredAt)
	}
	if !old.CreatedAt.Equal(t0.Truncate(time.Millisecond)) {
		t.Errorf("created_at = %v, want %v", old.CreatedAt, t0.Truncate(time.Millisecond))
	}

	newer := mustBackup(t, s, backupInput(d.ID, g.Name, "/games/backups/nvngx_dlss.dlsss", t1))
	oldAfter, err := s.GetBackup(ctx, old.ID)
	if err != nil {
		t.Fatalf("GetBackup(old): %v", err)
	}
	if oldAfter.IsActive {
		t.Error("creating a newer backup left the older one active")
	}

	active, err := s.ListBackups(ctx, store.BackupFilter{})
	if err != nil {
		t.Fatalf("ListBackups(active): %v", err)
	}
	if len(active) != 1 || active[0].ID != newer.ID {
		t.Errorf("active backups = %+v, want only %d", active, newer.ID)
	}

	all, err := s.ListBackups(ctx, store.BackupFilter{IncludeInactive: true})
	if err != nil {
		t.Fatalf("ListBackups(all): %v", err)
	}
	if len(all) != 2 {
		t.Fatalf("all backups = %d, want 2", len(all))
	}
	if all[0].ID != newer.ID || all[1].ID != old.ID {
		t.Errorf("backup order = [%d %d], want newest first [%d %d]", all[0].ID, all[1].ID, newer.ID, old.ID)
	}

	if err := s.SetBackupActive(ctx, old.ID, true); err != nil {
		t.Fatalf("SetBackupActive(old): %v", err)
	}
	active, err = s.ListBackups(ctx, store.BackupFilter{})
	if err != nil {
		t.Fatalf("ListBackups after reactivation: %v", err)
	}
	if len(active) != 1 || active[0].ID != old.ID {
		t.Errorf("active backups = %+v, want only %d", active, old.ID)
	}

	if err := s.SetBackupActive(ctx, old.ID, false); err != nil {
		t.Fatalf("SetBackupActive(old, false): %v", err)
	}
	active, err = s.ListBackups(ctx, store.BackupFilter{})
	if err != nil {
		t.Fatalf("ListBackups after deactivation: %v", err)
	}
	if len(active) != 0 {
		t.Errorf("active backups = %+v, want none", active)
	}

	if _, err := s.RecordRestore(ctx, store.RestoreInput{
		BackupID:   old.ID,
		GameDLLID:  d.ID,
		Version:    "2.4.2.0",
		RestoredAt: t2,
	}); err != nil {
		t.Fatalf("RecordRestore: %v", err)
	}
	restored, err := s.GetBackup(ctx, old.ID)
	if err != nil {
		t.Fatalf("GetBackup(restored): %v", err)
	}
	if restored.IsActive {
		t.Error("restored backup is still active")
	}
	if restored.RestoredAt == nil || !restored.RestoredAt.Equal(t2.Truncate(time.Millisecond)) {
		t.Errorf("restored_at = %v, want %v", restored.RestoredAt, t2.Truncate(time.Millisecond))
	}

	if err := s.DeleteBackup(ctx, old.ID); err != nil {
		t.Fatalf("DeleteBackup: %v", err)
	}
	if _, err := s.GetBackup(ctx, old.ID); !errors.Is(err, store.ErrNotFound) {
		t.Errorf("GetBackup after delete = %v, want ErrNotFound", err)
	}
	if err := s.DeleteBackup(ctx, old.ID); !errors.Is(err, store.ErrNotFound) {
		t.Errorf("second DeleteBackup = %v, want ErrNotFound", err)
	}
}

func TestListBackupsFiltersByGame(t *testing.T) {
	dir := t.TempDir()
	s := openStore(t, dir)
	ctx := context.Background()

	alpha := mustGame(t, s, gameInput("Alpha", "/games/alpha"))
	beta := mustGame(t, s, gameInput("Beta", "/games/beta"))
	dllA := mustDLL(t, s, dllInput(alpha.ID, "/games/alpha/nvngx_dlss.dll"))
	dllB := mustDLL(t, s, dllInput(beta.ID, "/games/beta/nvngx_dlss.dll"))
	a := mustBackup(t, s, backupInput(dllA.ID, alpha.Name, "/games/alpha/nvngx_dlss.dlsss", t0))
	b := mustBackup(t, s, backupInput(dllB.ID, beta.Name, "/games/beta/nvngx_dlss.dlsss", t1))

	got, err := s.ListBackups(ctx, store.BackupFilter{GameID: beta.ID, IncludeInactive: true})
	if err != nil {
		t.Fatalf("ListBackups(beta): %v", err)
	}
	if len(got) != 1 || got[0].ID != b.ID {
		t.Errorf("beta backups = %+v, want only %d", got, b.ID)
	}
	if got[0].GameName != "Beta" {
		t.Errorf("game_name = %q, want Beta", got[0].GameName)
	}

	all, err := s.ListBackups(ctx, store.BackupFilter{IncludeInactive: true})
	if err != nil {
		t.Fatalf("ListBackups(all): %v", err)
	}
	if len(all) != 2 || all[0].ID != b.ID || all[1].ID != a.ID {
		t.Errorf("all backups = %+v, want newest first", all)
	}
}

func TestRecordUpdateStoresUTCUnixMilliseconds(t *testing.T) {
	dir := t.TempDir()
	s := openStore(t, dir)
	ctx := context.Background()

	g := mustGame(t, s, gameInput("Game", "/games/history"))
	d := mustDLL(t, s, dllInput(g.ID, "/games/history/nvngx_dlss.dll"))
	at := t0.Add(123456 * time.Nanosecond)
	backup, err := s.RecordUpdate(ctx, store.UpdateRecordInput{
		GameDLLID:         d.ID,
		GameName:          g.Name,
		DLLType:           "dlss",
		DLLFilename:       "nvngx_dlss.dll",
		BackupPath:        "/games/history/nvngx_dlss.dlsss",
		OriginalVersion:   "2.4.2.0",
		PostUpdateVersion: "3.7.10.0",
		SizeBytes:         4096,
		UpdatedAt:         at,
	})
	if err != nil {
		t.Fatalf("RecordUpdate: %v", err)
	}
	if got := backup.CreatedAt.UnixMilli(); got != at.UnixMilli() {
		t.Errorf("backup created_at = %d, want %d", got, at.UnixMilli())
	}

	db := rawDB(t, dir)
	var (
		dllID               int64
		success             int
		fromVersion, toVers string
		updatedAt           int64
	)
	if err := db.QueryRow(`SELECT game_dll_id, success, from_version, to_version, updated_at
		FROM update_history WHERE game_dll_id = ?`, d.ID).
		Scan(&dllID, &success, &fromVersion, &toVers, &updatedAt); err != nil {
		t.Fatalf("read history row: %v", err)
	}
	if dllID != d.ID || success != 1 {
		t.Errorf("history row = dll %d success %d, want %d 1", dllID, success, d.ID)
	}
	if fromVersion != "2.4.2.0" || toVers != "3.7.10.0" {
		t.Errorf("history versions = %q -> %q", fromVersion, toVers)
	}
	if want := at.UnixMilli(); updatedAt != want {
		t.Errorf("updated_at = %d, want %d", updatedAt, want)
	}
	if got := time.UnixMilli(updatedAt).UTC(); !got.Equal(at.Truncate(time.Millisecond)) {
		t.Errorf("round-trip = %v, want %v", got, at.Truncate(time.Millisecond))
	}
}

func TestOpenRejectsRelativeDataDir(t *testing.T) {
	if _, err := store.Open(context.Background(), "relative/dir"); err == nil {
		t.Fatal("store.Open accepted a relative data directory")
	}
}

func TestOpenRejectsNewerSchemaVersion(t *testing.T) {
	dir := t.TempDir()
	s := openStore(t, dir)
	if err := s.Close(); err != nil {
		t.Fatalf("close store: %v", err)
	}

	db := rawDB(t, dir)
	if _, err := db.Exec(`UPDATE schema_meta SET version = ?`, store.SchemaVersion+1); err != nil {
		t.Fatalf("bump schema version: %v", err)
	}
	if _, err := store.Open(context.Background(), dir); err == nil {
		t.Fatal("store.Open accepted a database from a newer schema version")
	}
}
