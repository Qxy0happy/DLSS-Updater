//go:build integration

package integration

import (
	"bytes"
	"context"
	"database/sql"
	"errors"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials/insecure"

	dlssv1 "github.com/Qxy0happy/DLSS-Updater/backend/gen/dlss/v1"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/contract"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/testfixtures"

	_ "modernc.org/sqlite"
)

// updateClients opens one channel for the services the update tests drive.
func updateClients(t *testing.T, socket string) (dlssv1.UpdateClient, dlssv1.LibraryClient, dlssv1.ScanClient, func()) {
	t.Helper()
	conn, err := grpc.NewClient("unix://"+socket, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		t.Fatalf("grpc.NewClient(%s): %v", socket, err)
	}
	return dlssv1.NewUpdateClient(conn), dlssv1.NewLibraryClient(conn), dlssv1.NewScanClient(conn), func() { _ = conn.Close() }
}

func collectUpdate(stream dlssv1.Update_StartUpdateClient) ([]*dlssv1.UpdateEvent, error) {
	var events []*dlssv1.UpdateEvent
	for {
		event, err := stream.Recv()
		if err != nil {
			if errors.Is(err, io.EOF) {
				return events, nil
			}
			return events, err
		}
		events = append(events, event)
	}
}

func runUpdate(t *testing.T, client dlssv1.UpdateClient, ids []string) []*dlssv1.UpdateEvent {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()
	stream, err := client.StartUpdate(ctx, &dlssv1.StartUpdateRequest{DllIds: ids})
	if err != nil {
		t.Fatalf("StartUpdate: %v", err)
	}
	events, err := collectUpdate(stream)
	if err != nil {
		t.Fatalf("update stream: %v", err)
	}
	return events
}

// updateFinished asserts the stream carried no run-level failed event and
// exactly one finished event, and returns it.
func updateFinished(t *testing.T, events []*dlssv1.UpdateEvent) *dlssv1.UpdateFinished {
	t.Helper()
	var finished []*dlssv1.UpdateFinished
	for _, event := range events {
		if failed := event.GetFailed(); failed != nil {
			t.Fatalf("update failed: reason=%s message=%s", failed.GetReason(), failed.GetMessage())
		}
		if event.GetFinished() != nil {
			finished = append(finished, event.GetFinished())
		}
	}
	if len(finished) != 1 {
		t.Fatalf("finished events = %d, want exactly 1 (%v)", len(finished), describeUpdateEvents(events))
	}
	return finished[0]
}

func describeUpdateEvents(events []*dlssv1.UpdateEvent) []string {
	out := make([]string, 0, len(events))
	for _, event := range events {
		switch {
		case event.GetStarted() != nil:
			out = append(out, "started")
		case event.GetItemStarted() != nil:
			out = append(out, "item_started:"+event.GetItemStarted().GetFilename())
		case event.GetItemFinished() != nil:
			out = append(out, "item_finished:"+event.GetItemFinished().GetReason())
		case event.GetFinished() != nil:
			out = append(out, "finished")
		case event.GetFailed() != nil:
			out = append(out, "failed:"+event.GetFailed().GetReason())
		default:
			out = append(out, "unknown")
		}
	}
	return out
}

// beginUpdate is the checking variant runUpdate uses for empty and mixed
// requests; it keeps the strict one-finished-event rule.
func beginUpdate(t *testing.T, client dlssv1.UpdateClient, ids []string) dlssv1.Update_StartUpdateClient {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	t.Cleanup(cancel)
	stream, err := client.StartUpdate(ctx, &dlssv1.StartUpdateRequest{DllIds: ids})
	if err != nil {
		t.Fatalf("StartUpdate: %v", err)
	}
	return stream
}

func itemsFinished(t *testing.T, events []*dlssv1.UpdateEvent) []*dlssv1.UpdateItemFinished {
	t.Helper()
	var out []*dlssv1.UpdateItemFinished
	for _, event := range events {
		if item := event.GetItemFinished(); item != nil {
			out = append(out, item)
		}
	}
	return out
}

func dllByFilename(t *testing.T, client dlssv1.LibraryClient, filename string) *dlssv1.GameDLL {
	t.Helper()
	for _, game := range listGames(t, client) {
		for _, dll := range game.GetDlls() {
			if strings.EqualFold(dll.GetFilename(), filename) {
				return dll
			}
		}
	}
	t.Fatalf("no %s in the library", filename)
	return nil
}

func allDLLIDs(t *testing.T, client dlssv1.LibraryClient) []string {
	t.Helper()
	var ids []string
	for _, game := range listGames(t, client) {
		for _, dll := range game.GetDlls() {
			ids = append(ids, dll.GetId())
		}
	}
	if len(ids) == 0 {
		t.Fatal("library has no DLLs")
	}
	return ids
}

func versionByDLLID(t *testing.T, client dlssv1.LibraryClient) map[string]string {
	t.Helper()
	versions := map[string]string{}
	for _, game := range listGames(t, client) {
		for _, dll := range game.GetDlls() {
			versions[dll.GetId()] = dll.GetCurrentVersion()
		}
	}
	return versions
}

func readBytes(t *testing.T, path string) []byte {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read %s: %v", path, err)
	}
	return data
}

func backupPathFor(target string) string {
	return strings.TrimSuffix(target, filepath.Ext(target)) + ".dlsss"
}

// assertDirEntryNames asserts dir contains exactly the given base names, so a
// leaked temporary file fails the test.
func assertDirEntryNames(t *testing.T, dir string, want ...string) {
	t.Helper()
	entries, err := os.ReadDir(dir)
	if err != nil {
		t.Fatalf("read dir %s: %v", dir, err)
	}
	got := make([]string, 0, len(entries))
	for _, entry := range entries {
		got = append(got, entry.Name())
	}
	if len(got) != len(want) {
		t.Fatalf("%s entries = %v, want %v", dir, got, want)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("%s entries = %v, want %v", dir, got, want)
		}
	}
}

func requireItemOutcome(t *testing.T, item *dlssv1.UpdateItemFinished, outcome dlssv1.UpdateOutcome, reason string) {
	t.Helper()
	if item.GetOutcome() != outcome {
		t.Errorf("outcome = %v, want %v", item.GetOutcome(), outcome)
	}
	if item.GetReason() != reason {
		t.Errorf("reason = %q, want %q", item.GetReason(), reason)
	}
}

// installHistoryFailureTrigger makes the next update-history insert abort, so
// the metadata transaction fails after the file replacement has succeeded.
func installHistoryFailureTrigger(t *testing.T, dataDir string) {
	t.Helper()
	path := filepath.Join(dataDir, "db.sqlite3")
	db, err := sql.Open("sqlite", "file:"+path)
	if err != nil {
		t.Fatalf("open data directory database: %v", err)
	}
	t.Cleanup(func() { _ = db.Close() })
	if _, err := db.Exec(`CREATE TRIGGER fail_update_history
		BEFORE INSERT ON update_history
		BEGIN SELECT RAISE(ABORT, 'injected metadata failure'); END`); err != nil {
		t.Fatalf("install history failure trigger: %v", err)
	}
}

func TestUpdateReportsMetadataStaleWithoutRollingBackFile(t *testing.T) {
	p := newPaths(t)
	source := testfixtures.NewDLLSource(t)
	sourcePath := source.Add("nvngx_dlss.dll", testfixtures.VersionUpdate)
	p.dllSource = source.Dir()
	startSidecar(t, p)
	updateClient, libraryClient, scanClient, closeClients := updateClients(t, p.socket)
	defer closeClients()

	lib := testfixtures.NewSteamLibrary(t)
	gameDir := lib.AddGame(testfixtures.GameSpec{
		AppID: 2009, Name: "Stale Metadata Game", InstallDir: "Stale Metadata Game",
		DLLs: []testfixtures.DLLSpec{{Path: "nvngx_dlss.dll", Version: testfixtures.VersionInstalled}},
	})
	runScan(t, scanClient, lib.Root())
	target := filepath.Join(gameDir, "nvngx_dlss.dll")
	original := readBytes(t, target)
	dll := dllByFilename(t, libraryClient, "nvngx_dlss.dll")
	installHistoryFailureTrigger(t, p.dataDir)

	events := runUpdate(t, updateClient, []string{dll.GetId()})
	item := itemsFinished(t, events)
	if len(item) != 1 {
		t.Fatalf("item_finished events = %d, want 1", len(item))
	}
	requireItemOutcome(t, item[0], dlssv1.UpdateOutcome_UPDATE_OUTCOME_FAILED, "METADATA_STALE")
	if item[0].GetBackupId() != "" {
		t.Errorf("failed metadata transaction reported backup_id %q", item[0].GetBackupId())
	}

	// The already-written target stays replaced; only the metadata rolled back.
	if got, want := readBytes(t, target), readBytes(t, sourcePath); !bytes.Equal(got, want) {
		t.Error("metadata failure rolled the replacement back")
	}
	if got := readBytes(t, backupPathFor(target)); !bytes.Equal(got, original) {
		t.Error("backup does not hold the pre-update bytes")
	}
	if got := roleDLLs(t, listGames(t, libraryClient)[0].GetDlls())["nvngx_dlss.dll"].GetCurrentVersion(); got != testfixtures.VersionInstalled {
		t.Errorf("stored current_version = %q, want the rolled-back %q", got, testfixtures.VersionInstalled)
	}
}

func TestUpdateReplacesDLLAndCreatesBackup(t *testing.T) {
	p := newPaths(t)
	source := testfixtures.NewDLLSource(t)
	sourcePath := source.Add("nvngx_dlss.dll", testfixtures.VersionUpdate)
	p.dllSource = source.Dir()
	startSidecar(t, p)
	updateClient, libraryClient, scanClient, closeClients := updateClients(t, p.socket)
	defer closeClients()

	lib := testfixtures.NewSteamLibrary(t)
	gameDir := lib.AddGame(testfixtures.GameSpec{
		AppID: 2001, Name: "Update Game", InstallDir: "Update Game",
		DLLs: []testfixtures.DLLSpec{{Path: "bin/nvngx_dlss.dll", Version: testfixtures.VersionInstalled}},
	})
	runScan(t, scanClient, lib.Root())

	target := filepath.Join(gameDir, "bin", "nvngx_dlss.dll")
	if err := os.Chmod(target, 0o640); err != nil {
		t.Fatalf("set target mode: %v", err)
	}
	original := readBytes(t, target)
	sourceBytes := readBytes(t, sourcePath)
	dll := dllByFilename(t, libraryClient, "nvngx_dlss.dll")

	events := runUpdate(t, updateClient, []string{dll.GetId()})
	if len(events) != 4 {
		t.Fatalf("events = %v, want started/item_started/item_finished/finished", describeUpdateEvents(events))
	}
	started := events[0].GetStarted()
	if started == nil || started.GetItemCount() != 1 {
		t.Fatalf("first event = %v, want started with item_count 1", describeUpdateEvents(events))
	}
	if started.GetStartedAt() == nil {
		t.Error("started.started_at is missing")
	}
	itemStarted := events[1].GetItemStarted()
	if itemStarted == nil {
		t.Fatalf("second event = %v, want item_started", describeUpdateEvents(events))
	}
	if itemStarted.GetDllId() != dll.GetId() || itemStarted.GetFilename() != "nvngx_dlss.dll" {
		t.Errorf("item_started = id %q filename %q", itemStarted.GetDllId(), itemStarted.GetFilename())
	}
	if itemStarted.GetIndex() != 1 || itemStarted.GetTotal() != 1 {
		t.Errorf("item_started index/total = %d/%d, want 1/1", itemStarted.GetIndex(), itemStarted.GetTotal())
	}

	item := events[2].GetItemFinished()
	if item == nil {
		t.Fatalf("third event = %v, want item_finished", describeUpdateEvents(events))
	}
	requireItemOutcome(t, item, dlssv1.UpdateOutcome_UPDATE_OUTCOME_UPDATED, "")
	if item.GetBackupId() == "" {
		t.Error("item_finished.backup_id is empty for an updated item")
	}
	if item.GetResultingVersion() != testfixtures.VersionUpdate {
		t.Errorf("resulting_version = %q, want %q", item.GetResultingVersion(), testfixtures.VersionUpdate)
	}

	finished := updateFinished(t, events)
	if finished.GetSucceeded() != 1 || finished.GetSkipped() != 0 || finished.GetFailed() != 0 {
		t.Errorf("finished counts = %d/%d/%d, want 1/0/0",
			finished.GetSucceeded(), finished.GetSkipped(), finished.GetFailed())
	}
	if finished.GetCancelled() {
		t.Error("finished.cancelled = true, want false")
	}

	// The backup keeps the original bytes and is private.
	backup := backupPathFor(target)
	if got := readBytes(t, backup); !bytes.Equal(got, original) {
		t.Error("backup bytes differ from the original target")
	}
	if mode := fileMode(t, backup); mode != 0o600 {
		t.Errorf("backup mode = %#o, want 0600", mode)
	}
	// The target holds the source bytes and kept its permissions.
	if got := readBytes(t, target); !bytes.Equal(got, sourceBytes) {
		t.Error("target bytes differ from the source DLL")
	}
	if mode := fileMode(t, target); mode != 0o640 {
		t.Errorf("target mode = %#o, want 0640", mode)
	}
	assertDirEntryNames(t, filepath.Dir(target), "nvngx_dlss.dll", "nvngx_dlss.dlsss")

	games := listGames(t, libraryClient)
	if len(games) != 1 {
		t.Fatalf("ListGames returned %d games, want 1", len(games))
	}
	updated := roleDLLs(t, games[0].GetDlls())["nvngx_dlss.dll"]
	if updated.GetCurrentVersion() != testfixtures.VersionUpdate {
		t.Errorf("stored current_version = %q, want %q", updated.GetCurrentVersion(), testfixtures.VersionUpdate)
	}
}

func TestUpdateSkipsUpToDateWithoutBackup(t *testing.T) {
	p := newPaths(t)
	source := testfixtures.NewDLLSource(t)
	source.Add("nvngx_dlss.dll", testfixtures.VersionUpdate)
	p.dllSource = source.Dir()
	startSidecar(t, p)
	updateClient, libraryClient, scanClient, closeClients := updateClients(t, p.socket)
	defer closeClients()

	lib := testfixtures.NewSteamLibrary(t)
	gameDir := lib.AddGame(testfixtures.GameSpec{
		AppID: 2002, Name: "Current Game", InstallDir: "Current Game",
		DLLs: []testfixtures.DLLSpec{{Path: "nvngx_dlss.dll", Version: testfixtures.VersionUpdate}},
	})
	runScan(t, scanClient, lib.Root())

	target := filepath.Join(gameDir, "nvngx_dlss.dll")
	original := readBytes(t, target)
	dll := dllByFilename(t, libraryClient, "nvngx_dlss.dll")

	events := runUpdate(t, updateClient, []string{dll.GetId()})
	item := itemsFinished(t, events)
	if len(item) != 1 {
		t.Fatalf("item_finished events = %d, want 1", len(item))
	}
	requireItemOutcome(t, item[0], dlssv1.UpdateOutcome_UPDATE_OUTCOME_SKIPPED, "UP_TO_DATE")
	if item[0].GetBackupId() != "" {
		t.Errorf("skipped item has backup_id %q", item[0].GetBackupId())
	}
	finished := updateFinished(t, events)
	if finished.GetSucceeded() != 0 || finished.GetSkipped() != 1 || finished.GetFailed() != 0 {
		t.Errorf("finished counts = %d/%d/%d, want 0/1/0",
			finished.GetSucceeded(), finished.GetSkipped(), finished.GetFailed())
	}
	if got := readBytes(t, target); !bytes.Equal(got, original) {
		t.Error("up-to-date target was modified")
	}
	if _, err := os.Stat(backupPathFor(target)); !os.IsNotExist(err) {
		t.Errorf("up-to-date item created a backup: %v", err)
	}
	if got := roleDLLs(t, listGames(t, libraryClient)[0].GetDlls())["nvngx_dlss.dll"].GetCurrentVersion(); got != testfixtures.VersionUpdate {
		t.Errorf("stored current_version = %q, want unchanged %q", got, testfixtures.VersionUpdate)
	}
}

func TestUpdateSkipsDLSSBelowMinimum(t *testing.T) {
	p := newPaths(t)
	source := testfixtures.NewDLLSource(t)
	source.Add("nvngx_dlss.dll", testfixtures.VersionUpdate)
	p.dllSource = source.Dir()
	startSidecar(t, p)
	updateClient, libraryClient, scanClient, closeClients := updateClients(t, p.socket)
	defer closeClients()

	lib := testfixtures.NewSteamLibrary(t)
	gameDir := lib.AddGame(testfixtures.GameSpec{
		AppID: 2003, Name: "Old Game", InstallDir: "Old Game",
		DLLs: []testfixtures.DLLSpec{{Path: "nvngx_dlss.dll", Version: testfixtures.VersionBelowMinimum}},
	})
	runScan(t, scanClient, lib.Root())

	target := filepath.Join(gameDir, "nvngx_dlss.dll")
	original := readBytes(t, target)
	dll := dllByFilename(t, libraryClient, "nvngx_dlss.dll")

	events := runUpdate(t, updateClient, []string{dll.GetId()})
	item := itemsFinished(t, events)
	if len(item) != 1 {
		t.Fatalf("item_finished events = %d, want 1", len(item))
	}
	requireItemOutcome(t, item[0], dlssv1.UpdateOutcome_UPDATE_OUTCOME_SKIPPED, "BELOW_MINIMUM")
	if item[0].GetBackupId() != "" {
		t.Errorf("below-minimum item has backup_id %q", item[0].GetBackupId())
	}
	if got := readBytes(t, target); !bytes.Equal(got, original) {
		t.Error("below-minimum target was modified")
	}
	if _, err := os.Stat(backupPathFor(target)); !os.IsNotExist(err) {
		t.Errorf("below-minimum item created a backup: %v", err)
	}
}

func TestUpdateReportsTargetMissing(t *testing.T) {
	p := newPaths(t)
	source := testfixtures.NewDLLSource(t)
	source.Add("nvngx_dlss.dll", testfixtures.VersionUpdate)
	p.dllSource = source.Dir()
	startSidecar(t, p)
	updateClient, libraryClient, scanClient, closeClients := updateClients(t, p.socket)
	defer closeClients()

	lib := testfixtures.NewSteamLibrary(t)
	gameDir := lib.AddGame(testfixtures.GameSpec{
		AppID: 2004, Name: "Vanished Game", InstallDir: "Vanished Game",
		DLLs: []testfixtures.DLLSpec{{Path: "nvngx_dlss.dll", Version: testfixtures.VersionInstalled}},
	})
	runScan(t, scanClient, lib.Root())
	dll := dllByFilename(t, libraryClient, "nvngx_dlss.dll")
	target := filepath.Join(gameDir, "nvngx_dlss.dll")
	if err := os.Remove(target); err != nil {
		t.Fatalf("remove target: %v", err)
	}

	events := runUpdate(t, updateClient, []string{dll.GetId()})
	item := itemsFinished(t, events)
	if len(item) != 1 {
		t.Fatalf("item_finished events = %d, want 1", len(item))
	}
	requireItemOutcome(t, item[0], dlssv1.UpdateOutcome_UPDATE_OUTCOME_FAILED, "TARGET_MISSING")
	if item[0].GetBackupId() != "" {
		t.Errorf("failed item has backup_id %q", item[0].GetBackupId())
	}
	finished := updateFinished(t, events)
	if finished.GetFailed() != 1 {
		t.Errorf("finished.failed = %d, want 1", finished.GetFailed())
	}
	if _, err := os.Stat(backupPathFor(target)); !os.IsNotExist(err) {
		t.Errorf("missing target produced a backup: %v", err)
	}
}

func TestUpdateReportsSourceMissing(t *testing.T) {
	p := newPaths(t)
	source := testfixtures.NewDLLSource(t)
	p.dllSource = source.Dir()
	startSidecar(t, p)
	updateClient, libraryClient, scanClient, closeClients := updateClients(t, p.socket)
	defer closeClients()

	lib := testfixtures.NewSteamLibrary(t)
	gameDir := lib.AddGame(testfixtures.GameSpec{
		AppID: 2005, Name: "No Source Game", InstallDir: "No Source Game",
		DLLs: []testfixtures.DLLSpec{{Path: "nvngx_dlss.dll", Version: testfixtures.VersionInstalled}},
	})
	runScan(t, scanClient, lib.Root())
	target := filepath.Join(gameDir, "nvngx_dlss.dll")
	original := readBytes(t, target)
	dll := dllByFilename(t, libraryClient, "nvngx_dlss.dll")

	events := runUpdate(t, updateClient, []string{dll.GetId()})
	item := itemsFinished(t, events)
	if len(item) != 1 {
		t.Fatalf("item_finished events = %d, want 1", len(item))
	}
	requireItemOutcome(t, item[0], dlssv1.UpdateOutcome_UPDATE_OUTCOME_FAILED, "SOURCE_MISSING")
	if got := readBytes(t, target); !bytes.Equal(got, original) {
		t.Error("target was modified despite a missing source")
	}
	if _, err := os.Stat(backupPathFor(target)); !os.IsNotExist(err) {
		t.Errorf("missing source produced a backup: %v", err)
	}
}

func TestUpdateReportsPermissionDenied(t *testing.T) {
	if os.Geteuid() == 0 {
		t.Skip("root can write to a read-only directory")
	}
	p := newPaths(t)
	source := testfixtures.NewDLLSource(t)
	source.Add("nvngx_dlss.dll", testfixtures.VersionUpdate)
	p.dllSource = source.Dir()
	startSidecar(t, p)
	updateClient, libraryClient, scanClient, closeClients := updateClients(t, p.socket)
	defer closeClients()

	lib := testfixtures.NewSteamLibrary(t)
	gameDir := lib.AddGame(testfixtures.GameSpec{
		AppID: 2006, Name: "Locked Game", InstallDir: "Locked Game",
		DLLs: []testfixtures.DLLSpec{{Path: "nvngx_dlss.dll", Version: testfixtures.VersionInstalled}},
	})
	runScan(t, scanClient, lib.Root())
	target := filepath.Join(gameDir, "nvngx_dlss.dll")
	original := readBytes(t, target)
	dll := dllByFilename(t, libraryClient, "nvngx_dlss.dll")

	if err := os.Chmod(gameDir, 0o555); err != nil {
		t.Fatalf("make target directory read-only: %v", err)
	}
	t.Cleanup(func() { _ = os.Chmod(gameDir, 0o755) })

	events := runUpdate(t, updateClient, []string{dll.GetId()})
	item := itemsFinished(t, events)
	if len(item) != 1 {
		t.Fatalf("item_finished events = %d, want 1", len(item))
	}
	requireItemOutcome(t, item[0], dlssv1.UpdateOutcome_UPDATE_OUTCOME_FAILED, "PERMISSION_DENIED")
	if got := readBytes(t, target); !bytes.Equal(got, original) {
		t.Error("target was modified despite a read-only directory")
	}
	if _, err := os.Stat(backupPathFor(target)); !os.IsNotExist(err) {
		t.Errorf("permission failure produced a backup: %v", err)
	}
}

func TestUpdateReplacesFileHeldOpen(t *testing.T) {
	p := newPaths(t)
	source := testfixtures.NewDLLSource(t)
	sourcePath := source.Add("nvngx_dlss.dll", testfixtures.VersionUpdate)
	p.dllSource = source.Dir()
	startSidecar(t, p)
	updateClient, libraryClient, scanClient, closeClients := updateClients(t, p.socket)
	defer closeClients()

	lib := testfixtures.NewSteamLibrary(t)
	gameDir := lib.AddGame(testfixtures.GameSpec{
		AppID: 2007, Name: "Running Game", InstallDir: "Running Game",
		DLLs: []testfixtures.DLLSpec{{Path: "nvngx_dlss.dll", Version: testfixtures.VersionInstalled}},
	})
	runScan(t, scanClient, lib.Root())
	target := filepath.Join(gameDir, "nvngx_dlss.dll")
	dll := dllByFilename(t, libraryClient, "nvngx_dlss.dll")

	held, err := os.Open(target)
	if err != nil {
		t.Fatalf("open target: %v", err)
	}
	defer held.Close()
	heldBytes, err := io.ReadAll(held)
	if err != nil {
		t.Fatalf("read held target: %v", err)
	}

	events := runUpdate(t, updateClient, []string{dll.GetId()})
	item := itemsFinished(t, events)
	if len(item) != 1 {
		t.Fatalf("item_finished events = %d, want 1", len(item))
	}
	requireItemOutcome(t, item[0], dlssv1.UpdateOutcome_UPDATE_OUTCOME_UPDATED, "")

	afterHeld, err := io.ReadAll(io.NewSectionReader(held, 0, 1<<30))
	if err != nil {
		t.Fatalf("read held target after update: %v", err)
	}
	if !bytes.Equal(afterHeld, heldBytes) {
		t.Error("open descriptor saw the replacement; the old inode was modified")
	}
	if got, want := readBytes(t, target), readBytes(t, sourcePath); !bytes.Equal(got, want) {
		t.Error("replacement path does not hold the source bytes")
	}
}

func TestUpdateRollsBackOnVersionMismatch(t *testing.T) {
	p := newPaths(t)
	source := testfixtures.NewDLLSource(t)
	source.Add("nvngx_dlss.dll", testfixtures.VersionUpdate)
	p.dllSource = source.Dir()
	startSidecarWithEnv(t, p,
		[]string{"DLSS_TEST_VERSION_MISMATCH=nvngx_dlss.dll"},
		func(t *testing.T) string { return dlssdBinaryTagged(t, "integration") })
	updateClient, libraryClient, scanClient, closeClients := updateClients(t, p.socket)
	defer closeClients()

	lib := testfixtures.NewSteamLibrary(t)
	gameDir := lib.AddGame(testfixtures.GameSpec{
		AppID: 2008, Name: "Mismatch Game", InstallDir: "Mismatch Game",
		DLLs: []testfixtures.DLLSpec{{Path: "nvngx_dlss.dll", Version: testfixtures.VersionInstalled}},
	})
	runScan(t, scanClient, lib.Root())
	target := filepath.Join(gameDir, "nvngx_dlss.dll")
	original := readBytes(t, target)
	dll := dllByFilename(t, libraryClient, "nvngx_dlss.dll")

	events := runUpdate(t, updateClient, []string{dll.GetId()})
	item := itemsFinished(t, events)
	if len(item) != 1 {
		t.Fatalf("item_finished events = %d, want 1", len(item))
	}
	requireItemOutcome(t, item[0], dlssv1.UpdateOutcome_UPDATE_OUTCOME_FAILED, "VERSION_MISMATCH")
	if item[0].GetBackupId() != "" {
		t.Errorf("rolled-back item has backup_id %q", item[0].GetBackupId())
	}
	if got := readBytes(t, target); !bytes.Equal(got, original) {
		t.Error("target was not restored from the backup after the verification failure")
	}
	// The target is back to its original bytes, so the backup file is
	// redundant and must not be left next to it.
	if _, err := os.Stat(backupPathFor(target)); !os.IsNotExist(err) {
		t.Errorf("rollback left a backup file behind: %v", err)
	}
	assertDirEntryNames(t, filepath.Dir(target), "nvngx_dlss.dll")
	if got := roleDLLs(t, listGames(t, libraryClient)[0].GetDlls())["nvngx_dlss.dll"].GetCurrentVersion(); got != testfixtures.VersionInstalled {
		t.Errorf("stored current_version = %q, want unchanged %q", got, testfixtures.VersionInstalled)
	}
}

func TestUpdateCancellationKeepsCompletedItems(t *testing.T) {
	p := newPaths(t)
	source := testfixtures.NewDLLSource(t)
	source.Add("nvngx_dlss.dll", testfixtures.VersionUpdate)
	p.dllSource = source.Dir()
	startSidecar(t, p)
	updateClient, libraryClient, scanClient, closeClients := updateClients(t, p.socket)
	defer closeClients()

	const total = 150
	lib := testfixtures.NewSteamLibrary(t)
	for i := range total {
		lib.AddGame(testfixtures.GameSpec{
			AppID:      uint32(9000 + i),
			Name:       "Cancel Game " + strconv.Itoa(i),
			InstallDir: "Cancel Game " + strconv.Itoa(i),
			DLLs:       []testfixtures.DLLSpec{{Path: "nvngx_dlss.dll", Version: testfixtures.VersionInstalled}},
		})
	}
	runScan(t, scanClient, lib.Root())
	ids := allDLLIDs(t, libraryClient)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	stream, err := updateClient.StartUpdate(ctx, &dlssv1.StartUpdateRequest{DllIds: ids})
	if err != nil {
		t.Fatalf("StartUpdate: %v", err)
	}

	var (
		completed      []*dlssv1.UpdateItemFinished
		finishedEvents int
		finishedCancel bool
	)
	for {
		event, recvErr := stream.Recv()
		if recvErr != nil {
			cancel()
			break
		}
		if item := event.GetItemFinished(); item != nil {
			completed = append(completed, item)
			if item.GetOutcome() == dlssv1.UpdateOutcome_UPDATE_OUTCOME_UPDATED {
				// The server has replaced and persisted this item; stop the
				// remaining ones.
				cancel()
			}
		}
		if event.GetFinished() != nil {
			finishedEvents++
			finishedCancel = event.GetFinished().GetCancelled()
		}
	}
	if len(completed) == 0 {
		t.Fatal("cancelled update emitted no item_finished event")
	}
	if len(completed) >= total {
		t.Fatalf("cancelled update processed all %d items; cancellation had no effect", total)
	}
	if finishedEvents > 1 {
		t.Errorf("finished events = %d, want at most 1", finishedEvents)
	}
	if finishedEvents == 1 && !finishedCancel {
		t.Error("finished.cancelled = false for a cancelled update")
	}

	versions := versionByDLLID(t, libraryClient)
	updated := 0
	for _, item := range completed {
		if item.GetOutcome() != dlssv1.UpdateOutcome_UPDATE_OUTCOME_UPDATED {
			continue
		}
		if got := versions[item.GetDllId()]; got != testfixtures.VersionUpdate {
			t.Errorf("completed item %s persisted version %q, want %q", item.GetDllId(), got, testfixtures.VersionUpdate)
		}
		updated++
	}
	if updated == 0 {
		t.Fatal("cancelled update reported no completed item")
	}
	persisted := 0
	for _, version := range versions {
		if version == testfixtures.VersionUpdate {
			persisted++
		}
	}
	if persisted >= total {
		t.Errorf("cancelled update persisted all %d items", total)
	}
	if persisted < updated {
		t.Errorf("persisted updated items = %d, fewer than emitted %d", persisted, updated)
	}

	waitFor(t, 5*time.Second, "update_running cleared after cancellation", func() bool {
		status, err := probeStatus(p.socket)
		return err == nil && !status.GetUpdateRunning()
	})
}

func TestUpdateConcurrentStartIsRejected(t *testing.T) {
	p := newPaths(t)
	source := testfixtures.NewDLLSource(t)
	source.Add("nvngx_dlss.dll", testfixtures.VersionUpdate)
	p.dllSource = source.Dir()
	startSidecar(t, p)
	updateClient, libraryClient, scanClient, closeClients := updateClients(t, p.socket)
	defer closeClients()

	const total = 250
	lib := testfixtures.NewSteamLibrary(t)
	for i := range total {
		lib.AddGame(testfixtures.GameSpec{
			AppID:      uint32(9500 + i),
			Name:       "Busy Game " + strconv.Itoa(i),
			InstallDir: "Busy Game " + strconv.Itoa(i),
			DLLs:       []testfixtures.DLLSpec{{Path: "nvngx_dlss.dll", Version: testfixtures.VersionInstalled}},
		})
	}
	runScan(t, scanClient, lib.Root())
	ids := allDLLIDs(t, libraryClient)

	firstCtx, cancelFirst := context.WithCancel(context.Background())
	defer cancelFirst()
	first, err := updateClient.StartUpdate(firstCtx, &dlssv1.StartUpdateRequest{DllIds: ids})
	if err != nil {
		t.Fatalf("first StartUpdate: %v", err)
	}
	if _, err := first.Recv(); err != nil {
		t.Fatalf("first update produced no event: %v", err)
	}
	if status, err := probeStatus(p.socket); err != nil {
		t.Fatalf("GetStatus during update: %v", err)
	} else if !status.GetUpdateRunning() {
		t.Error("GetStatus reports update_running=false while an update streams")
	}

	secondCtx, cancelSecond := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancelSecond()
	second, err := updateClient.StartUpdate(secondCtx, &dlssv1.StartUpdateRequest{DllIds: ids[:1]})
	if err == nil {
		_, err = second.Recv()
	}
	requireReason(t, err, contract.ReasonUpdateInProgress, codes.FailedPrecondition)

	cancelFirst()
	for {
		if _, err := first.Recv(); err != nil {
			break
		}
	}
	waitFor(t, 5*time.Second, "update_running cleared after cancellation", func() bool {
		status, err := probeStatus(p.socket)
		return err == nil && !status.GetUpdateRunning()
	})
}

func TestUpdateMixedBatchReportsCountsInRequestOrder(t *testing.T) {
	p := newPaths(t)
	source := testfixtures.NewDLLSource(t)
	source.Add("nvngx_dlss.dll", testfixtures.VersionUpdate)
	source.Add("libxess.dll", testfixtures.VersionUpdate)
	p.dllSource = source.Dir()
	startSidecar(t, p)
	updateClient, libraryClient, scanClient, closeClients := updateClients(t, p.socket)
	defer closeClients()

	lib := testfixtures.NewSteamLibrary(t)
	gameDir := lib.AddGame(testfixtures.GameSpec{
		AppID: 2100, Name: "Mixed Game", InstallDir: "Mixed Game",
		DLLs: []testfixtures.DLLSpec{
			{Path: "bin/nvngx_dlss.dll", Version: testfixtures.VersionInstalled},
			{Path: "bin/libxess.dll", Version: testfixtures.VersionUpdate},
			{Path: "bin/sl.reflex.dll", Version: testfixtures.VersionInstalled},
			{Path: "bin/nvngx_dlssg.dll", Version: testfixtures.VersionInstalled},
		},
	})
	runScan(t, scanClient, lib.Root())
	byName := roleDLLs(t, listGames(t, libraryClient)[0].GetDlls())
	if err := os.Remove(filepath.Join(gameDir, "bin", "nvngx_dlssg.dll")); err != nil {
		t.Fatalf("remove dlssg target: %v", err)
	}

	ids := []string{
		byName["nvngx_dlss.dll"].GetId(),
		byName["libxess.dll"].GetId(),
		byName["sl.reflex.dll"].GetId(),
		byName["nvngx_dlssg.dll"].GetId(),
	}
	events := runUpdate(t, updateClient, ids)
	items := itemsFinished(t, events)
	if len(items) != len(ids) {
		t.Fatalf("item_finished events = %d, want %d (%v)", len(items), len(ids), describeUpdateEvents(events))
	}
	for i, item := range items {
		if item.GetDllId() != ids[i] {
			t.Errorf("item %d dll_id = %q, want %q (request order)", i, item.GetDllId(), ids[i])
		}
	}
	requireItemOutcome(t, items[0], dlssv1.UpdateOutcome_UPDATE_OUTCOME_UPDATED, "")
	requireItemOutcome(t, items[1], dlssv1.UpdateOutcome_UPDATE_OUTCOME_SKIPPED, "UP_TO_DATE")
	requireItemOutcome(t, items[2], dlssv1.UpdateOutcome_UPDATE_OUTCOME_FAILED, "SOURCE_MISSING")
	requireItemOutcome(t, items[3], dlssv1.UpdateOutcome_UPDATE_OUTCOME_FAILED, "TARGET_MISSING")

	startedSeen := 0
	for _, event := range events {
		started := event.GetItemStarted()
		if started == nil {
			continue
		}
		startedSeen++
		if started.GetIndex() != int32(startedSeen) || started.GetTotal() != int32(len(ids)) {
			t.Errorf("item_started index/total = %d/%d, want %d/%d",
				started.GetIndex(), started.GetTotal(), startedSeen, len(ids))
		}
	}
	if startedSeen != len(ids) {
		t.Errorf("item_started events = %d, want %d", startedSeen, len(ids))
	}

	finished := updateFinished(t, events)
	if finished.GetSucceeded() != 1 || finished.GetSkipped() != 1 || finished.GetFailed() != 2 {
		t.Errorf("finished counts = %d/%d/%d, want 1/1/2",
			finished.GetSucceeded(), finished.GetSkipped(), finished.GetFailed())
	}
	// Only the replaced DLL got a backup beside it.
	dir := filepath.Join(gameDir, "bin")
	assertDirEntryNames(t, dir, "libxess.dll", "nvngx_dlss.dll", "nvngx_dlss.dlsss", "sl.reflex.dll")
	if _, err := os.Stat(filepath.Join(dir, "nvngx_dlssg.dll")); !os.IsNotExist(err) {
		t.Errorf("missing target unexpectedly exists: %v", err)
	}
}

func TestUpdateEmptyRequestFinishesImmediately(t *testing.T) {
	p := newPaths(t)
	startSidecar(t, p)
	updateClient, _, _, closeClients := updateClients(t, p.socket)
	defer closeClients()

	events, err := collectUpdate(beginUpdate(t, updateClient, nil))
	if err != nil {
		t.Fatalf("update stream: %v", err)
	}
	if len(events) != 2 {
		t.Fatalf("events = %v, want started/finished", describeUpdateEvents(events))
	}
	started := events[0].GetStarted()
	if started == nil || started.GetItemCount() != 0 {
		t.Fatalf("started = %v, want item_count 0", describeUpdateEvents(events))
	}
	finished := updateFinished(t, events)
	if finished.GetSucceeded() != 0 || finished.GetSkipped() != 0 || finished.GetFailed() != 0 {
		t.Errorf("finished counts = %d/%d/%d, want 0/0/0",
			finished.GetSucceeded(), finished.GetSkipped(), finished.GetFailed())
	}
}
