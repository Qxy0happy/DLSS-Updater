package testfixtures

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
)

// GameSpec describes one synthetic Steam game.
type GameSpec struct {
	// AppID is the Steam app id written to the appmanifest (required).
	AppID uint32
	// Name is the display name written to the appmanifest (required).
	Name string
	// InstallDir is the directory name below steamapps/common (required).
	InstallDir string
	// DLLs are the known-technology files to place inside the game directory.
	DLLs []DLLSpec
}

// DLLSpec describes one synthetic DLL inside a game directory.
type DLLSpec struct {
	// Path is slash-separated and relative to the game directory, for example
	// "bin/x64/nvngx_dlss.dll". Paths that escape the game directory are
	// rejected.
	Path string
	// Version is the PE file version, for example "2.4.2.0".
	Version string
	// Bits is 32 or 64; zero means 64.
	Bits int
}

// SteamLibrary is a synthetic Steam root plus any additional library roots,
// all below one t.TempDir().
type SteamLibrary struct {
	tb        testing.TB
	tmpRoot   string
	root      string
	libraries []string
}

// NewSteamLibrary creates a Steam root at <t.TempDir()>/steam with
// steamapps/common and a libraryfolders.vdf listing that root.
func NewSteamLibrary(tb testing.TB) *SteamLibrary {
	tb.Helper()
	tmp := tb.TempDir()
	l := &SteamLibrary{
		tb:      tb,
		tmpRoot: tmp,
		root:    filepath.Join(tmp, "steam"),
	}
	l.mkdir(filepath.Join(l.root, "steamapps", "common"))
	l.libraries = []string{l.root}
	l.WriteLibraryFolders()
	return l
}

// TempRoot is the directory every path this builder creates lives under.
func (l *SteamLibrary) TempRoot() string { return l.tmpRoot }

// Root is the primary Steam root (the directory holding steamapps).
func (l *SteamLibrary) Root() string { return l.root }

// SteamAppsDir is the primary <root>/steamapps directory.
func (l *SteamLibrary) SteamAppsDir() string { return filepath.Join(l.root, "steamapps") }

// LibraryFoldersPath is where libraryfolders.vdf is written.
func (l *SteamLibrary) LibraryFoldersPath() string {
	return filepath.Join(l.root, "steamapps", "libraryfolders.vdf")
}

// AddGame writes a game into the primary library and returns its directory.
func (l *SteamLibrary) AddGame(spec GameSpec) string {
	l.tb.Helper()
	return l.AddGameTo(l.root, spec)
}

// AddGameTo writes a game into libraryRoot and returns its directory.
func (l *SteamLibrary) AddGameTo(libraryRoot string, spec GameSpec) string {
	l.tb.Helper()
	l.validateGame(spec)

	gameDir := filepath.Join(libraryRoot, "steamapps", "common", spec.InstallDir)
	l.mkdir(gameDir)
	for _, dll := range spec.DLLs {
		rel := filepath.Clean(dll.Path)
		if filepath.IsAbs(rel) || rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) {
			l.tb.Fatalf("DLL path %q escapes the game directory %q", dll.Path, gameDir)
		}
		target := filepath.Join(gameDir, rel)
		if !strings.HasPrefix(target, gameDir+string(filepath.Separator)) {
			l.tb.Fatalf("DLL path %q escapes the game directory %q", dll.Path, gameDir)
		}
		WritePE(l.tb, filepath.Dir(target), filepath.Base(target), PEOptions{
			Bits:    dll.Bits,
			Version: dll.Version,
		})
	}
	l.writeManifest(libraryRoot, spec)
	return gameDir
}

// AddMissingInstallDir writes an appmanifest whose installdir does not exist
// and returns the path it points at.
func (l *SteamLibrary) AddMissingInstallDir(spec GameSpec) string {
	l.tb.Helper()
	l.validateGame(spec)
	l.writeManifest(l.root, spec)
	return filepath.Join(l.root, "steamapps", "common", spec.InstallDir)
}

// AddUnreadableGame writes a game and removes all permissions from its
// directory. The second result is false when running as root, because root
// can read a mode-0 directory; callers skip the permission assertion then.
func (l *SteamLibrary) AddUnreadableGame(spec GameSpec) (string, bool) {
	l.tb.Helper()
	gameDir := l.AddGame(spec)
	if os.Geteuid() == 0 {
		return gameDir, false
	}
	if err := os.Chmod(gameDir, 0); err != nil {
		l.tb.Fatalf("make %s unreadable: %v", gameDir, err)
	}
	l.tb.Cleanup(func() { _ = os.Chmod(gameDir, 0o700) })
	return gameDir, true
}

// AddLibraryRoot creates and registers an additional library root below the
// fixture temp root, returning it.
func (l *SteamLibrary) AddLibraryRoot(name string) string {
	l.tb.Helper()
	if name == "" || filepath.Base(name) != name {
		l.tb.Fatalf("library root name %q must be a single path element", name)
	}
	root := filepath.Join(l.tmpRoot, name)
	if k := l.index(root); k < 0 {
		l.mkdir(filepath.Join(root, "steamapps", "common"))
		l.libraries = append(l.libraries, root)
	}
	l.WriteLibraryFolders()
	return root
}

// AddSymlinkedLibraryRoot registers a library root that is a symlink to a real
// directory, mirroring ~/.steam/steam -> ~/.local/share/Steam. It returns the
// symlink path and the resolved directory.
func (l *SteamLibrary) AddSymlinkedLibraryRoot(name string) (link, real string) {
	l.tb.Helper()
	if name == "" || filepath.Base(name) != name {
		l.tb.Fatalf("symlinked library name %q must be a single path element", name)
	}
	real = filepath.Join(l.tmpRoot, name+"-real")
	link = filepath.Join(l.tmpRoot, name)
	l.mkdir(filepath.Join(real, "steamapps", "common"))
	if err := os.Symlink(real, link); err != nil {
		l.tb.Fatalf("symlink %s -> %s: %v", link, real, err)
	}
	if l.index(link) < 0 {
		l.libraries = append(l.libraries, link)
	}
	l.WriteLibraryFolders()
	return link, real
}

// RemoveLibraryFolders deletes libraryfolders.vdf so tests can exercise the
// fallback to <root>/steamapps/common.
func (l *SteamLibrary) RemoveLibraryFolders() {
	l.tb.Helper()
	if err := os.Remove(l.LibraryFoldersPath()); err != nil && !os.IsNotExist(err) {
		l.tb.Fatalf("remove libraryfolders.vdf: %v", err)
	}
}

// WriteLibraryFolders (re)writes libraryfolders.vdf from the static template
// under the repository's fixtures/ directory.
func (l *SteamLibrary) WriteLibraryFolders() {
	l.tb.Helper()
	header := string(fixtureFile(l.tb, "steam", "libraryfolders.vdf"))
	entryTemplate := string(fixtureFile(l.tb, "steam", "libraryfolder_entry.vdf"))

	var entries strings.Builder
	for i, root := range l.libraries {
		entry := strings.NewReplacer(
			"{{INDEX}}", strconv.Itoa(i),
			"{{PATH}}", vdfString(root),
			"{{CONTENT_ID}}", strconv.Itoa(900000000+i),
		).Replace(entryTemplate)
		entries.WriteString(entry)
	}
	body := strings.Replace(header, "{{LIBRARY_ENTRIES}}", entries.String(), 1)

	dir := filepath.Dir(l.LibraryFoldersPath())
	l.mkdir(dir)
	if err := os.WriteFile(l.LibraryFoldersPath(), []byte(body), 0o644); err != nil {
		l.tb.Fatalf("write libraryfolders.vdf: %v", err)
	}
}

func (l *SteamLibrary) writeManifest(libraryRoot string, spec GameSpec) {
	l.tb.Helper()
	template := string(fixtureFile(l.tb, "steam", "appmanifest.acf"))
	body := strings.NewReplacer(
		"{{APP_ID}}", strconv.FormatUint(uint64(spec.AppID), 10),
		"{{NAME}}", vdfString(spec.Name),
		"{{INSTALL_DIR}}", vdfString(spec.InstallDir),
		"{{SIZE_ON_DISK}}", "1073741824",
		"{{BUILD_ID}}", strconv.FormatUint(uint64(spec.AppID)*2+1, 10),
	).Replace(template)

	dir := filepath.Join(libraryRoot, "steamapps")
	l.mkdir(dir)
	path := filepath.Join(dir, "appmanifest_"+strconv.FormatUint(uint64(spec.AppID), 10)+".acf")
	if err := os.WriteFile(path, []byte(body), 0o644); err != nil {
		l.tb.Fatalf("write appmanifest %s: %v", path, err)
	}
}

func (l *SteamLibrary) validateGame(spec GameSpec) {
	l.tb.Helper()
	if spec.InstallDir == "" {
		l.tb.Fatal("GameSpec.InstallDir must not be empty")
	}
	if filepath.Base(spec.InstallDir) != spec.InstallDir {
		l.tb.Fatalf("GameSpec.InstallDir %q must be a single path element", spec.InstallDir)
	}
	if spec.Name == "" {
		l.tb.Fatalf("GameSpec.Name must not be empty for install dir %q", spec.InstallDir)
	}
}

func (l *SteamLibrary) mkdir(path string) {
	l.tb.Helper()
	if err := os.MkdirAll(path, 0o755); err != nil {
		l.tb.Fatalf("create %s: %v", path, err)
	}
}

func (l *SteamLibrary) index(path string) int {
	for i, existing := range l.libraries {
		if existing == path {
			return i
		}
	}
	return -1
}

// vdfString escapes a value for a quoted VDF string.
func vdfString(s string) string {
	return strings.NewReplacer(`\`, `\\`, `"`, `\"`).Replace(s)
}

// fixtureFile reads one static fixture below <repo>/fixtures. The repository
// root is found by walking up from the test's working directory, which Go
// sets to the package directory.
func fixtureFile(tb testing.TB, parts ...string) []byte {
	tb.Helper()
	path := repoFixturePath(tb, parts...)
	data, err := os.ReadFile(path)
	if err != nil {
		tb.Fatalf("read fixture %s: %v", path, err)
	}
	return data
}

func repoFixturePath(tb testing.TB, parts ...string) string {
	tb.Helper()
	dir, err := os.Getwd()
	if err != nil {
		tb.Fatalf("get working directory: %v", err)
	}
	for {
		candidate := filepath.Join(append([]string{dir, "fixtures"}, parts...)...)
		if _, err := os.Stat(candidate); err == nil {
			return candidate
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			tb.Fatalf("cannot find fixtures/%s above the working directory", strings.Join(parts, "/"))
		}
		dir = parent
	}
}
