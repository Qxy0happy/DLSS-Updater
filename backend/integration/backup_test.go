//go:build integration

package integration

import (
	"bytes"
	"context"
	"database/sql"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials/insecure"

	dlssv1 "github.com/Qxy0happy/DLSS-Updater/backend/gen/dlss/v1"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/contract"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/testfixtures"
)

// backupEnv is a running sidecar plus the clients the backup tests drive. All
// state is seeded through StartScan and StartUpdate; the tests never call the
// store directly except to move a row into a state the filesystem cannot
// produce on its own (see TestRestoreReportsMissingTargetFolder).
type backupEnv struct {
	paths   paths
	backup  dlssv1.BackupClient
	update  dlssv1.UpdateClient
	library dlssv1.LibraryClient
	scan    dlssv1.ScanClient
	source  *testfixtures.DLLSource
}

// newBackupEnv starts a daemon with an empty DLL source directory.
func newBackupEnv(t *testing.T) *backupEnv {
	t.Helper()
	p := newPaths(t)
	source := testfixtures.NewDLLSource(t)
	p.dllSource = source.Dir()
	startSidecar(t, p)
	return backupClientsFor(t, p, source)
}

// backupClientsFor attaches the backup test clients to an already-started
// sidecar, so tests that build a tagged binary can use the same helpers.
func backupClientsFor(t *testing.T, p paths, source *testfixtures.DLLSource) *backupEnv {
	t.Helper()
	conn, err := grpc.NewClient("unix://"+p.socket, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		t.Fatalf("grpc.NewClient(%s): %v", p.socket, err)
	}
	t.Cleanup(func() { _ = conn.Close() })
	return &backupEnv{
		paths:   p,
		backup:  dlssv1.NewBackupClient(conn),
		update:  dlssv1.NewUpdateClient(conn),
		library: dlssv1.NewLibraryClient(conn),
		scan:    dlssv1.NewScanClient(conn),
		source:  source,
	}
}

func (e *backupEnv) scanLibrary(t *testing.T, root string) {
	t.Helper()
	runScan(t, e.scan, root)
}

func (e *backupEnv) list(t *testing.T, req *dlssv1.ListBackupsRequest) []*dlssv1.BackupRecord {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	resp, err := e.backup.ListBackups(ctx, req)
	if err != nil {
		t.Fatalf("ListBackups(%+v): %v", req, err)
	}
	return resp.GetBackups()
}

func (e *backupEnv) restore(t *testing.T, id string) (*dlssv1.RestoreBackupResponse, error) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	return e.backup.RestoreBackup(ctx, &dlssv1.RestoreBackupRequest{BackupId: id})
}

func (e *backupEnv) delete(t *testing.T, id string) error {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	_, err := e.backup.DeleteBackup(ctx, &dlssv1.DeleteBackupRequest{BackupId: id})
	return err
}

// updateOne runs one update for dllID and requires it to succeed with a
// backup, so every test starts from a real update-created record.
func (e *backupEnv) updateOne(t *testing.T, dllID string) *dlssv1.UpdateItemFinished {
	t.Helper()
	events := runUpdate(t, e.update, []string{dllID})
	items := itemsFinished(t, events)
	if len(items) != 1 {
		t.Fatalf("item_finished events = %d, want 1", len(items))
	}
	if items[0].GetOutcome() != dlssv1.UpdateOutcome_UPDATE_OUTCOME_UPDATED {
		t.Fatalf("update outcome = %v reason %q, want UPDATED", items[0].GetOutcome(), items[0].GetReason())
	}
	if items[0].GetBackupId() == "" {
		t.Fatal("updated item has no backup_id")
	}
	return items[0]
}

// gameByName returns the library game with the given display name.
func gameByName(t *testing.T, games []*dlssv1.Game, name string) *dlssv1.Game {
	t.Helper()
	for _, game := range games {
		if game.GetName() == name {
			return game
		}
	}
	t.Fatalf("no game named %q in the library", name)
	return nil
}

func requireBackupReason(t *testing.T, err error, want contract.Reason, wantCode codes.Code, wantPath string) {
	t.Helper()
	requireReason(t, err, want, wantCode)
	detail, ok := contract.FromError(err)
	if !ok {
		t.Fatalf("status has no dlss.v1 ErrorInfo: %v", err)
	}
	if detail.Path != wantPath {
		t.Errorf("error path = %q, want %q", detail.Path, wantPath)
	}
	if detail.Retryable {
		t.Errorf("error %s retryable = true, want false", want)
	}
}

// seedUpdatedDLL builds a one-game library, scans it and updates its DLL from
// the source directory. It returns the directory and names the tests need.
type seededDLL struct {
	gameDir  string
	target   string
	backup   string
	backupID string
	dllID    string
	gameID   string
	// original is the pre-update content, now held by the backup file.
	original []byte
	// replaced is the post-update content, now held by the target.
	replaced []byte
}

func seedUpdatedDLL(t *testing.T, e *backupEnv, appID uint32, name, version string) seededDLL {
	t.Helper()
	lib := testfixtures.NewSteamLibrary(t)
	gameDir := lib.AddGame(testfixtures.GameSpec{
		AppID: appID, Name: name, InstallDir: name,
		DLLs: []testfixtures.DLLSpec{{Path: "bin/nvngx_dlss.dll", Version: version}},
	})
	e.scanLibrary(t, lib.Root())

	game := gameByName(t, listGames(t, e.library), name)
	dll := roleDLLs(t, game.GetDlls())["nvngx_dlss.dll"]
	target := filepath.Join(gameDir, "bin", "nvngx_dlss.dll")
	original := readBytes(t, target)
	item := e.updateOne(t, dll.GetId())
	return seededDLL{
		gameDir:  gameDir,
		target:   target,
		backup:   backupPathFor(target),
		backupID: item.GetBackupId(),
		dllID:    dll.GetId(),
		gameID:   game.GetId(),
		original: original,
		replaced: readBytes(t, target),
	}
}

func TestListBackupsReturnsActiveRecordsWithDisplayFields(t *testing.T) {
	e := newBackupEnv(t)
	e.source.Add("nvngx_dlss.dll", testfixtures.VersionUpdate)
	seed := seedUpdatedDLL(t, e, 5101, "Backup Game", testfixtures.VersionInstalled)

	records := e.list(t, &dlssv1.ListBackupsRequest{})
	if len(records) != 1 {
		t.Fatalf("ListBackups returned %d records, want 1", len(records))
	}
	record := records[0]
	if got := record.GetId(); got != seed.backupID {
		t.Errorf("backup id = %q, want %q", got, seed.backupID)
	}
	if got := record.GetGameId(); got != seed.gameID {
		t.Errorf("game id = %q, want %q", got, seed.gameID)
	}
	if got := record.GetDllId(); got != seed.dllID {
		t.Errorf("dll id = %q, want %q", got, seed.dllID)
	}
	if got := record.GetGameName(); got != "Backup Game" {
		t.Errorf("game name = %q, want %q", got, "Backup Game")
	}
	if got := record.GetDllFilename(); got != "nvngx_dlss.dll" {
		t.Errorf("dll filename = %q, want nvngx_dlss.dll", got)
	}
	if got := record.GetDllType(); got != "dlss" {
		t.Errorf("dll type = %q, want dlss", got)
	}
	if got := record.GetBackupPath(); got != seed.backup {
		t.Errorf("backup path = %q, want %q", got, seed.backup)
	}
	if got := record.GetOriginalVersion(); got != testfixtures.VersionInstalled {
		t.Errorf("original version = %q, want %q", got, testfixtures.VersionInstalled)
	}
	if got, want := record.GetSizeBytes(), int64(len(seed.original)); got != want {
		t.Errorf("size = %d, want %d", got, want)
	}
	if record.GetCreatedAt() == nil {
		t.Error("created_at is missing")
	}
	if !record.GetIsActive() {
		t.Error("is_active = false, want true")
	}
	if record.GetRestoredAt() != nil {
		t.Errorf("restored_at = %v, want nil", record.GetRestoredAt())
	}
	if !record.GetTargetExists() {
		t.Error("target_exists = false, want true")
	}

	// The game filter keeps the same record and an unknown game yields none.
	if filtered := e.list(t, &dlssv1.ListBackupsRequest{GameId: seed.gameID}); len(filtered) != 1 {
		t.Errorf("filtered list returned %d records, want 1", len(filtered))
	}
	if other := e.list(t, &dlssv1.ListBackupsRequest{GameId: "999999"}); len(other) != 0 {
		t.Errorf("unknown game returned %d records, want 0", len(other))
	}
}

func TestListBackupsFiltersByGameAndIncludesSupersededHistory(t *testing.T) {
	e := newBackupEnv(t)
	e.source.Add("nvngx_dlss.dll", testfixtures.VersionUpdate)
	lib := testfixtures.NewSteamLibrary(t)
	lib.AddGame(testfixtures.GameSpec{
		AppID: 5102, Name: "First Game", InstallDir: "First Game",
		DLLs: []testfixtures.DLLSpec{{Path: "nvngx_dlss.dll", Version: testfixtures.VersionInstalled}},
	})
	lib.AddGame(testfixtures.GameSpec{
		AppID: 5103, Name: "Second Game", InstallDir: "Second Game",
		DLLs: []testfixtures.DLLSpec{{Path: "nvngx_dlss.dll", Version: testfixtures.VersionInstalled}},
	})
	e.scanLibrary(t, lib.Root())

	games := listGames(t, e.library)
	first := gameByName(t, games, "First Game")
	second := gameByName(t, games, "Second Game")
	firstDLL := roleDLLs(t, first.GetDlls())["nvngx_dlss.dll"]
	secondDLL := roleDLLs(t, second.GetDlls())["nvngx_dlss.dll"]

	firstBackup := e.updateOne(t, firstDLL.GetId())
	e.updateOne(t, secondDLL.GetId())

	// A newer source makes a second update of the first game necessary; that
	// supersedes the first backup without deleting its file.
	e.source.Add("nvngx_dlss.dll", testfixtures.VersionNewest)
	secondBackup := e.updateOne(t, firstDLL.GetId())

	active := e.list(t, &dlssv1.ListBackupsRequest{})
	if len(active) != 2 {
		t.Fatalf("active list returned %d records, want 2", len(active))
	}
	if got := active[0].GetId(); got != secondBackup.GetBackupId() {
		t.Errorf("first active record = %q, want the newest backup %q", got, secondBackup.GetBackupId())
	}

	firstGameActive := e.list(t, &dlssv1.ListBackupsRequest{GameId: first.GetId()})
	if len(firstGameActive) != 1 || firstGameActive[0].GetId() != secondBackup.GetBackupId() {
		t.Errorf("first game active records = %v, want only the newest backup", recordIDs(firstGameActive))
	}

	history := e.list(t, &dlssv1.ListBackupsRequest{IncludeInactive: true})
	if len(history) != 3 {
		t.Fatalf("history list returned %d records, want 3", len(history))
	}
	superseded := recordByID(t, history, firstBackup.GetBackupId())
	if superseded.GetIsActive() {
		t.Error("superseded backup is still active")
	}
	if superseded.GetRestoredAt() != nil {
		t.Error("superseded backup has a restored_at")
	}
	firstGameHistory := e.list(t, &dlssv1.ListBackupsRequest{GameId: first.GetId(), IncludeInactive: true})
	if got := recordIDs(firstGameHistory); len(got) != 2 || got[0] != secondBackup.GetBackupId() {
		t.Errorf("first game history = %v, want newest first", got)
	}
}

func TestOrphanBackupIsListedAndRestoreRecreatesTarget(t *testing.T) {
	e := newBackupEnv(t)
	e.source.Add("nvngx_dlss.dll", testfixtures.VersionUpdate)
	seed := seedUpdatedDLL(t, e, 5104, "Orphan Game", testfixtures.VersionInstalled)

	if err := os.Remove(seed.target); err != nil {
		t.Fatalf("remove target: %v", err)
	}
	orphans := e.list(t, &dlssv1.ListBackupsRequest{})
	if len(orphans) != 1 {
		t.Fatalf("orphan list returned %d records, want the orphan", len(orphans))
	}
	if orphans[0].GetTargetExists() {
		t.Error("target_exists = true after the target was deleted")
	}
	if !orphans[0].GetIsActive() {
		t.Error("orphan record is not active")
	}

	// A rescan records the absence, so the restore's missing_at clearing is
	// observable through Library.GetGame.
	e.scanLibrary(t, steamRootOf(seed.gameDir))
	game := gameByName(t, listGames(t, e.library), "Orphan Game")
	dll := roleDLLs(t, game.GetDlls())["nvngx_dlss.dll"]
	if dll.GetMissingAt() == nil {
		t.Fatal("rescan did not mark the deleted DLL missing")
	}

	resp, err := e.restore(t, seed.backupID)
	if err != nil {
		t.Fatalf("RestoreBackup: %v", err)
	}
	if got := readBytes(t, seed.target); !bytes.Equal(got, seed.original) {
		t.Error("restored target does not hold the backup bytes")
	}
	if resp.GetDll().GetCurrentVersion() != testfixtures.VersionInstalled {
		t.Errorf("restored version = %q, want %q", resp.GetDll().GetCurrentVersion(), testfixtures.VersionInstalled)
	}
	if !resp.GetDll().GetExists() {
		t.Error("response DLL reports exists = false")
	}
	if resp.GetDll().GetMissingAt() != nil {
		t.Errorf("response DLL missing_at = %v, want nil", resp.GetDll().GetMissingAt())
	}
	if resp.GetBackup().GetIsActive() {
		t.Error("restored backup is still active")
	}
	if resp.GetBackup().GetRestoredAt() == nil {
		t.Error("restored backup has no restored_at")
	}
	if !resp.GetBackup().GetTargetExists() {
		t.Error("restored backup reports target_exists = false")
	}

	// The library reflects the resurrection as well.
	game = gameByName(t, listGames(t, e.library), "Orphan Game")
	dll = roleDLLs(t, game.GetDlls())["nvngx_dlss.dll"]
	if dll.GetCurrentVersion() != testfixtures.VersionInstalled {
		t.Errorf("stored current_version = %q, want %q", dll.GetCurrentVersion(), testfixtures.VersionInstalled)
	}
	if dll.GetMissingAt() != nil {
		t.Errorf("stored missing_at = %v, want nil", dll.GetMissingAt())
	}
	if !dll.GetExists() {
		t.Error("stored DLL reports exists = false after the restore")
	}
	if active := e.list(t, &dlssv1.ListBackupsRequest{}); len(active) != 0 {
		t.Errorf("active list has %d records after the restore, want 0", len(active))
	}
	assertDirEntryNames(t, filepath.Dir(seed.target), "nvngx_dlss.dll", "nvngx_dlss.dlsss")
}

// steamRootOf derives the Steam root from a game directory the fixture built:
// <root>/steamapps/common/<install dir>.
func steamRootOf(gameDir string) string {
	return filepath.Dir(filepath.Dir(filepath.Dir(gameDir)))
}

func TestRestoreCorruptBackupDoesNotTouchTarget(t *testing.T) {
	e := newBackupEnv(t)
	e.source.Add("nvngx_dlss.dll", testfixtures.VersionUpdate)
	seed := seedUpdatedDLL(t, e, 5105, "Corrupt Game", testfixtures.VersionInstalled)

	before := readBytes(t, seed.target)
	file, err := os.OpenFile(seed.backup, os.O_APPEND|os.O_WRONLY, 0)
	if err != nil {
		t.Fatalf("open backup for corruption: %v", err)
	}
	if _, err := file.Write([]byte("corruption")); err != nil {
		t.Fatalf("corrupt backup: %v", err)
	}
	if err := file.Close(); err != nil {
		t.Fatalf("close corrupted backup: %v", err)
	}

	resp, err := e.restore(t, seed.backupID)
	if resp != nil {
		t.Errorf("corrupt restore returned a response: %v", resp)
	}
	requireBackupReason(t, err, contract.ReasonBackupCorrupt, codes.FailedPrecondition, seed.backup)
	if got := readBytes(t, seed.target); !bytes.Equal(got, before) {
		t.Error("corrupt restore modified the target")
	}
	assertDirEntryNames(t, filepath.Dir(seed.target), "nvngx_dlss.dll", "nvngx_dlss.dlsss")
	if active := e.list(t, &dlssv1.ListBackupsRequest{}); len(active) != 1 {
		t.Errorf("active list has %d records after a rejected restore, want 1", len(active))
	}
}

func TestRestoreMissingBackupFileDoesNotTouchTarget(t *testing.T) {
	e := newBackupEnv(t)
	e.source.Add("nvngx_dlss.dll", testfixtures.VersionUpdate)
	seed := seedUpdatedDLL(t, e, 5106, "Missing Backup Game", testfixtures.VersionInstalled)

	before := readBytes(t, seed.target)
	if err := os.Remove(seed.backup); err != nil {
		t.Fatalf("remove backup: %v", err)
	}
	resp, err := e.restore(t, seed.backupID)
	if resp != nil {
		t.Errorf("missing backup restore returned a response: %v", resp)
	}
	requireBackupReason(t, err, contract.ReasonBackupMissing, codes.NotFound, seed.backup)
	if got := readBytes(t, seed.target); !bytes.Equal(got, before) {
		t.Error("missing backup restore modified the target")
	}
	assertDirEntryNames(t, filepath.Dir(seed.target), "nvngx_dlss.dll")
	if active := e.list(t, &dlssv1.ListBackupsRequest{}); len(active) != 1 {
		t.Errorf("active list has %d records after a rejected restore, want 1", len(active))
	}
}

func TestRestoreReportsMissingTargetFolderWithoutCreatingIt(t *testing.T) {
	e := newBackupEnv(t)
	e.source.Add("nvngx_dlss.dll", testfixtures.VersionUpdate)
	seed := seedUpdatedDLL(t, e, 5107, "Folder Game", testfixtures.VersionInstalled)
	before := readBytes(t, seed.target)

	// A backup always lives beside its target, so the backup file exists while
	// the target folder is gone only when the stored path points elsewhere.
	// Move the DLL row to such a path to exercise the guard; the seed itself
	// still came from StartScan + StartUpdate.
	gone := filepath.Join(seed.gameDir, "gone", "nvngx_dlss.dll")
	db, err := sql.Open("sqlite", "file:"+filepath.Join(e.paths.dataDir, "db.sqlite3"))
	if err != nil {
		t.Fatalf("open data directory database: %v", err)
	}
	if _, err := db.Exec(`UPDATE game_dlls SET dll_path = ? WHERE id = ?`, gone, seed.dllID); err != nil {
		_ = db.Close()
		t.Fatalf("move stored DLL path: %v", err)
	}
	if err := db.Close(); err != nil {
		t.Fatalf("close data directory database: %v", err)
	}

	resp, err := e.restore(t, seed.backupID)
	if resp != nil {
		t.Errorf("missing folder restore returned a response: %v", resp)
	}
	requireBackupReason(t, err, contract.ReasonTargetFolderMissing, codes.NotFound, filepath.Dir(gone))
	if _, statErr := os.Stat(filepath.Dir(gone)); !errors.Is(statErr, os.ErrNotExist) {
		t.Errorf("restore created the target folder: %v", statErr)
	}
	if got := readBytes(t, seed.target); !bytes.Equal(got, before) {
		t.Error("missing folder restore modified the original target")
	}
	if active := e.list(t, &dlssv1.ListBackupsRequest{}); len(active) != 1 {
		t.Errorf("active list has %d records after a rejected restore, want 1", len(active))
	}
}

func TestRestoreRollsBackAfterPostReplaceFailure(t *testing.T) {
	p := newPaths(t)
	source := testfixtures.NewDLLSource(t)
	source.Add("nvngx_dlss.dll", testfixtures.VersionUpdate)
	p.dllSource = source.Dir()
	startSidecarWithEnv(t, p,
		[]string{"DLSS_TEST_RESTORE_FAIL_AFTER_REPLACE=nvngx_dlss.dll"},
		func(t *testing.T) string { return dlssdBinaryTagged(t, "integration") })
	e := backupClientsFor(t, p, source)

	seed := seedUpdatedDLL(t, e, 5108, "Rollback Game", testfixtures.VersionInstalled)
	if err := os.Chmod(seed.target, 0o640); err != nil {
		t.Fatalf("set target mode: %v", err)
	}
	before := readBytes(t, seed.target)

	resp, err := e.restore(t, seed.backupID)
	if resp != nil {
		t.Errorf("forced-failure restore returned a response: %v", resp)
	}
	requireBackupReason(t, err, contract.ReasonInternal, codes.Internal, seed.target)

	// The replacement happened and was rolled back: the bytes are the ones
	// the target held before the restore, not the backup's bytes.
	if got := readBytes(t, seed.target); !bytes.Equal(got, before) {
		t.Error("post-replace failure did not roll the target back")
	}
	if got := readBytes(t, seed.target); bytes.Equal(got, seed.original) {
		t.Error("target holds the backup bytes; the replacement was not rolled back")
	}
	if mode := fileMode(t, seed.target); mode != 0o640 {
		t.Errorf("rolled-back target mode = %#o, want 0640", mode)
	}
	assertDirEntryNames(t, filepath.Dir(seed.target), "nvngx_dlss.dll", "nvngx_dlss.dlsss")

	active := e.list(t, &dlssv1.ListBackupsRequest{})
	if len(active) != 1 || active[0].GetId() != seed.backupID {
		t.Errorf("active list = %v, want the untouched backup", recordIDs(active))
	}
	if active[0].GetRestoredAt() != nil {
		t.Error("failed restore marked the backup restored")
	}
	game := gameByName(t, listGames(t, e.library), "Rollback Game")
	dll := roleDLLs(t, game.GetDlls())["nvngx_dlss.dll"]
	if dll.GetCurrentVersion() != testfixtures.VersionUpdate {
		t.Errorf("stored current_version = %q, want unchanged %q", dll.GetCurrentVersion(), testfixtures.VersionUpdate)
	}
}

func TestRestoreReportsMetadataStaleWithoutRollingBackFile(t *testing.T) {
	e := newBackupEnv(t)
	e.source.Add("nvngx_dlss.dll", testfixtures.VersionUpdate)
	seed := seedUpdatedDLL(t, e, 5113, "Stale Restore Game", testfixtures.VersionInstalled)

	// The file replacement succeeds, then the backup-row update aborts. The
	// restore must report stale metadata and leave the restored file in place.
	db, err := sql.Open("sqlite", "file:"+filepath.Join(e.paths.dataDir, "db.sqlite3"))
	if err != nil {
		t.Fatalf("open data directory database: %v", err)
	}
	if _, err := db.Exec(`CREATE TRIGGER fail_restore_metadata
		BEFORE UPDATE ON dll_backups
		WHEN NEW.restored_at IS NOT NULL
		BEGIN SELECT RAISE(ABORT, 'injected metadata failure'); END`); err != nil {
		_ = db.Close()
		t.Fatalf("install restore failure trigger: %v", err)
	}
	if err := db.Close(); err != nil {
		t.Fatalf("close data directory database: %v", err)
	}

	resp, err := e.restore(t, seed.backupID)
	if resp != nil {
		t.Errorf("metadata failure restore returned a response: %v", resp)
	}
	requireReason(t, err, contract.ReasonMetadataStale, codes.Aborted)
	if detail, _ := contract.FromError(err); detail.Path != seed.target || !detail.Retryable {
		t.Errorf("metadata error = path %q retryable %v, want %q and true", detail.Path, detail.Retryable, seed.target)
	}

	// The backup's bytes are in place; only the metadata transaction rolled
	// back, so the stored version is stale until the next scan.
	if got := readBytes(t, seed.target); !bytes.Equal(got, seed.original) {
		t.Error("metadata failure rolled the file restore back")
	}
	assertDirEntryNames(t, filepath.Dir(seed.target), "nvngx_dlss.dll", "nvngx_dlss.dlsss")
	game := gameByName(t, listGames(t, e.library), "Stale Restore Game")
	dll := roleDLLs(t, game.GetDlls())["nvngx_dlss.dll"]
	if dll.GetCurrentVersion() != testfixtures.VersionUpdate {
		t.Errorf("stored current_version = %q, want the rolled-back %q", dll.GetCurrentVersion(), testfixtures.VersionUpdate)
	}
	active := e.list(t, &dlssv1.ListBackupsRequest{})
	if len(active) != 1 || active[0].GetId() != seed.backupID {
		t.Errorf("active list = %v, want the backup untouched", recordIDs(active))
	}
	if active[0].GetRestoredAt() != nil {
		t.Error("failed metadata transaction marked the backup restored")
	}
}

func TestDeleteBackupRemovesFileAndRecord(t *testing.T) {
	e := newBackupEnv(t)
	e.source.Add("nvngx_dlss.dll", testfixtures.VersionUpdate)
	seed := seedUpdatedDLL(t, e, 5109, "Delete Game", testfixtures.VersionInstalled)

	if err := e.delete(t, seed.backupID); err != nil {
		t.Fatalf("DeleteBackup: %v", err)
	}
	if _, err := os.Stat(seed.backup); !errors.Is(err, os.ErrNotExist) {
		t.Errorf("backup file still exists: %v", err)
	}
	assertDirEntryNames(t, filepath.Dir(seed.target), "nvngx_dlss.dll")
	if got := readBytes(t, seed.target); !bytes.Equal(got, seed.replaced) {
		t.Error("deleting a backup modified the target")
	}
	if active := e.list(t, &dlssv1.ListBackupsRequest{}); len(active) != 0 {
		t.Errorf("active list has %d records after the delete, want 0", len(active))
	}
	history := e.list(t, &dlssv1.ListBackupsRequest{IncludeInactive: true})
	if len(history) != 0 {
		t.Errorf("history list has %d records after the delete, want 0 (%v)",
			len(history), recordIDs(history))
	}
	// The row is gone, so a second delete no longer finds it.
	requireBackupReason(t, e.delete(t, seed.backupID),
		contract.ReasonBackupMissing, codes.NotFound, "")
}

func TestDeleteBackupWithMissingFileStillSucceeds(t *testing.T) {
	e := newBackupEnv(t)
	e.source.Add("nvngx_dlss.dll", testfixtures.VersionUpdate)
	seed := seedUpdatedDLL(t, e, 5110, "Gone Game", testfixtures.VersionInstalled)

	if err := os.Remove(seed.backup); err != nil {
		t.Fatalf("remove backup: %v", err)
	}
	if err := e.delete(t, seed.backupID); err != nil {
		t.Fatalf("DeleteBackup with a missing file: %v", err)
	}
	if active := e.list(t, &dlssv1.ListBackupsRequest{}); len(active) != 0 {
		t.Errorf("active list has %d records after the delete, want 0", len(active))
	}
	if history := e.list(t, &dlssv1.ListBackupsRequest{IncludeInactive: true}); len(history) != 0 {
		t.Errorf("history list has %d records after the delete, want 0", len(history))
	}
}

func TestDeleteBackupReportsFileFailureAndKeepsTheRecord(t *testing.T) {
	if os.Geteuid() == 0 {
		t.Skip("root can remove files from a read-only directory")
	}
	e := newBackupEnv(t)
	e.source.Add("nvngx_dlss.dll", testfixtures.VersionUpdate)
	seed := seedUpdatedDLL(t, e, 5111, "Locked Backup Game", testfixtures.VersionInstalled)

	dir := filepath.Dir(seed.backup)
	if err := os.Chmod(dir, 0o555); err != nil {
		t.Fatalf("make backup directory read-only: %v", err)
	}
	t.Cleanup(func() { _ = os.Chmod(dir, 0o755) })

	err := e.delete(t, seed.backupID)
	requireBackupReason(t, err, contract.ReasonPermissionDenied, codes.PermissionDenied, seed.backup)
	if _, statErr := os.Stat(seed.backup); statErr != nil {
		t.Errorf("backup file disappeared despite the failed delete: %v", statErr)
	}
	active := e.list(t, &dlssv1.ListBackupsRequest{})
	if len(active) != 1 || active[0].GetId() != seed.backupID {
		t.Errorf("active list = %v, want the record to remain active", recordIDs(active))
	}
	if history := e.list(t, &dlssv1.ListBackupsRequest{IncludeInactive: true}); len(history) != 1 {
		t.Errorf("history list = %v, want the record to remain", recordIDs(history))
	}
}

func TestRestoreRejectedWhileUpdateIsRunning(t *testing.T) {
	e := newBackupEnv(t)
	e.source.Add("nvngx_dlss.dll", testfixtures.VersionUpdate)

	// Enough files make the run long enough to observe UpdateRunning after the
	// stream opened and to attempt a restore while it still processes items.
	const dllCount = 300
	specs := make([]testfixtures.DLLSpec, 0, dllCount)
	for i := 0; i < dllCount; i++ {
		specs = append(specs, testfixtures.DLLSpec{
			Path:    fmt.Sprintf("d%03d/nvngx_dlss.dll", i),
			Version: testfixtures.VersionInstalled,
		})
	}
	lib := testfixtures.NewSteamLibrary(t)
	lib.AddGame(testfixtures.GameSpec{
		AppID: 5112, Name: "Busy Game", InstallDir: "Busy Game", DLLs: specs,
	})
	e.scanLibrary(t, lib.Root())

	ids := allDLLIDs(t, e.library)
	if len(ids) != dllCount {
		t.Fatalf("library has %d DLLs, want %d", len(ids), dllCount)
	}
	// Give the restore call a real backup to ask for.
	firstBackup := e.updateOne(t, ids[0])

	updateDone := make(chan []*dlssv1.UpdateEvent, 1)
	updateErr := make(chan error, 1)
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
		defer cancel()
		stream, err := e.update.StartUpdate(ctx, &dlssv1.StartUpdateRequest{DllIds: ids})
		if err != nil {
			updateErr <- err
			return
		}
		events, err := collectUpdate(stream)
		if err != nil {
			updateErr <- err
			return
		}
		updateDone <- events
	}()

	waitFor(t, 10*time.Second, "the update to report itself running", func() bool {
		status, err := probeStatus(e.paths.socket)
		return err == nil && status.GetUpdateRunning()
	})

	resp, err := e.restore(t, firstBackup.GetBackupId())
	if resp != nil {
		t.Errorf("restore during an update returned a response: %v", resp)
	}
	requireReason(t, err, contract.ReasonUpdateInProgress, codes.FailedPrecondition)

	select {
	case events := <-updateDone:
		finished := updateFinished(t, events)
		if finished.GetSucceeded() != dllCount-1 || finished.GetSkipped() != 1 {
			t.Errorf("update finished with %d succeeded and %d skipped, want %d and 1",
				finished.GetSucceeded(), finished.GetSkipped(), dllCount-1)
		}
	case err := <-updateErr:
		t.Fatalf("update after the restore attempt: %v", err)
	case <-time.After(120 * time.Second):
		t.Fatal("update did not finish")
	}

	// The first DLL was up to date and kept its backup active; every other
	// item created one.
	active := e.list(t, &dlssv1.ListBackupsRequest{})
	if len(active) != dllCount {
		t.Fatalf("active backups = %d, want %d", len(active), dllCount)
	}
	found := false
	for _, record := range active {
		if record.GetId() == firstBackup.GetBackupId() {
			found = true
		}
	}
	if !found {
		t.Error("the rejected restore deactivated the old backup")
	}
}

func recordIDs(records []*dlssv1.BackupRecord) []string {
	ids := make([]string, 0, len(records))
	for _, record := range records {
		ids = append(ids, record.GetId())
	}
	return ids
}

func recordByID(t *testing.T, records []*dlssv1.BackupRecord, id string) *dlssv1.BackupRecord {
	t.Helper()
	for _, record := range records {
		if record.GetId() == id {
			return record
		}
	}
	t.Fatalf("no backup %q in %v", id, recordIDs(records))
	return nil
}
