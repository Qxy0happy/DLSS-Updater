//go:build integration

package integration

import (
	"context"
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
	"google.golang.org/grpc/status"

	dlssv1 "github.com/Qxy0happy/DLSS-Updater/backend/gen/dlss/v1"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/contract"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/testfixtures"
)

// scanClients opens one channel for both services the scan tests drive.
func scanClients(t *testing.T, socket string) (dlssv1.ScanClient, dlssv1.LibraryClient, func()) {
	t.Helper()
	conn, err := grpc.NewClient("unix://"+socket, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		t.Fatalf("grpc.NewClient(%s): %v", socket, err)
	}
	return dlssv1.NewScanClient(conn), dlssv1.NewLibraryClient(conn), func() { _ = conn.Close() }
}

func collectScan(t *testing.T, stream dlssv1.Scan_StartScanClient) []*dlssv1.ScanEvent {
	t.Helper()
	var events []*dlssv1.ScanEvent
	for {
		event, err := stream.Recv()
		if errors.Is(err, io.EOF) {
			return events
		}
		if err != nil {
			t.Fatalf("scan stream: %v", err)
		}
		events = append(events, event)
	}
}

func runScan(t *testing.T, client dlssv1.ScanClient, root string) []*dlssv1.ScanEvent {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	stream, err := client.StartScan(ctx, &dlssv1.StartScanRequest{SteamRoot: root})
	if err != nil {
		t.Fatalf("StartScan: %v", err)
	}
	return collectScan(t, stream)
}

// finishSummary asserts the stream carried no failed event and exactly one
// finished event, and returns it.
func finishSummary(t *testing.T, events []*dlssv1.ScanEvent) *dlssv1.ScanFinished {
	t.Helper()
	var (
		finished []*dlssv1.ScanFinished
		previous *dlssv1.ScanLibraryProgress
	)
	for _, event := range events {
		if failed := event.GetFailed(); failed != nil {
			t.Fatalf("scan failed: reason=%s message=%s", failed.GetReason(), failed.GetMessage())
		}
		if progress := event.GetLibraryProgress(); progress != nil {
			if sameProgress(previous, progress) {
				t.Errorf("scan emitted consecutive identical library_progress events: %v",
					progress)
			}
			previous = progress
		}
		if event.GetFinished() != nil {
			finished = append(finished, event.GetFinished())
		}
	}
	if len(finished) != 1 {
		t.Fatalf("finished events = %d, want exactly 1 (events: %v)", len(finished), describeEvents(events))
	}
	return finished[0]
}

func describeEvents(events []*dlssv1.ScanEvent) []string {
	out := make([]string, 0, len(events))
	for _, event := range events {
		switch {
		case event.GetStarted() != nil:
			out = append(out, "started")
		case event.GetLibraryProgress() != nil:
			out = append(out, "library_progress")
		case event.GetGameFound() != nil:
			out = append(out, "game_found:"+event.GetGameFound().GetName())
		case event.GetWarning() != nil:
			out = append(out, "warning:"+event.GetWarning().GetPath())
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

func listGames(t *testing.T, client dlssv1.LibraryClient) []*dlssv1.Game {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	resp, err := client.ListGames(ctx, &dlssv1.ListGamesRequest{})
	if err != nil {
		t.Fatalf("ListGames: %v", err)
	}
	return resp.GetGames()
}

func getGame(t *testing.T, client dlssv1.LibraryClient, id string) *dlssv1.Game {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	game, err := client.GetGame(ctx, &dlssv1.GetGameRequest{GameId: id})
	if err != nil {
		t.Fatalf("GetGame(%q): %v", id, err)
	}
	return game
}

func requireReason(t *testing.T, err error, want contract.Reason, wantCode codes.Code) {
	t.Helper()
	if err == nil {
		t.Fatalf("error = nil, want reason %s", want)
	}
	st, _ := status.FromError(err)
	if got := st.Code(); got != wantCode {
		t.Errorf("status code = %v, want %v (error: %v)", got, wantCode, err)
	}
	detail, ok := contract.FromError(err)
	if !ok {
		t.Fatalf("status has no dlss.v1 ErrorInfo: %v", err)
	}
	if detail.Reason != want {
		t.Errorf("reason = %s, want %s", detail.Reason, want)
	}
}

func roleDLLs(t *testing.T, dlls []*dlssv1.GameDLL) map[string]*dlssv1.GameDLL {
	t.Helper()
	byFilename := map[string]*dlssv1.GameDLL{}
	for _, dll := range dlls {
		byFilename[strings.ToLower(dll.GetFilename())] = dll
	}
	return byFilename
}

func TestScanEnumeratesRecursiveDLLsAndPersists(t *testing.T) {
	p := newPaths(t)
	startSidecar(t, p)
	scanClient, libraryClient, closeClients := scanClients(t, p.socket)
	defer closeClients()

	lib := testfixtures.NewSteamLibrary(t)
	gameDir := lib.AddGame(testfixtures.GameSpec{
		AppID:      4001,
		Name:       "Nested Game",
		InstallDir: "Nested Game",
		DLLs: []testfixtures.DLLSpec{
			{Path: "bin/x64/nvngx_dlss.dll", Version: testfixtures.VersionInstalled},
			{Path: "NVNGX_DLSSG.DLL", Version: testfixtures.VersionUpdate},
			// The old application's skip set keeps this out of the result.
			{Path: "logs/nvngx_dlssd.dll", Version: testfixtures.VersionInstalled},
			// Not part of the known catalog.
			{Path: "bin/unrelated.dll", Version: testfixtures.VersionInstalled},
		},
	})

	events := runScan(t, scanClient, lib.Root())
	finished := finishSummary(t, events)
	if finished.GetCancelled() {
		t.Error("finished.cancelled = true, want false")
	}
	if got, want := finished.GetGameCount(), int32(1); got != want {
		t.Errorf("finished.game_count = %d, want %d", got, want)
	}
	if got, want := finished.GetDllCount(), int32(2); got != want {
		t.Errorf("finished.dll_count = %d, want %d", got, want)
	}

	started := events[0].GetStarted()
	if started == nil {
		t.Fatalf("first event = %v, want started", describeEvents(events)[:1])
	}
	if started.GetSteamRoot() != lib.Root() {
		t.Errorf("started.steam_root = %q, want %q", started.GetSteamRoot(), lib.Root())
	}
	if started.GetStartedAt() == nil {
		t.Error("started.started_at is missing")
	}

	var (
		libraryEvents int
		lastGames     int32
		lastDLLs      int32
		gameFound     int
	)
	for _, event := range events {
		progress := event.GetLibraryProgress()
		if progress == nil {
			continue
		}
		libraryEvents++
		if progress.GetLibraryIndex() < 1 || progress.GetLibraryIndex() > progress.GetLibraryCount() {
			t.Errorf("library index %d outside 1..%d", progress.GetLibraryIndex(), progress.GetLibraryCount())
		}
		if progress.GetLibraryCount() != 1 {
			t.Errorf("library_count = %d, want 1", progress.GetLibraryCount())
		}
		if progress.GetGamesFound() < lastGames || progress.GetDllsFound() < lastDLLs {
			t.Errorf("progress counters went backwards: (%d,%d) after (%d,%d)",
				progress.GetGamesFound(), progress.GetDllsFound(), lastGames, lastDLLs)
		}
		lastGames, lastDLLs = progress.GetGamesFound(), progress.GetDllsFound()
	}
	for _, event := range events {
		if event.GetGameFound() != nil {
			gameFound++
		}
	}
	if libraryEvents == 0 {
		t.Error("scan emitted no library_progress events")
	}
	if gameFound != int(finished.GetGameCount()) {
		t.Errorf("game_found events = %d, want %d", gameFound, finished.GetGameCount())
	}
	if lastGames != finished.GetGameCount() || lastDLLs != finished.GetDllCount() {
		t.Errorf("last progress = (%d,%d), finished = (%d,%d)",
			lastGames, lastDLLs, finished.GetGameCount(), finished.GetDllCount())
	}

	games := listGames(t, libraryClient)
	if len(games) != 1 {
		t.Fatalf("ListGames returned %d games, want 1", len(games))
	}
	game := games[0]
	if game.GetAppId() != 4001 || game.GetName() != "Nested Game" {
		t.Errorf("game = app_id %d name %q", game.GetAppId(), game.GetName())
	}
	if game.GetInstallPath() != gameDir || game.GetLibraryPath() != lib.Root() {
		t.Errorf("paths = install %q library %q, want %q / %q",
			game.GetInstallPath(), game.GetLibraryPath(), gameDir, lib.Root())
	}
	if len(game.GetDlls()) != 2 {
		t.Fatalf("DLL count = %d (%v), want 2", len(game.GetDlls()), roleDLLs(t, game.GetDlls()))
	}
	byName := roleDLLs(t, game.GetDlls())
	dlss := byName["nvngx_dlss.dll"]
	if dlss == nil {
		t.Fatal("nvngx_dlss.dll missing from result")
	}
	if dlss.GetDllType() != "dlss" || !dlss.GetExists() {
		t.Errorf("dlss = type %q exists %v", dlss.GetDllType(), dlss.GetExists())
	}
	if dlss.GetCurrentVersion() != testfixtures.VersionInstalled {
		t.Errorf("dlss current_version = %q, want %q", dlss.GetCurrentVersion(), testfixtures.VersionInstalled)
	}
	if dlss.GetMissingAt() != nil {
		t.Error("fresh DLL has missing_at")
	}
	if dlss.GetSourceVersion() != "" {
		t.Errorf("scan result source_version = %q, want empty", dlss.GetSourceVersion())
	}
	if got := byName["nvngx_dlssg.dll"]; got == nil || got.GetDllType() != "dlss_g" {
		t.Errorf("case-insensitive match failed: %v", byName)
	}
	if _, ok := byName["nvngx_dlssd.dll"]; ok {
		t.Error("DLL from a skipped directory was reported")
	}
	if _, ok := byName["unrelated.dll"]; ok {
		t.Error("unknown DLL was reported")
	}
	for _, reported := range games {
		if !strings.HasPrefix(reported.GetInstallPath(), lib.TempRoot()) {
			t.Errorf("install path %q escaped the fixture root %q", reported.GetInstallPath(), lib.TempRoot())
		}
		for _, dll := range reported.GetDlls() {
			if !strings.HasPrefix(dll.GetPath(), lib.TempRoot()) {
				t.Errorf("DLL path %q escaped the fixture root %q", dll.GetPath(), lib.TempRoot())
			}
		}
	}

	detailed := getGame(t, libraryClient, game.GetId())
	if detailed.GetId() != game.GetId() || len(detailed.GetDlls()) != 2 {
		t.Errorf("GetGame(%q) = id %q with %d DLLs", game.GetId(), detailed.GetId(), len(detailed.GetDlls()))
	}
}

func TestScanMultipleLibraries(t *testing.T) {
	p := newPaths(t)
	startSidecar(t, p)
	scanClient, libraryClient, closeClients := scanClients(t, p.socket)
	defer closeClients()

	lib := testfixtures.NewSteamLibrary(t)
	second := lib.AddLibraryRoot("second-library")
	lib.AddGame(testfixtures.GameSpec{
		AppID: 100, Name: "Primary Game", InstallDir: "Primary Game",
		DLLs: []testfixtures.DLLSpec{{Path: "nvngx_dlss.dll", Version: testfixtures.VersionInstalled}},
	})
	lib.AddGameTo(second, testfixtures.GameSpec{
		AppID: 200, Name: "Second Game", InstallDir: "Second Game",
		DLLs: []testfixtures.DLLSpec{{Path: "libxess.dll", Version: testfixtures.VersionUpdate}},
	})

	events := runScan(t, scanClient, lib.Root())
	finished := finishSummary(t, events)
	if finished.GetGameCount() != 2 || finished.GetDllCount() != 2 {
		t.Errorf("finished = %d games / %d DLLs, want 2 / 2", finished.GetGameCount(), finished.GetDllCount())
	}

	libraryPaths := map[string]bool{}
	for _, event := range events {
		progress := event.GetLibraryProgress()
		if progress == nil {
			continue
		}
		if progress.GetLibraryCount() != 2 {
			t.Errorf("library_count = %d, want 2", progress.GetLibraryCount())
		}
		libraryPaths[progress.GetLibraryPath()] = true
	}
	if !libraryPaths[lib.Root()] || !libraryPaths[second] {
		t.Errorf("progress libraries = %v, want %q and %q", libraryPaths, lib.Root(), second)
	}

	games := listGames(t, libraryClient)
	if len(games) != 2 {
		t.Fatalf("ListGames returned %d games, want 2", len(games))
	}
	names := map[string]bool{}
	for _, game := range games {
		names[game.GetName()] = true
	}
	if !names["Primary Game"] || !names["Second Game"] {
		t.Errorf("game names = %v", names)
	}
}

func TestScanFallsBackToSteamAppsCommon(t *testing.T) {
	p := newPaths(t)
	startSidecar(t, p)
	scanClient, libraryClient, closeClients := scanClients(t, p.socket)
	defer closeClients()

	lib := testfixtures.NewSteamLibrary(t)
	lib.AddGame(testfixtures.GameSpec{
		AppID: 300, Name: "Fallback Game", InstallDir: "Fallback Game",
		DLLs: []testfixtures.DLLSpec{{Path: "sl.reflex.dll", Version: testfixtures.VersionInstalled}},
	})
	lib.RemoveLibraryFolders()

	events := runScan(t, scanClient, lib.Root())
	finished := finishSummary(t, events)
	if finished.GetGameCount() != 1 || finished.GetDllCount() != 1 {
		t.Errorf("finished = %d games / %d DLLs, want 1 / 1", finished.GetGameCount(), finished.GetDllCount())
	}
	games := listGames(t, libraryClient)
	if len(games) != 1 || games[0].GetName() != "Fallback Game" {
		t.Fatalf("games = %v, want the fallback game", games)
	}
}

func TestScanCollapsesSymlinkedAndDuplicateLibraries(t *testing.T) {
	p := newPaths(t)
	startSidecar(t, p)
	scanClient, libraryClient, closeClients := scanClients(t, p.socket)
	defer closeClients()

	lib := testfixtures.NewSteamLibrary(t)
	link, real := lib.AddSymlinkedLibraryRoot("linked-library")
	lib.AddGameTo(real, testfixtures.GameSpec{
		AppID: 500, Name: "Linked Game", InstallDir: "Linked Game",
		DLLs: []testfixtures.DLLSpec{{Path: "bin/nvngx_dlss.dll", Version: testfixtures.VersionInstalled}},
	})
	// The real directory is now listed twice: once through the symlink and
	// once literally. Resolution must collapse them into one library and one
	// game.
	lib.AddLibraryRoot(filepath.Base(real))

	events := runScan(t, scanClient, lib.Root())
	finished := finishSummary(t, events)
	if finished.GetGameCount() != 1 || finished.GetDllCount() != 1 {
		t.Errorf("finished = %d games / %d DLLs, want 1 / 1", finished.GetGameCount(), finished.GetDllCount())
	}
	for _, event := range events {
		progress := event.GetLibraryProgress()
		if progress != nil && progress.GetLibraryCount() != 2 {
			t.Errorf("library_count = %d, want 2 after deduplication", progress.GetLibraryCount())
		}
	}
	games := listGames(t, libraryClient)
	if len(games) != 1 {
		t.Fatalf("ListGames returned %d games, want 1: %v", len(games), games)
	}
	if !strings.HasPrefix(games[0].GetInstallPath(), link) {
		t.Errorf("install path = %q, want it under the symlinked library %q", games[0].GetInstallPath(), link)
	}
}

func TestScanEmptyLibrarySucceeds(t *testing.T) {
	p := newPaths(t)
	startSidecar(t, p)
	scanClient, libraryClient, closeClients := scanClients(t, p.socket)
	defer closeClients()

	lib := testfixtures.NewSteamLibrary(t)
	events := runScan(t, scanClient, lib.Root())
	finished := finishSummary(t, events)
	if finished.GetGameCount() != 0 || finished.GetDllCount() != 0 {
		t.Errorf("finished = %d games / %d DLLs, want 0 / 0", finished.GetGameCount(), finished.GetDllCount())
	}
	if games := listGames(t, libraryClient); len(games) != 0 {
		t.Errorf("ListGames returned %v, want no games", games)
	}
}

func TestScanWarnsAboutMissingAndUnreadableGameDirectories(t *testing.T) {
	p := newPaths(t)
	startSidecar(t, p)
	scanClient, libraryClient, closeClients := scanClients(t, p.socket)
	defer closeClients()

	lib := testfixtures.NewSteamLibrary(t)
	good := lib.AddGame(testfixtures.GameSpec{
		AppID: 600, Name: "Good Game", InstallDir: "Good Game",
		DLLs: []testfixtures.DLLSpec{{Path: "nvngx_dlss.dll", Version: testfixtures.VersionInstalled}},
	})
	missing := lib.AddMissingInstallDir(testfixtures.GameSpec{
		AppID: 601, Name: "Gone Game", InstallDir: "Gone Game",
	})
	unreadable, unreadableChecked := lib.AddUnreadableGame(testfixtures.GameSpec{
		AppID: 602, Name: "Locked Game", InstallDir: "Locked Game",
		DLLs: []testfixtures.DLLSpec{{Path: "nvngx_dlss.dll", Version: testfixtures.VersionInstalled}},
	})

	events := runScan(t, scanClient, lib.Root())
	finished := finishSummary(t, events)
	if finished.GetGameCount() != 1 {
		t.Errorf("finished.game_count = %d, want 1", finished.GetGameCount())
	}

	warnings := map[string]string{}
	for _, event := range events {
		if w := event.GetWarning(); w != nil {
			warnings[w.GetPath()] = w.GetMessage()
		}
	}
	if _, ok := warnings[missing]; !ok {
		t.Errorf("no warning for missing game dir %q (warnings: %v)", missing, warnings)
	}
	if unreadableChecked {
		if _, ok := warnings[unreadable]; !ok {
			t.Errorf("no warning for unreadable game dir %q (warnings: %v)", unreadable, warnings)
		}
	}

	games := listGames(t, libraryClient)
	if len(games) != 1 || games[0].GetName() != "Good Game" {
		t.Fatalf("games = %v, want only Good Game", games)
	}
	if games[0].GetInstallPath() != good {
		t.Errorf("good install path = %q, want %q", games[0].GetInstallPath(), good)
	}
}

func TestScanInvalidRoot(t *testing.T) {
	p := newPaths(t)
	startSidecar(t, p)
	scanClient, _, closeClients := scanClients(t, p.socket)
	defer closeClients()

	tests := []struct {
		name string
		root string
	}{
		{"missing", filepath.Join(t.TempDir(), "no-steam-here")},
		{"relative", "relative/steam"},
		{"regular file", func() string {
			path := filepath.Join(t.TempDir(), "steam-file")
			if err := os.WriteFile(path, []byte("not a directory"), 0o600); err != nil {
				t.Fatalf("write root file: %v", err)
			}
			return path
		}()},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			defer cancel()
			stream, err := scanClient.StartScan(ctx, &dlssv1.StartScanRequest{SteamRoot: tt.root})
			if err != nil {
				// The stream may surface the error on the first Recv instead.
				requireReason(t, err, contract.ReasonScanRootInvalid, codes.InvalidArgument)
				return
			}
			event, recvErr := stream.Recv()
			if recvErr == nil {
				failed := event.GetFailed()
				if failed == nil {
					t.Fatalf("first event = %v, want failed", describeEvents([]*dlssv1.ScanEvent{event}))
				}
				if failed.GetReason() != string(contract.ReasonScanRootInvalid) {
					t.Errorf("failed.reason = %q, want SCAN_ROOT_INVALID", failed.GetReason())
				}
				return
			}
			requireReason(t, recvErr, contract.ReasonScanRootInvalid, codes.InvalidArgument)
		})
	}
}

func TestScanUnreadableRootIsRejected(t *testing.T) {
	if os.Geteuid() == 0 {
		t.Skip("root can read a mode-000 directory")
	}
	p := newPaths(t)
	startSidecar(t, p)
	scanClient, _, closeClients := scanClients(t, p.socket)
	defer closeClients()

	root := t.TempDir()
	if err := os.Chmod(root, 0); err != nil {
		t.Fatalf("make root unreadable: %v", err)
	}
	t.Cleanup(func() { _ = os.Chmod(root, 0o700) })

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	stream, err := scanClient.StartScan(ctx, &dlssv1.StartScanRequest{SteamRoot: root})
	if err == nil {
		var event *dlssv1.ScanEvent
		event, err = stream.Recv()
		if err == nil {
			failed := event.GetFailed()
			if failed == nil {
				t.Fatalf("first event = %v, want failed", describeEvents([]*dlssv1.ScanEvent{event}))
			}
			if failed.GetReason() != string(contract.ReasonScanRootInvalid) {
				t.Errorf("failed.reason = %q, want SCAN_ROOT_INVALID", failed.GetReason())
			}
			return
		}
	}
	requireReason(t, err, contract.ReasonScanRootInvalid, codes.InvalidArgument)
}

func TestScanConcurrentStartIsRejected(t *testing.T) {
	p := newPaths(t)
	startSidecar(t, p)
	scanClient, _, closeClients := scanClients(t, p.socket)
	defer closeClients()

	lib := testfixtures.NewSteamLibrary(t)
	for i := range 200 {
		lib.AddGame(testfixtures.GameSpec{
			AppID:      uint32(7000 + i),
			Name:       "Game " + strconv.Itoa(i),
			InstallDir: "Game " + strconv.Itoa(i),
			DLLs: []testfixtures.DLLSpec{
				{Path: "bin/nvngx_dlss.dll", Version: testfixtures.VersionInstalled},
			},
		})
	}

	firstCtx, cancelFirst := context.WithCancel(context.Background())
	defer cancelFirst()
	first, err := scanClient.StartScan(firstCtx, &dlssv1.StartScanRequest{SteamRoot: lib.Root()})
	if err != nil {
		t.Fatalf("first StartScan: %v", err)
	}
	if _, err := first.Recv(); err != nil {
		t.Fatalf("first scan produced no event: %v", err)
	}
	if status, err := probeStatus(p.socket); err != nil {
		t.Fatalf("GetStatus during scan: %v", err)
	} else if !status.GetScanRunning() {
		t.Error("GetStatus reports scan_running=false while a scan streams")
	}

	secondCtx, cancelSecond := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancelSecond()
	second, err := scanClient.StartScan(secondCtx, &dlssv1.StartScanRequest{SteamRoot: lib.Root()})
	if err == nil {
		_, err = second.Recv()
	}
	requireReason(t, err, contract.ReasonScanInProgress, codes.FailedPrecondition)

	cancelFirst()
	for {
		if _, err := first.Recv(); err != nil {
			break
		}
	}
	waitFor(t, 3*time.Second, "scan_running cleared after cancellation", func() bool {
		status, err := probeStatus(p.socket)
		return err == nil && !status.GetScanRunning()
	})
}

func TestScanCancellationKeepsPersistedGames(t *testing.T) {
	p := newPaths(t)
	startSidecar(t, p)
	scanClient, libraryClient, closeClients := scanClients(t, p.socket)
	defer closeClients()

	const total = 300
	lib := testfixtures.NewSteamLibrary(t)
	for i := range total {
		lib.AddGame(testfixtures.GameSpec{
			AppID:      uint32(8000 + i),
			Name:       "Scan Game " + strconv.Itoa(i),
			InstallDir: "Scan Game " + strconv.Itoa(i),
			DLLs: []testfixtures.DLLSpec{
				{Path: "nvngx_dlss.dll", Version: testfixtures.VersionInstalled},
			},
		})
	}

	ctx, cancel := context.WithCancel(context.Background())
	stream, err := scanClient.StartScan(ctx, &dlssv1.StartScanRequest{SteamRoot: lib.Root()})
	if err != nil {
		cancel()
		t.Fatalf("StartScan: %v", err)
	}

	var (
		finishedEvents int
		finishedCancel bool
		sawGame        bool
	)
	for {
		event, recvErr := stream.Recv()
		if recvErr != nil {
			if !sawGame {
				cancel()
				t.Fatalf("stream ended before any game was found: %v", recvErr)
			}
			cancel()
			break
		}
		if event.GetGameFound() != nil && !sawGame {
			sawGame = true
			// Cancel immediately: the server has persisted at least one game
			// and must keep it.
			cancel()
		}
		if event.GetFinished() != nil {
			finishedEvents++
			finishedCancel = event.GetFinished().GetCancelled()
		}
	}
	// gRPC tears the stream down before the server can deliver its summary;
	// zero or one finished event is the honest observable outcome.
	if finishedEvents > 1 {
		t.Errorf("finished events = %d, want at most 1", finishedEvents)
	}
	if finishedEvents == 1 && !finishedCancel {
		t.Error("finished.cancelled = false for a cancelled scan")
	}

	games := listGames(t, libraryClient)
	if len(games) == 0 {
		t.Fatal("cancelled scan lost every persisted game")
	}
	if len(games) >= total {
		t.Errorf("cancelled scan persisted all %d games; cancellation had no effect", total)
	}
}

func TestLibraryResolvesSourceVersions(t *testing.T) {
	p := newPaths(t)
	source := testfixtures.NewDLLSource(t)
	source.Add("NVNGX_DLSS.dll", testfixtures.VersionUpdate)
	p.dllSource = source.Dir()
	startSidecar(t, p)
	scanClient, libraryClient, closeClients := scanClients(t, p.socket)
	defer closeClients()

	lib := testfixtures.NewSteamLibrary(t)
	lib.AddGame(testfixtures.GameSpec{
		AppID: 900, Name: "Source Game", InstallDir: "Source Game",
		DLLs: []testfixtures.DLLSpec{
			{Path: "bin/nvngx_dlss.dll", Version: testfixtures.VersionInstalled},
			{Path: "bin/libxess.dll", Version: testfixtures.VersionInstalled},
		},
	})
	runScan(t, scanClient, lib.Root())

	games := listGames(t, libraryClient)
	if len(games) != 1 {
		t.Fatalf("ListGames returned %d games, want 1", len(games))
	}
	byName := roleDLLs(t, games[0].GetDlls())
	dlss := byName["nvngx_dlss.dll"]
	if dlss == nil {
		t.Fatal("dlss row missing")
	}
	if dlss.GetCurrentVersion() != testfixtures.VersionInstalled {
		t.Errorf("current_version = %q, want %q", dlss.GetCurrentVersion(), testfixtures.VersionInstalled)
	}
	if dlss.GetSourceVersion() != testfixtures.VersionUpdate {
		t.Errorf("source_version = %q, want %q", dlss.GetSourceVersion(), testfixtures.VersionUpdate)
	}
	if xess := byName["libxess.dll"]; xess == nil || xess.GetSourceVersion() != "" {
		t.Errorf("libxess source_version should stay empty: %v", xess)
	}

	detailed := getGame(t, libraryClient, games[0].GetId())
	detailedByName := roleDLLs(t, detailed.GetDlls())
	if got := detailedByName["nvngx_dlss.dll"].GetSourceVersion(); got != testfixtures.VersionUpdate {
		t.Errorf("GetGame source_version = %q, want %q", got, testfixtures.VersionUpdate)
	}

	for _, id := range []string{"999999", "not-a-number"} {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		_, err := libraryClient.GetGame(ctx, &dlssv1.GetGameRequest{GameId: id})
		cancel()
		requireReason(t, err, contract.ReasonTargetMissing, codes.NotFound)
	}
}

func TestRescanMarksAndClearsMissingDLLs(t *testing.T) {
	p := newPaths(t)
	startSidecar(t, p)
	scanClient, libraryClient, closeClients := scanClients(t, p.socket)
	defer closeClients()

	lib := testfixtures.NewSteamLibrary(t)
	gameDir := lib.AddGame(testfixtures.GameSpec{
		AppID: 1000, Name: "Rescan Game", InstallDir: "Rescan Game",
		DLLs: []testfixtures.DLLSpec{
			{Path: "bin/nvngx_dlss.dll", Version: testfixtures.VersionInstalled},
			{Path: "bin/libxess.dll", Version: testfixtures.VersionInstalled},
		},
	})
	runScan(t, scanClient, lib.Root())
	games := listGames(t, libraryClient)
	if len(games) != 1 {
		t.Fatalf("ListGames returned %d games, want 1", len(games))
	}
	gameID := games[0].GetId()

	target := filepath.Join(gameDir, "bin", "nvngx_dlss.dll")
	if err := os.Remove(target); err != nil {
		t.Fatalf("remove target DLL: %v", err)
	}
	runScan(t, scanClient, lib.Root())

	detailed := getGame(t, libraryClient, gameID)
	byName := roleDLLs(t, detailed.GetDlls())
	dlss := byName["nvngx_dlss.dll"]
	if dlss == nil {
		t.Fatal("missing DLL row disappeared")
	}
	if dlss.GetMissingAt() == nil {
		t.Error("removed DLL has no missing_at")
	}
	if dlss.GetExists() {
		t.Error("removed DLL reports exists=true")
	}
	if xess := byName["libxess.dll"]; xess == nil || xess.GetMissingAt() != nil {
		t.Errorf("untouched DLL missing_at = %v, want nil", xess.GetMissingAt())
	}

	testfixtures.WritePE(t, filepath.Dir(target), filepath.Base(target), testfixtures.PEOptions{Version: testfixtures.VersionInstalled})
	runScan(t, scanClient, lib.Root())

	detailed = getGame(t, libraryClient, gameID)
	dlss = roleDLLs(t, detailed.GetDlls())["nvngx_dlss.dll"]
	if dlss == nil {
		t.Fatal("rediscovered DLL row disappeared")
	}
	if dlss.GetMissingAt() != nil {
		t.Error("rediscovered DLL still has missing_at")
	}
	if !dlss.GetExists() {
		t.Error("rediscovered DLL reports exists=false")
	}
}

// sameProgress compares the user-visible fields of two progress events.
func sameProgress(a, b *dlssv1.ScanLibraryProgress) bool {
	if a == nil || b == nil {
		return false
	}
	return a.GetLibraryPath() == b.GetLibraryPath() &&
		a.GetLibraryIndex() == b.GetLibraryIndex() &&
		a.GetLibraryCount() == b.GetLibraryCount() &&
		a.GetCurrentGame() == b.GetCurrentGame() &&
		a.GetGamesFound() == b.GetGamesFound() &&
		a.GetDllsFound() == b.GetDllsFound()
}
