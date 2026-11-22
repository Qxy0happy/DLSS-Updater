//go:build integration

package integration

import (
	"database/sql"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	_ "modernc.org/sqlite"

	dlssv1 "github.com/Qxy0happy/DLSS-Updater/backend/gen/dlss/v1"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/testfixtures"
)

func heroicSource() *dlssv1.ScanSource {
	return &dlssv1.ScanSource{Source: &dlssv1.ScanSource_Heroic{
		Heroic: &dlssv1.HeroicSource{},
	}}
}

func lutrisSource() *dlssv1.ScanSource {
	return &dlssv1.ScanSource{Source: &dlssv1.ScanSource_Lutris{
		Lutris: &dlssv1.LutrisSource{},
	}}
}

func launcherEnv(home string) []string {
	return []string{
		"HOME=" + home,
		"XDG_CONFIG_HOME=" + filepath.Join(home, ".config"),
		"XDG_DATA_HOME=" + filepath.Join(home, ".local", "share"),
	}
}

func writeJSONFile(t *testing.T, path string, value any) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		t.Fatalf("create JSON directory: %v", err)
	}
	data, err := json.MarshalIndent(value, "", "  ")
	if err != nil {
		t.Fatalf("marshal JSON: %v", err)
	}
	if err := os.WriteFile(path, data, 0o600); err != nil {
		t.Fatalf("write JSON: %v", err)
	}
}

func writeGameDLL(t *testing.T, dir, filename string) string {
	t.Helper()
	return testfixtures.WritePE(t, dir, filename, testfixtures.PEOptions{
		Version: testfixtures.VersionInstalled,
	})
}

type legendaryEntry struct {
	AppName     string `json:"app_name"`
	InstallPath string `json:"install_path"`
	Title       string `json:"title"`
	IsDLC       bool   `json:"is_dlc"`
}

type gogEntry struct {
	AppName     string `json:"appName"`
	InstallPath string `json:"install_path"`
}

type gogInstalledFile struct {
	Installed []gogEntry `json:"installed"`
}

type sideloadInstall struct {
	Executable string `json:"executable"`
}

type sideloadEntry struct {
	Title       string          `json:"title"`
	FolderName  string          `json:"folder_name"`
	Install     sideloadInstall `json:"install"`
	IsInstalled bool            `json:"is_installed"`
}

type sideloadFile struct {
	Games []sideloadEntry `json:"games"`
}

func writeLutrisDB(t *testing.T, path, installedDir, uninstalledDir string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		t.Fatalf("create Lutris data dir: %v", err)
	}
	db, err := sql.Open("sqlite", path)
	if err != nil {
		t.Fatalf("open Lutris database: %v", err)
	}
	defer func() { _ = db.Close() }()
	if _, err := db.Exec(`CREATE TABLE games (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		name TEXT NOT NULL,
		directory TEXT,
		installed INTEGER NOT NULL DEFAULT 0
	)`); err != nil {
		t.Fatalf("create Lutris games table: %v", err)
	}
	if _, err := db.Exec(`INSERT INTO games (name, directory, installed) VALUES
		(?, ?, 1), (?, ?, 0)`,
		filepath.Base(installedDir), installedDir,
		filepath.Base(uninstalledDir), uninstalledDir); err != nil {
		t.Fatalf("insert Lutris games: %v", err)
	}
}

func TestScanHeroicDiscoversInstalledGames(t *testing.T) {
	p := newPaths(t)
	home := t.TempDir()
	config := filepath.Join(home, ".config", "heroic")
	gamesRoot := filepath.Join(home, "games")

	epicDir := filepath.Join(gamesRoot, "epic-install")
	gogDir := filepath.Join(gamesRoot, "gog-install")
	sideloadDir := filepath.Join(gamesRoot, "sideload-install")
	writeGameDLL(t, epicDir, "nvngx_dlss.dll")
	writeGameDLL(t, gogDir, "libxess.dll")
	writeGameDLL(t, sideloadDir, "sl.reflex.dll")

	writeJSONFile(t, filepath.Join(config, "legendaryConfig", "legendary", "installed.json"),
		map[string]legendaryEntry{
			"epic1": {
				AppName: "epic1", InstallPath: epicDir, Title: "Epic Game",
			},
			"epic1-dlc": {
				AppName: "epic1-dlc", InstallPath: epicDir, Title: "Epic DLC", IsDLC: true,
			},
		})
	writeJSONFile(t, filepath.Join(config, "gog_store", "installed.json"),
		gogInstalledFile{Installed: []gogEntry{{AppName: "gog1", InstallPath: gogDir}}})
	writeJSONFile(t, filepath.Join(config, "sideload_apps", "library.json"),
		sideloadFile{Games: []sideloadEntry{
			{Title: "Sideload Game", FolderName: sideloadDir, IsInstalled: true},
			{Title: "Uninstalled Sideload", FolderName: filepath.Join(gamesRoot, "Gone"), IsInstalled: false},
		}})

	startSidecarWithEnv(t, p, launcherEnv(home))
	scanClient, libraryClient, closeClients := scanClients(t, p.socket)
	defer closeClients()

	for run := 1; run <= 2; run++ {
		events := runScanSources(t, scanClient, heroicSource())
		finished := finishSummary(t, events)
		if finished.GetGameCount() != 3 || finished.GetDllCount() != 3 {
			t.Fatalf("run %d: finished = %d games / %d DLLs, want 3 / 3 (events: %v)",
				run, finished.GetGameCount(), finished.GetDllCount(), describeEvents(events))
		}
		for _, event := range events {
			if progress := event.GetLibraryProgress(); progress != nil && progress.GetLibraryCount() != 1 {
				t.Errorf("run %d: library_count = %d, want 1 Heroic source", run, progress.GetLibraryCount())
			}
		}
	}

	games := listGames(t, libraryClient)
	if len(games) != 3 {
		t.Fatalf("ListGames returned %d games after rescans, want 3", len(games))
	}
	byName := map[string]string{}
	for _, game := range games {
		byName[game.GetName()] = game.GetInstallPath()
	}
	want := map[string]string{
		"Epic Game":     epicDir,
		"gog-install":   gogDir,
		"Sideload Game": sideloadDir,
	}
	for name, path := range want {
		if got, ok := byName[name]; !ok {
			t.Errorf("game names = %v, missing %q", byName, name)
		} else if got != path {
			t.Errorf("game %q install path = %q, want %q", name, got, path)
		}
	}
}

func TestScanLutrisDiscoversInstalledGames(t *testing.T) {
	p := newPaths(t)
	home := t.TempDir()
	gamesRoot := filepath.Join(home, "games")
	installedDir := filepath.Join(gamesRoot, "Lutris Game")
	uninstalledDir := filepath.Join(gamesRoot, "Not Installed")
	writeGameDLL(t, installedDir, "nvngx_dlssg.dll")
	writeGameDLL(t, uninstalledDir, "nvngx_dlssg.dll")

	writeLutrisDB(t, filepath.Join(home, ".local", "share", "lutris", "pga.db"),
		installedDir, uninstalledDir)

	startSidecarWithEnv(t, p, launcherEnv(home))
	scanClient, libraryClient, closeClients := scanClients(t, p.socket)
	defer closeClients()

	events := runScanSources(t, scanClient, lutrisSource())
	finished := finishSummary(t, events)
	if finished.GetGameCount() != 1 || finished.GetDllCount() != 1 {
		t.Fatalf("finished = %d games / %d DLLs, want 1 / 1", finished.GetGameCount(), finished.GetDllCount())
	}
	games := listGames(t, libraryClient)
	if len(games) != 1 || games[0].GetName() != "Lutris Game" {
		t.Fatalf("games = %v, want only Lutris Game", games)
	}
}

func TestScanLutrisFlatpakDatabase(t *testing.T) {
	p := newPaths(t)
	home := t.TempDir()
	gameDir := filepath.Join(home, "games", "Flatpak Lutris Game")
	writeGameDLL(t, gameDir, "libxess.dll")
	writeLutrisDB(t, filepath.Join(home, ".var", "app", "net.lutris.Lutris", "data", "lutris", "pga.db"),
		gameDir, "")

	startSidecarWithEnv(t, p, launcherEnv(home))
	scanClient, libraryClient, closeClients := scanClients(t, p.socket)
	defer closeClients()

	events := runScanSources(t, scanClient, lutrisSource())
	finished := finishSummary(t, events)
	if finished.GetGameCount() != 1 || finished.GetDllCount() != 1 {
		t.Fatalf("finished = %d games / %d DLLs, want 1 / 1", finished.GetGameCount(), finished.GetDllCount())
	}
	games := listGames(t, libraryClient)
	if len(games) != 1 || games[0].GetName() != "Flatpak Lutris Game" {
		t.Fatalf("games = %v, want the Flatpak Lutris game", games)
	}
}

func TestScanLauncherDuplicateOfSteamWarnsAndKeepsOneGame(t *testing.T) {
	p := newPaths(t)
	home := t.TempDir()
	lib := testfixtures.NewSteamLibrary(t)
	gameDir := lib.AddGame(testfixtures.GameSpec{
		AppID: 9400, Name: "Steam Game", InstallDir: "Steam Game",
		DLLs: []testfixtures.DLLSpec{{Path: "nvngx_dlss.dll", Version: testfixtures.VersionInstalled}},
	})
	writeJSONFile(t,
		filepath.Join(home, ".config", "heroic", "legendaryConfig", "legendary", "installed.json"),
		map[string]legendaryEntry{
			"steam-copy": {AppName: "steam-copy", InstallPath: gameDir, Title: "Heroic Copy"},
		})

	startSidecarWithEnv(t, p, launcherEnv(home))
	scanClient, libraryClient, closeClients := scanClients(t, p.socket)
	defer closeClients()

	events := runScanSources(t, scanClient, steamSource(lib.Root()), heroicSource())
	finished := finishSummary(t, events)
	if finished.GetGameCount() != 1 || finished.GetDllCount() != 1 {
		t.Errorf("finished = %d games / %d DLLs, want 1 / 1", finished.GetGameCount(), finished.GetDllCount())
	}
	if _, ok := scanWarnings(events)[gameDir]; !ok {
		t.Errorf("no warning for Heroic duplicating a Steam game: %v", scanWarnings(events))
	}
	games := listGames(t, libraryClient)
	if len(games) != 1 || games[0].GetName() != "Steam Game" {
		t.Fatalf("games = %v, want only the Steam game", games)
	}
}

func TestScanMissingLaunchersWarnWithoutFailing(t *testing.T) {
	p := newPaths(t)
	home := t.TempDir()
	startSidecarWithEnv(t, p, launcherEnv(home))
	scanClient, _, closeClients := scanClients(t, p.socket)
	defer closeClients()

	events := runScanSources(t, scanClient, heroicSource(), lutrisSource())
	finished := finishSummary(t, events)
	if finished.GetGameCount() != 0 || finished.GetDllCount() != 0 {
		t.Errorf("finished = %d games / %d DLLs, want 0 / 0", finished.GetGameCount(), finished.GetDllCount())
	}
	warnings := 0
	for _, event := range events {
		if event.GetWarning() != nil {
			warnings++
		}
	}
	if warnings != 2 {
		t.Errorf("warning events = %d, want one for Heroic and one for Lutris", warnings)
	}
}

func TestScanCorruptHeroicManifestWarns(t *testing.T) {
	p := newPaths(t)
	home := t.TempDir()
	path := filepath.Join(home, ".config", "heroic", "legendaryConfig", "legendary", "installed.json")
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		t.Fatalf("create Heroic config dir: %v", err)
	}
	if err := os.WriteFile(path, []byte("{not json"), 0o600); err != nil {
		t.Fatalf("write corrupt manifest: %v", err)
	}

	startSidecarWithEnv(t, p, launcherEnv(home))
	scanClient, _, closeClients := scanClients(t, p.socket)
	defer closeClients()

	events := runScanSources(t, scanClient, heroicSource())
	finished := finishSummary(t, events)
	if finished.GetGameCount() != 0 {
		t.Errorf("finished.game_count = %d, want 0", finished.GetGameCount())
	}
	if _, ok := scanWarnings(events)[path]; !ok {
		t.Errorf("no warning for corrupt Heroic manifest: %v", scanWarnings(events))
	}
}

func TestScanHeroicFlatpakConfigRoot(t *testing.T) {
	p := newPaths(t)
	home := t.TempDir()
	gameDir := filepath.Join(home, "games", "Flatpak Game")
	writeGameDLL(t, gameDir, "nvngx_dlss.dll")
	config := filepath.Join(home, ".var", "app", "com.heroicgameslauncher.hgl", "config", "heroic")
	writeJSONFile(t, filepath.Join(config, "legendaryConfig", "legendary", "installed.json"),
		map[string]legendaryEntry{
			"flatpak1": {AppName: "flatpak1", InstallPath: gameDir, Title: "Flatpak Game"},
		})

	startSidecarWithEnv(t, p, launcherEnv(home))
	scanClient, libraryClient, closeClients := scanClients(t, p.socket)
	defer closeClients()

	events := runScanSources(t, scanClient, heroicSource())
	finished := finishSummary(t, events)
	if finished.GetGameCount() != 1 || finished.GetDllCount() != 1 {
		t.Fatalf("finished = %d games / %d DLLs, want 1 / 1", finished.GetGameCount(), finished.GetDllCount())
	}
	games := listGames(t, libraryClient)
	if len(games) != 1 || games[0].GetName() != "Flatpak Game" {
		t.Fatalf("games = %v, want the Flatpak game", games)
	}
}

func TestScanHeroicAcceptsGOGArrayForm(t *testing.T) {
	p := newPaths(t)
	home := t.TempDir()
	gameDir := filepath.Join(home, "games", "Array GOG Game")
	writeGameDLL(t, gameDir, "nvngx_dlss.dll")
	path := filepath.Join(home, ".config", "heroic", "gog_store", "installed.json")
	writeJSONFile(t, path, []gogEntry{{InstallPath: gameDir}})

	startSidecarWithEnv(t, p, launcherEnv(home))
	scanClient, libraryClient, closeClients := scanClients(t, p.socket)
	defer closeClients()

	events := runScanSources(t, scanClient, heroicSource())
	finished := finishSummary(t, events)
	if finished.GetGameCount() != 1 || finished.GetDllCount() != 1 {
		t.Fatalf("finished = %d games / %d DLLs, want 1 / 1", finished.GetGameCount(), finished.GetDllCount())
	}
	games := listGames(t, libraryClient)
	if len(games) != 1 || games[0].GetName() != "Array GOG Game" {
		t.Fatalf("games = %v, want the array-form GOG game", games)
	}
}

func TestScanNestedLauncherGamesAreBothKept(t *testing.T) {
	p := newPaths(t)
	home := t.TempDir()
	parent := filepath.Join(home, "games", "Parent Game")
	child := filepath.Join(parent, "DLC Game")
	writeGameDLL(t, parent, "nvngx_dlss.dll")
	writeGameDLL(t, child, "libxess.dll")
	writeJSONFile(t,
		filepath.Join(home, ".config", "heroic", "legendaryConfig", "legendary", "installed.json"),
		map[string]legendaryEntry{
			"parent": {AppName: "parent", InstallPath: parent, Title: "Parent Game"},
			"child":  {AppName: "child", InstallPath: child, Title: "DLC Game"},
		})

	startSidecarWithEnv(t, p, launcherEnv(home))
	scanClient, libraryClient, closeClients := scanClients(t, p.socket)
	defer closeClients()

	events := runScanSources(t, scanClient, heroicSource())
	finished := finishSummary(t, events)
	if finished.GetGameCount() != 2 || finished.GetDllCount() != 2 {
		t.Fatalf("finished = %d games / %d DLLs, want 2 / 2", finished.GetGameCount(), finished.GetDllCount())
	}
	games := listGames(t, libraryClient)
	if len(games) != 2 {
		t.Fatalf("ListGames returned %d games, want 2", len(games))
	}
	for _, game := range games {
		if len(game.GetDlls()) != 1 {
			t.Errorf("game %q DLLs = %v, want exactly one fenced file", game.GetName(), game.GetDlls())
		}
	}
}

func TestScanLutrisDuplicateOfSteamWarnsAndKeepsOneGame(t *testing.T) {
	p := newPaths(t)
	home := t.TempDir()
	lib := testfixtures.NewSteamLibrary(t)
	gameDir := lib.AddGame(testfixtures.GameSpec{
		AppID: 9500, Name: "Steam Game", InstallDir: "Steam Game",
		DLLs: []testfixtures.DLLSpec{{Path: "nvngx_dlss.dll", Version: testfixtures.VersionInstalled}},
	})
	writeLutrisDB(t, filepath.Join(home, ".local", "share", "lutris", "pga.db"),
		gameDir, "")

	startSidecarWithEnv(t, p, launcherEnv(home))
	scanClient, libraryClient, closeClients := scanClients(t, p.socket)
	defer closeClients()

	events := runScanSources(t, scanClient, steamSource(lib.Root()), lutrisSource())
	finished := finishSummary(t, events)
	if finished.GetGameCount() != 1 || finished.GetDllCount() != 1 {
		t.Errorf("finished = %d games / %d DLLs, want 1 / 1", finished.GetGameCount(), finished.GetDllCount())
	}
	if _, ok := scanWarnings(events)[gameDir]; !ok {
		t.Errorf("no warning for Lutris duplicating a Steam game: %v", scanWarnings(events))
	}
	games := listGames(t, libraryClient)
	if len(games) != 1 || games[0].GetName() != "Steam Game" {
		t.Fatalf("games = %v, want only the Steam game", games)
	}
}
