//go:build integration

package integration

import (
	"bytes"
	"context"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"runtime"
	"strings"
	"testing"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"

	dlssv1 "github.com/Qxy0happy/DLSS-Updater/backend/gen/dlss/v1"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/testfixtures"
)

// TestAcceptanceFullSlice is the acceptance evidence for the whole slice: one
// real dlssd process on a temporary Unix socket and temporary data directory
// drives scan -> update -> backup -> restore -> delete through the generated
// clients, then shuts down. Everything the daemon can touch lives under the
// test's temporary roots and is compared before and after.
func TestAcceptanceFullSlice(t *testing.T) {
	p := newPaths(t)
	source := testfixtures.NewDLLSource(t)
	p.dllSource = source.Dir()
	source.Add(testfixtures.DLSSDLL, testfixtures.VersionUpdate)

	lib := testfixtures.NewSteamLibrary(t)
	gameDir := lib.AddGame(testfixtures.GameSpec{
		AppID: 9001, Name: "Acceptance Game", InstallDir: "Acceptance Game",
		DLLs: []testfixtures.DLLSpec{
			{Path: "bin/nvngx_dlss.dll", Version: testfixtures.VersionInstalled},
		},
	})
	lib.AddGame(testfixtures.GameSpec{
		AppID: 9002, Name: "Second Game", InstallDir: "Second Game",
		DLLs: []testfixtures.DLLSpec{
			{Path: "nvngx_dlssg.dll", Version: testfixtures.VersionInstalled},
		},
	})
	target := filepath.Join(gameDir, "bin", testfixtures.DLSSDLL)
	backupPath := backupPathFor(target)
	original := readBytes(t, target)
	originalMode := fileMode(t, target)
	replacement := readBytes(t, source.Path(testfixtures.DLSSDLL))

	// Snapshot every fixture tree before the daemon starts. After the flow
	// the same names, sizes and permissions must be present again: no
	// temporary file, socket, lock or log may leak into them.
	beforeRoots := snapshotTrees(t, lib.TempRoot(), source.TempRoot())

	s := startSidecar(t, p)
	conn, err := grpc.NewClient("unix://"+p.socket, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		t.Fatalf("grpc.NewClient(%s): %v", p.socket, err)
	}
	t.Cleanup(func() { _ = conn.Close() })
	daemonClient := dlssv1.NewDaemonClient(conn)
	scanClient := dlssv1.NewScanClient(conn)
	libraryClient := dlssv1.NewLibraryClient(conn)
	updateClient := dlssv1.NewUpdateClient(conn)
	backupClient := dlssv1.NewBackupClient(conn)

	statusCtx, statusCancel := context.WithTimeout(context.Background(), 5*time.Second)
	status, err := daemonClient.GetStatus(statusCtx, &dlssv1.GetStatusRequest{})
	statusCancel()
	if err != nil {
		t.Fatalf("GetStatus: %v", err)
	}
	if got, want := status.GetAppVersion(), repoVersion(t); got != want {
		t.Errorf("daemon app_version = %q, want the repository VERSION %q", got, want)
	}
	if got, want := status.GetProtoVersion(), "dlss.v1"; got != want {
		t.Errorf("proto_version = %q, want %q", got, want)
	}

	// Scan the fixture Steam root.
	scanEvents := runScan(t, scanClient, lib.Root())
	assertScanSequence(t, scanEvents, 2)
	games := listGames(t, libraryClient)
	if len(games) != 2 {
		t.Fatalf("ListGames returned %d games, want 2", len(games))
	}
	var dlssDLL *dlssv1.GameDLL
	for _, game := range games {
		if game.GetId() == "" || game.GetInstallPath() == "" {
			t.Errorf("game %q has an empty id or install path: %+v", game.GetName(), game)
		}
		for _, dll := range game.GetDlls() {
			if dll.GetFilename() != testfixtures.DLSSDLL {
				continue
			}
			dlssDLL = dll
			if got := dll.GetCurrentVersion(); got != testfixtures.VersionInstalled {
				t.Errorf("scanned version = %q, want %q", got, testfixtures.VersionInstalled)
			}
			if !dll.GetExists() {
				t.Error("scanned DLL is marked missing")
			}
			if got := dll.GetDllType(); got != "dlss" {
				t.Errorf("dll type = %q, want dlss", got)
			}
			if got := dll.GetPath(); got != target {
				t.Errorf("dll path = %q, want %q", got, target)
			}
		}
	}
	if dlssDLL == nil {
		t.Fatalf("library has no %s", testfixtures.DLSSDLL)
	}

	// Update the single DLL.
	updateEvents := runUpdate(t, updateClient, []string{dlssDLL.GetId()})
	assertUpdateSequence(t, updateEvents)
	finished := updateFinished(t, updateEvents)
	if got := finished.GetSucceeded(); got != 1 {
		t.Errorf("update succeeded = %d, want 1", got)
	}
	if got := finished.GetSkipped(); got != 0 {
		t.Errorf("update skipped = %d, want 0", got)
	}
	if got := finished.GetFailed(); got != 0 {
		t.Errorf("update failed = %d, want 0", got)
	}
	if finished.GetCancelled() {
		t.Error("update reports cancelled = true")
	}
	item := itemsFinished(t, updateEvents)[0]
	requireItemOutcome(t, item, dlssv1.UpdateOutcome_UPDATE_OUTCOME_UPDATED, "")
	if got := item.GetResultingVersion(); got != testfixtures.VersionUpdate {
		t.Errorf("resulting version = %q, want %q", got, testfixtures.VersionUpdate)
	}
	if item.GetBackupId() == "" {
		t.Fatal("updated item reports no backup_id")
	}

	// The replaced target keeps the original permissions and holds the source
	// bytes; the backup is a 0600 copy of the original bytes.
	if got := readBytes(t, target); !bytes.Equal(got, replacement) {
		t.Errorf("target bytes after update differ from the source DLL")
	}
	if got := fileMode(t, target); got != originalMode {
		t.Errorf("target mode after update = %#o, want %#o", got, originalMode)
	}
	if got := readBytes(t, backupPath); !bytes.Equal(got, original) {
		t.Error("backup bytes differ from the original target")
	}
	if got := fileMode(t, backupPath); got != 0o600 {
		t.Errorf("backup mode = %#o, want 0600", got)
	}
	assertDirEntryNames(t, filepath.Dir(target), testfixtures.DLSSDLL, "nvngx_dlss.dlsss")

	// The backup record is active and carries the fields the Backups view
	// renders.
	records := listBackups(t, backupClient, &dlssv1.ListBackupsRequest{})
	if len(records) != 1 {
		t.Fatalf("ListBackups returned %d records, want 1", len(records))
	}
	record := records[0]
	if got := record.GetId(); got != item.GetBackupId() {
		t.Errorf("backup id = %q, want %q", got, item.GetBackupId())
	}
	if !record.GetIsActive() {
		t.Error("listed backup is not active")
	}
	if record.GetRestoredAt() != nil {
		t.Errorf("restored_at = %v, want nil before restore", record.GetRestoredAt())
	}
	if got, want := record.GetBackupPath(), backupPath; got != want {
		t.Errorf("backup path = %q, want %q", got, want)
	}
	if got, want := record.GetOriginalVersion(), testfixtures.VersionInstalled; got != want {
		t.Errorf("original version = %q, want %q", got, want)
	}
	if got, want := record.GetSizeBytes(), int64(len(original)); got != want {
		t.Errorf("backup size = %d, want %d", got, want)
	}
	if got, want := record.GetGameName(), "Acceptance Game"; got != want {
		t.Errorf("game name = %q, want %q", got, want)
	}
	if !record.GetTargetExists() {
		t.Error("backup says the target does not exist")
	}

	// Restore through the real RPC, then check bytes and metadata.
	restoreCtx, restoreCancel := context.WithTimeout(context.Background(), 30*time.Second)
	restored, err := backupClient.RestoreBackup(restoreCtx, &dlssv1.RestoreBackupRequest{BackupId: record.GetId()})
	restoreCancel()
	if err != nil {
		t.Fatalf("RestoreBackup: %v", err)
	}
	if got := restored.GetDll().GetCurrentVersion(); got != testfixtures.VersionInstalled {
		t.Errorf("version after restore = %q, want %q", got, testfixtures.VersionInstalled)
	}
	if restored.GetBackup().GetIsActive() {
		t.Error("restored backup is still active")
	}
	if restored.GetBackup().GetRestoredAt() == nil {
		t.Error("restored backup has no restored_at")
	}
	if got := readBytes(t, target); !bytes.Equal(got, original) {
		t.Error("target bytes after restore differ from the original DLL")
	}
	if got := fileMode(t, target); got != originalMode {
		t.Errorf("target mode after restore = %#o, want %#o", got, originalMode)
	}
	if got := readBytes(t, backupPath); !bytes.Equal(got, original) {
		t.Error("restore deleted or changed the backup file")
	}
	if active := listBackups(t, backupClient, &dlssv1.ListBackupsRequest{}); len(active) != 0 {
		t.Errorf("active list after restore = %d records, want 0", len(active))
	}
	history := listBackups(t, backupClient, &dlssv1.ListBackupsRequest{IncludeInactive: true})
	if len(history) != 1 || history[0].GetRestoredAt() == nil {
		t.Fatalf("history after restore = %d records (want 1 with restored_at)", len(history))
	}

	// Delete the backup: the file and the record go away without touching the
	// restored target.
	deleteCtx, deleteCancel := context.WithTimeout(context.Background(), 30*time.Second)
	if _, err := backupClient.DeleteBackup(deleteCtx, &dlssv1.DeleteBackupRequest{BackupId: record.GetId()}); err != nil {
		deleteCancel()
		t.Fatalf("DeleteBackup: %v", err)
	}
	deleteCancel()
	if _, err := os.Stat(backupPath); !errors.Is(err, os.ErrNotExist) {
		t.Errorf("backup file still exists after delete: %v", err)
	}
	if got := readBytes(t, target); !bytes.Equal(got, original) {
		t.Error("delete changed the restored target")
	}
	if active := listBackups(t, backupClient, &dlssv1.ListBackupsRequest{}); len(active) != 0 {
		t.Errorf("active list after delete = %d records, want 0", len(active))
	}
	if history := listBackups(t, backupClient, &dlssv1.ListBackupsRequest{IncludeInactive: true}); len(history) != 0 {
		t.Errorf("history list after delete = %d records, want 0", len(history))
	}
	assertDirEntryNames(t, filepath.Dir(target), testfixtures.DLSSDLL)

	// The fixture trees are byte-for-byte and mode-for-mode what they were
	// before the daemon started.
	afterRoots := snapshotTrees(t, lib.TempRoot(), source.TempRoot())
	if !reflect.DeepEqual(beforeRoots, afterRoots) {
		t.Errorf("fixture trees changed outside the intended files:\nbefore: %v\nafter:  %v", beforeRoots, afterRoots)
	}

	// Shutdown: the process exits, the socket disappears and the data
	// directory holds only daemon-owned state, no socket, lock in the data
	// directory only, and logs inside logs/.
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 5*time.Second)
	_, err = daemonClient.Shutdown(shutdownCtx, &dlssv1.ShutdownRequest{})
	shutdownCancel()
	if err != nil {
		t.Fatalf("Shutdown: %v", err)
	}
	if !s.wait(5 * time.Second) {
		t.Fatalf("dlssd did not exit after Shutdown; stderr: %s", s.stderr.String())
	}
	if s.exitErr != nil {
		t.Errorf("dlssd exit: %v; stderr: %s", s.exitErr, s.stderr.String())
	}
	waitFor(t, 2*time.Second, "socket removal", func() bool {
		_, err := os.Lstat(p.socket)
		return errors.Is(err, os.ErrNotExist)
	})
	assertSocketDirEmpty(t, p.socketDir)
	assertDataDirOnlyDaemonState(t, p.dataDir)
}

// assertScanSequence checks the externally visible scan event shape: exactly
// one started first, a progress event per library, one game_found per game
// and exactly one finished last. Warnings and failures are not expected for
// a fully readable fixture library.
func assertScanSequence(t *testing.T, events []*dlssv1.ScanEvent, wantGames int) {
	t.Helper()
	if len(events) < 4 {
		t.Fatalf("scan events = %v, want at least started/progress/games/finished", describeEvents(events))
	}
	if events[0].GetStarted() == nil {
		t.Errorf("first scan event = %v, want started", describeEvents(events))
	}
	if events[len(events)-1].GetFinished() == nil {
		t.Errorf("last scan event = %v, want finished", describeEvents(events))
	}
	var progress, found, finished int
	for _, event := range events {
		switch {
		case event.GetStarted() != nil:
			// one started event only; counted below
		case event.GetLibraryProgress() != nil:
			progress++
		case event.GetGameFound() != nil:
			found++
		case event.GetWarning() != nil:
			t.Errorf("unexpected scan warning: %s", event.GetWarning().GetPath())
		case event.GetFailed() != nil:
			t.Errorf("unexpected scan failure: %s", event.GetFailed().GetReason())
		case event.GetFinished() != nil:
			finished++
		}
	}
	if progress == 0 {
		t.Error("scan sent no library_progress event")
	}
	if found != wantGames {
		t.Errorf("game_found events = %d, want %d", found, wantGames)
	}
	if finished != 1 {
		t.Errorf("finished events = %d, want 1", finished)
	}
	summary := finishSummary(t, events)
	if got, want := int(summary.GetGameCount()), wantGames; got != want {
		t.Errorf("finished game_count = %d, want %d", got, want)
	}
	if got, want := int(summary.GetDllCount()), wantGames; got != want {
		t.Errorf("finished dll_count = %d, want %d", got, want)
	}
	if summary.GetCancelled() {
		t.Error("scan finished reports cancelled = true")
	}
}

// assertUpdateSequence checks the one-item update event shape.
func assertUpdateSequence(t *testing.T, events []*dlssv1.UpdateEvent) {
	t.Helper()
	if len(events) != 4 {
		t.Fatalf("update events = %v, want started/item_started/item_finished/finished", describeUpdateEvents(events))
	}
	if events[0].GetStarted() == nil {
		t.Errorf("first update event = %v, want started", describeUpdateEvents(events))
	}
	if got := events[0].GetStarted().GetItemCount(); got != 1 {
		t.Errorf("started item_count = %d, want 1", got)
	}
	if events[1].GetItemStarted() == nil {
		t.Errorf("second update event = %v, want item_started", describeUpdateEvents(events))
	}
	if events[2].GetItemFinished() == nil {
		t.Errorf("third update event = %v, want item_finished", describeUpdateEvents(events))
	}
	if events[3].GetFinished() == nil {
		t.Errorf("last update event = %v, want finished", describeUpdateEvents(events))
	}
	started := events[1].GetItemStarted()
	if got, want := started.GetIndex(), int32(1); got != want {
		t.Errorf("item_started index = %d, want %d", got, want)
	}
	if got, want := started.GetTotal(), int32(1); got != want {
		t.Errorf("item_started total = %d, want %d", got, want)
	}
}

func listBackups(t *testing.T, client dlssv1.BackupClient, req *dlssv1.ListBackupsRequest) []*dlssv1.BackupRecord {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	resp, err := client.ListBackups(ctx, req)
	if err != nil {
		t.Fatalf("ListBackups(%+v): %v", req, err)
	}
	return resp.GetBackups()
}

// treeEntry is what the acceptance test compares before and after the flow.
type treeEntry struct {
	mode os.FileMode
	size int64
}

// snapshotTrees returns one map of every file below the given roots, keyed by
// the root-relative path. Directories are included so a leaked temporary
// directory would also fail.
func snapshotTrees(t *testing.T, roots ...string) map[string]treeEntry {
	t.Helper()
	out := map[string]treeEntry{}
	for _, root := range roots {
		err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return err
			}
			rel, err := filepath.Rel(filepath.Dir(root), path)
			if err != nil {
				return err
			}
			entry := treeEntry{mode: info.Mode()}
			if info.Mode().IsRegular() {
				entry.size = info.Size()
			}
			out[rel] = entry
			return nil
		})
		if err != nil {
			t.Fatalf("walk %s: %v", root, err)
		}
	}
	return out
}

func assertSocketDirEmpty(t *testing.T, dir string) {
	t.Helper()
	entries, err := os.ReadDir(dir)
	if err != nil {
		t.Fatalf("read socket dir %s: %v", dir, err)
	}
	if len(entries) != 0 {
		names := make([]string, 0, len(entries))
		for _, entry := range entries {
			names = append(names, entry.Name())
		}
		t.Errorf("socket directory %s is not empty after shutdown: %v", dir, names)
	}
}

// assertDataDirOnlyDaemonState rejects any socket, stray lock, or log outside
// logs/ in the data directory. The lock file and SQLite files are expected
// daemon-owned state, not residue.
func assertDataDirOnlyDaemonState(t *testing.T, dir string) {
	t.Helper()
	allowed := map[string]bool{
		"db.sqlite3":     true,
		"db.sqlite3-wal": true,
		"db.sqlite3-shm": true,
		"daemon.lock":    true,
		"logs":           true,
	}
	entries, err := os.ReadDir(dir)
	if err != nil {
		t.Fatalf("read data dir %s: %v", dir, err)
	}
	for _, entry := range entries {
		name := entry.Name()
		if !allowed[name] {
			t.Errorf("unexpected entry in data dir: %s", name)
		}
		if entry.Type()&os.ModeSocket != 0 || strings.HasSuffix(name, ".sock") {
			t.Errorf("socket left in data dir: %s", name)
		}
		if strings.HasSuffix(name, ".log") {
			t.Errorf("log left outside logs/: %s", name)
		}
	}
}

// TestVersionFlagDoesNotRequirePaths keeps `dlssd --version` usable from a
// package build: no data directory, socket or DLL source may be required.
func TestVersionFlagDoesNotRequirePaths(t *testing.T) {
	out, err := exec.Command(dlssdBinary(t), "--version").CombinedOutput()
	if err != nil {
		t.Fatalf("dlssd --version: %v\n%s", err, out)
	}
	if got, want := strings.TrimSpace(string(out)), repoVersion(t); got != want {
		t.Errorf("--version = %q, want the repository VERSION %q", got, want)
	}
	if strings.Contains(string(out), "usage") {
		t.Errorf("--version printed usage:\n%s", out)
	}
}

// repoVersion reads the root VERSION file the build and Makefile use.
func repoVersion(t *testing.T) string {
	t.Helper()
	_, file, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("cannot locate the test source file")
	}
	root := filepath.Dir(filepath.Dir(filepath.Dir(file)))
	data, err := os.ReadFile(filepath.Join(root, "VERSION"))
	if err != nil {
		t.Fatalf("read VERSION: %v", err)
	}
	return strings.TrimSpace(string(data))
}
