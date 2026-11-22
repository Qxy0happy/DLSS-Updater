package testfixtures_test

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"

	"github.com/Qxy0happy/DLSS-Updater/backend/internal/testfixtures"
	"github.com/andygrunwald/vdf"
	"github.com/saferwall/pe"
)

func TestSteamLibraryLayout(t *testing.T) {
	lib := testfixtures.NewSteamLibrary(t)

	root := lib.Root()
	if !filepath.IsAbs(root) {
		t.Fatalf("Root() = %q, want an absolute path", root)
	}
	if !strings.HasPrefix(root, lib.TempRoot()) {
		t.Fatalf("Root() = %q, want it below TempRoot() %q", root, lib.TempRoot())
	}
	if _, err := os.Stat(filepath.Join(root, "steamapps", "common")); err != nil {
		t.Fatalf("steamapps/common missing: %v", err)
	}

	vdf, err := os.ReadFile(lib.LibraryFoldersPath())
	if err != nil {
		t.Fatalf("read libraryfolders.vdf: %v", err)
	}
	if !strings.Contains(string(vdf), root) {
		t.Errorf("libraryfolders.vdf does not mention the primary root %q:\n%s", root, vdf)
	}
	if !strings.Contains(string(vdf), `"libraryfolders"`) {
		t.Errorf("libraryfolders.vdf has no libraryfolders key:\n%s", vdf)
	}
}

func TestSteamLibraryAddsGamesWithNestedDLLs(t *testing.T) {
	lib := testfixtures.NewSteamLibrary(t)

	gameDir := lib.AddGame(testfixtures.GameSpec{
		AppID:      1091500,
		Name:       "Cyberpunk 2077",
		InstallDir: "Cyberpunk 2077",
		DLLs: []testfixtures.DLLSpec{
			{Path: "bin/x64/" + testfixtures.DLSSDLL, Version: testfixtures.VersionInstalled},
			{Path: "bin/x64/" + testfixtures.DLSSGDLL, Version: testfixtures.VersionAtMinimum, Bits: 32},
		},
	})
	if want := filepath.Join(lib.Root(), "steamapps", "common", "Cyberpunk 2077"); gameDir != want {
		t.Fatalf("AddGame returned %q, want %q", gameDir, want)
	}
	if got := testfixtures.PEVersion(t, filepath.Join(gameDir, "bin/x64", testfixtures.DLSSDLL)); got != testfixtures.VersionInstalled {
		t.Errorf("nested DLL version = %q, want %q", got, testfixtures.VersionInstalled)
	}

	manifest := filepath.Join(lib.SteamAppsDir(), "appmanifest_1091500.acf")
	body, err := os.ReadFile(manifest)
	if err != nil {
		t.Fatalf("read appmanifest: %v", err)
	}
	for _, want := range []string{`"appid"`, "1091500", `"name"`, "Cyberpunk 2077", `"installdir"`} {
		if !strings.Contains(string(body), want) {
			t.Errorf("appmanifest is missing %q:\n%s", want, body)
		}
	}
	if !strings.Contains(string(body), "Cyberpunk 2077") {
		t.Errorf("appmanifest does not carry the installdir:\n%s", body)
	}
}

func TestSteamLibraryGameWithoutKnownDLLs(t *testing.T) {
	lib := testfixtures.NewSteamLibrary(t)
	gameDir := lib.AddGame(testfixtures.GameSpec{
		AppID:      400,
		Name:       "Portal",
		InstallDir: "Portal",
	})
	if _, err := os.Stat(gameDir); err != nil {
		t.Fatalf("game dir missing: %v", err)
	}
	entries, err := os.ReadDir(gameDir)
	if err != nil {
		t.Fatalf("read game dir: %v", err)
	}
	if len(entries) != 0 {
		t.Errorf("game dir has %d entries, want none", len(entries))
	}
}

func TestSteamLibraryMissingInstallDir(t *testing.T) {
	lib := testfixtures.NewSteamLibrary(t)
	gameDir := lib.AddMissingInstallDir(testfixtures.GameSpec{
		AppID:      220,
		Name:       "Half-Life 2",
		InstallDir: "Half-Life 2",
	})
	if _, err := os.Stat(gameDir); !os.IsNotExist(err) {
		t.Fatalf("install dir exists, want it missing (err=%v)", err)
	}
	manifest := filepath.Join(lib.SteamAppsDir(), "appmanifest_220.acf")
	if _, err := os.Stat(manifest); err != nil {
		t.Fatalf("appmanifest missing: %v", err)
	}
}

func TestSteamLibraryUnreadableGameDir(t *testing.T) {
	if os.Geteuid() == 0 {
		t.Skip("root ignores directory permissions")
	}
	lib := testfixtures.NewSteamLibrary(t)
	gameDir, changed := lib.AddUnreadableGame(testfixtures.GameSpec{
		AppID:      620,
		Name:       "Portal 2",
		InstallDir: "Portal 2",
		DLLs:       []testfixtures.DLLSpec{{Path: testfixtures.DLSSDLL, Version: testfixtures.VersionInstalled}},
	})
	if !changed {
		t.Fatal("AddUnreadableGame reported no permission change for a non-root user")
	}
	info, err := os.Stat(gameDir)
	if err != nil {
		t.Fatalf("stat unreadable dir: %v", err)
	}
	if info.Mode().Perm() != 0 {
		t.Errorf("mode = %v, want 0", info.Mode().Perm())
	}
}

func TestSteamLibraryAdditionalRoots(t *testing.T) {
	lib := testfixtures.NewSteamLibrary(t)

	second := lib.AddLibraryRoot("library2")
	if !strings.HasPrefix(second, lib.TempRoot()) {
		t.Fatalf("second root %q is outside %q", second, lib.TempRoot())
	}
	gameDir := lib.AddGameTo(second, testfixtures.GameSpec{
		AppID:      570,
		Name:       "Dota 2",
		InstallDir: "dota 2 beta",
		DLLs:       []testfixtures.DLLSpec{{Path: "game/bin/linuxsteamrt64/" + testfixtures.XeSSDLL, Version: testfixtures.VersionUpdate}},
	})
	if !strings.HasPrefix(gameDir, second) {
		t.Fatalf("game dir %q is not inside the second library %q", gameDir, second)
	}
	if got := testfixtures.PEVersion(t, filepath.Join(gameDir, "game/bin/linuxsteamrt64", testfixtures.XeSSDLL)); got != testfixtures.VersionUpdate {
		t.Errorf("version = %q, want %q", got, testfixtures.VersionUpdate)
	}

	vdf, err := os.ReadFile(lib.LibraryFoldersPath())
	if err != nil {
		t.Fatalf("read libraryfolders.vdf: %v", err)
	}
	for _, want := range []string{lib.Root(), second} {
		if !strings.Contains(string(vdf), want) {
			t.Errorf("libraryfolders.vdf does not list %q:\n%s", want, vdf)
		}
	}
}

func TestSteamLibrarySymlinkedRoot(t *testing.T) {
	lib := testfixtures.NewSteamLibrary(t)

	link, real := lib.AddSymlinkedLibraryRoot("steam-link")
	if _, err := os.Stat(real); err != nil {
		t.Fatalf("real library root missing: %v", err)
	}
	target, err := os.Readlink(link)
	if err != nil {
		t.Fatalf("read symlink %s: %v", link, err)
	}
	if target != real {
		t.Errorf("symlink target = %q, want %q", target, real)
	}
	gameDir := lib.AddGameTo(real, testfixtures.GameSpec{
		AppID:      292030,
		Name:       "The Witcher 3",
		InstallDir: "The Witcher 3",
		DLLs:       []testfixtures.DLLSpec{{Path: "bin/x64/" + testfixtures.DLSSDLL, Version: testfixtures.VersionNewest}},
	})
	if !strings.HasPrefix(gameDir, real) {
		t.Fatalf("game dir %q is not inside the real root %q", gameDir, real)
	}

	vdf, err := os.ReadFile(lib.LibraryFoldersPath())
	if err != nil {
		t.Fatalf("read libraryfolders.vdf: %v", err)
	}
	if !strings.Contains(string(vdf), link) {
		t.Errorf("libraryfolders.vdf does not list the symlink %q:\n%s", link, vdf)
	}
}

func TestSteamLibraryRemoveLibraryFolders(t *testing.T) {
	lib := testfixtures.NewSteamLibrary(t)
	lib.RemoveLibraryFolders()
	if _, err := os.Stat(lib.LibraryFoldersPath()); !os.IsNotExist(err) {
		t.Fatalf("libraryfolders.vdf still exists (err=%v)", err)
	}
}

func TestSteamFixturesAreValidVDF(t *testing.T) {
	lib := testfixtures.NewSteamLibrary(t)
	lib.AddLibraryRoot("library2")
	lib.AddGame(testfixtures.GameSpec{
		AppID:      1091500,
		Name:       "Cyberpunk 2077",
		InstallDir: "Cyberpunk 2077",
	})

	parse := func(path string) map[string]any {
		t.Helper()
		f, err := os.Open(path)
		if err != nil {
			t.Fatalf("open %s: %v", path, err)
		}
		defer f.Close()
		doc, err := vdf.NewParser(f).Parse()
		if err != nil {
			t.Fatalf("parse %s: %v", path, err)
		}
		return doc
	}

	folders, ok := parse(lib.LibraryFoldersPath())["libraryfolders"].(map[string]any)
	if !ok {
		t.Fatal("libraryfolders.vdf has no libraryfolders object")
	}
	if len(folders) != 2 {
		t.Fatalf("libraryfolders.vdf lists %d libraries, want 2", len(folders))
	}
	for i, want := range []string{lib.Root(), filepath.Join(lib.TempRoot(), "library2")} {
		entry, ok := folders[strconv.Itoa(i)].(map[string]any)
		if !ok {
			t.Fatalf("library entry %d is not an object: %#v", i, folders[strconv.Itoa(i)])
		}
		if got := entry["path"]; got != want {
			t.Errorf("library %d path = %v, want %q", i, got, want)
		}
		if _, ok := entry["apps"].(map[string]any); !ok {
			t.Errorf("library %d has no apps object", i)
		}
	}

	manifestPath := filepath.Join(lib.SteamAppsDir(), "appmanifest_1091500.acf")
	app, ok := parse(manifestPath)["AppState"].(map[string]any)
	if !ok {
		t.Fatal("appmanifest has no AppState object")
	}
	if got := app["appid"]; got != "1091500" {
		t.Errorf("appmanifest appid = %v, want 1091500", got)
	}
	if got := app["installdir"]; got != "Cyberpunk 2077" {
		t.Errorf("appmanifest installdir = %v, want Cyberpunk 2077", got)
	}
}

func TestFixturesStayInsideTempRoots(t *testing.T) {
	lib := testfixtures.NewSteamLibrary(t)
	paths := []string{
		lib.Root(),
		lib.SteamAppsDir(),
		lib.LibraryFoldersPath(),
		lib.AddGame(testfixtures.GameSpec{
			AppID: 1, Name: "Contained", InstallDir: "Contained",
			DLLs: []testfixtures.DLLSpec{{Path: testfixtures.DLSSDLL, Version: testfixtures.VersionInstalled}},
		}),
		lib.AddMissingInstallDir(testfixtures.GameSpec{AppID: 2, Name: "Missing", InstallDir: "Missing"}),
		lib.AddLibraryRoot("extra-library"),
	}
	link, real := lib.AddSymlinkedLibraryRoot("linked-library")
	paths = append(paths, link, real)
	if unreadable, changed := lib.AddUnreadableGame(testfixtures.GameSpec{
		AppID: 3, Name: "Unreadable", InstallDir: "Unreadable",
	}); changed {
		paths = append(paths, unreadable)
	}

	src := testfixtures.NewDLLSource(t)
	paths = append(paths,
		src.Dir(),
		src.Path("not-written.dll"),
		src.Add("NVNGX_DLSS.dll", testfixtures.VersionUpdate),
		src.Add32("libxess.dll", testfixtures.VersionAtMinimum),
		src.AddCorrupt("nvngx_dlssg.dll"),
	)

	roots := []string{lib.TempRoot(), src.TempRoot()}
	for _, path := range paths {
		if !filepath.IsAbs(path) {
			t.Errorf("fixture path %q is not absolute", path)
			continue
		}
		if !withinAny(path, roots) {
			t.Errorf("fixture path %q escapes the temporary roots %v", path, roots)
		}
	}
}

func withinAny(path string, roots []string) bool {
	for _, root := range roots {
		if path == root || strings.HasPrefix(path, root+string(filepath.Separator)) {
			return true
		}
	}
	return false
}

func TestDLLSourceLayout(t *testing.T) {
	src := testfixtures.NewDLLSource(t)
	if !strings.HasPrefix(src.Dir(), src.TempRoot()) {
		t.Fatalf("Dir() = %q, want it below TempRoot() %q", src.Dir(), src.TempRoot())
	}

	mixed := src.Add("NVNGX_DLSS.dll", testfixtures.VersionUpdate)
	if filepath.Base(mixed) != "NVNGX_DLSS.dll" {
		t.Errorf("Add preserved no filename case: %q", filepath.Base(mixed))
	}
	if got := testfixtures.PEVersion(t, mixed); got != testfixtures.VersionUpdate {
		t.Errorf("version = %q, want %q", got, testfixtures.VersionUpdate)
	}
	if got := src.Path("NVNGX_DLSS.dll"); got != mixed {
		t.Errorf("Path() = %q, want %q", got, mixed)
	}

	xess32 := src.Add32("libxess.dll", testfixtures.VersionAtMinimum)
	if got := testfixtures.PEVersion(t, xess32); got != testfixtures.VersionAtMinimum {
		t.Errorf("32-bit source version = %q, want %q", got, testfixtures.VersionAtMinimum)
	}

	corrupt := src.AddCorrupt("nvngx_dlssg.dll")
	if f, err := pe.New(corrupt, versionOptions()); err == nil {
		defer f.Close()
		if perr := f.Parse(); perr == nil {
			t.Error("corrupt DLL source parsed as a valid PE")
		}
	}
}
