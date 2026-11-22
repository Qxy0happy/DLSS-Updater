package scan

import (
	"context"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
)

// errInvalidRoot marks a Steam root that cannot be scanned at all. It is the
// only scan failure caused by the root itself; unreadable libraries inside a
// valid root are warnings.
var errInvalidRoot = errors.New("invalid Steam root")

// warning is a non-fatal problem the scan reports and continues past.
type warning struct {
	Path    string
	Message string
}

// library is one library root plus the derived steamapps paths.
type library struct {
	Root      string
	SteamApps string
	Common    string
}

// game is one installed game discovered from an appmanifest.
type game struct {
	AppID       uint32
	Name        string
	InstallPath string
	LibraryRoot string
}

// dllFile is one known-technology file inside a game directory.
type dllFile struct {
	Path     string
	Type     string
	Filename string
}

// discoverLibraries validates the Steam root and resolves the libraries that
// belong to it. A missing libraryfolders.vdf falls back to
// <root>/steamapps/common, matching the old application.
func discoverLibraries(root string) ([]library, []warning, error) {
	root = strings.TrimSpace(root)
	if root == "" || !filepath.IsAbs(root) {
		return nil, nil, fmt.Errorf("%w: the Steam root must be an absolute path", errInvalidRoot)
	}
	info, err := os.Stat(root)
	if err != nil {
		if errors.Is(err, fs.ErrNotExist) {
			return nil, nil, fmt.Errorf("%w: %s does not exist", errInvalidRoot, root)
		}
		return nil, nil, fmt.Errorf("%w: %s cannot be inspected: %v", errInvalidRoot, root, err)
	}
	if !info.IsDir() {
		return nil, nil, fmt.Errorf("%w: %s is not a directory", errInvalidRoot, root)
	}
	if err := readableDir(root); err != nil {
		return nil, nil, fmt.Errorf("%w: %s cannot be read: %v", errInvalidRoot, root, err)
	}

	var warnings []warning
	roots := []string{root}
	vdfPath := filepath.Join(root, "steamapps", "libraryfolders.vdf")
	data, err := os.ReadFile(vdfPath)
	switch {
	case err == nil:
		parsed, parseErr := parseLibraryFolderPaths(data)
		if parseErr != nil {
			warnings = append(warnings, warning{
				Path:    vdfPath,
				Message: "The Steam library list could not be parsed; only the selected root is scanned.",
			})
			roots = []string{root}
		} else {
			roots = parsed
		}
	case errors.Is(err, fs.ErrNotExist):
		// Fallback to the selected root's own steamapps/common.
	default:
		warnings = append(warnings, warning{
			Path:    vdfPath,
			Message: "The Steam library list could not be read; only the selected root is scanned.",
		})
	}

	seen := realPathSet{}
	libraries := make([]library, 0, len(roots))
	for _, raw := range roots {
		entryRoot := strings.TrimSpace(raw)
		if entryRoot == "" {
			continue
		}
		if !filepath.IsAbs(entryRoot) {
			entryRoot = filepath.Join(root, entryRoot)
		}
		entryRoot = filepath.Clean(entryRoot)
		if !seen.add(entryRoot) {
			continue
		}
		lib := library{
			Root:      entryRoot,
			SteamApps: filepath.Join(entryRoot, "steamapps"),
			Common:    filepath.Join(entryRoot, "steamapps", "common"),
		}
		if info, err := os.Stat(lib.SteamApps); err != nil || !info.IsDir() {
			warnings = append(warnings, warning{
				Path:    lib.SteamApps,
				Message: "This Steam library is missing or unreadable; it is skipped.",
			})
			continue
		}
		libraries = append(libraries, lib)
	}
	return libraries, warnings, nil
}

// readableDir verifies the directory can actually be enumerated; os.Stat alone
// succeeds on a mode-000 directory.
func readableDir(path string) error {
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer func() { _ = f.Close() }()
	_, err = f.Readdirnames(1)
	if err != nil && !errors.Is(err, io.EOF) {
		return err
	}
	return nil
}

// enumerateGames reads every appmanifest_*.acf in one library. A manifest that
// cannot be read or parsed is a warning; the rest of the library still scans.
func enumerateGames(ctx context.Context, lib library) ([]game, []warning) {
	entries, err := os.ReadDir(lib.SteamApps)
	if err != nil {
		if ctx.Err() != nil {
			return nil, nil
		}
		return nil, []warning{{
			Path:    lib.SteamApps,
			Message: "This Steam library could not be read; it is skipped.",
		}}
	}

	var games []game
	var warnings []warning
	for _, entry := range entries {
		if ctx.Err() != nil {
			return games, warnings
		}
		name := strings.ToLower(entry.Name())
		if !strings.HasPrefix(name, "appmanifest_") || !strings.HasSuffix(name, ".acf") {
			continue
		}
		if !entry.Type().IsRegular() {
			continue
		}
		path := filepath.Join(lib.SteamApps, entry.Name())
		data, err := os.ReadFile(path)
		if err != nil {
			warnings = append(warnings, warning{
				Path:    path,
				Message: "This game manifest could not be read; the game is skipped.",
			})
			continue
		}
		manifest, ok, err := parseAppManifest(data)
		if err != nil {
			warnings = append(warnings, warning{
				Path:    path,
				Message: "This game manifest could not be parsed; the game is skipped.",
			})
			continue
		}
		if !ok {
			continue
		}
		games = append(games, game{
			AppID:       manifest.AppID,
			Name:        manifest.Name,
			InstallPath: filepath.Join(lib.Common, manifest.InstallDir),
			LibraryRoot: lib.Root,
		})
	}
	return games, warnings
}

// findDLLs walks one game directory recursively. Symbolic links are never
// followed, non-game directories are skipped, and each physical file is
// reported at most once per scan. A subdirectory that cannot be read becomes a
// warning; a root that cannot be read is returned as an error so the caller can
// skip a game it cannot inspect.
func findDLLs(ctx context.Context, gameDir string, seen realPathSet) ([]dllFile, []warning, error) {
	var found []dllFile
	var warnings []warning

	var walk func(dir string, root bool) error
	walk = func(dir string, root bool) error {
		entries, err := os.ReadDir(dir)
		if err != nil {
			if root {
				return err
			}
			warnings = append(warnings, warning{
				Path:    dir,
				Message: "This game subdirectory could not be read; it is skipped.",
			})
			return nil
		}
		for _, entry := range entries {
			if err := ctx.Err(); err != nil {
				return err
			}
			if entry.Type()&fs.ModeSymlink != 0 {
				continue
			}
			name := entry.Name()
			if entry.IsDir() {
				if skipDirectory(name) {
					continue
				}
				if err := walk(filepath.Join(dir, name), false); err != nil {
					return err
				}
				continue
			}
			if !entry.Type().IsRegular() {
				continue
			}
			dllType, ok := dllType(name)
			if !ok {
				continue
			}
			path := filepath.Join(dir, name)
			if !seen.add(path) {
				continue
			}
			found = append(found, dllFile{Path: path, Type: dllType, Filename: name})
		}
		return nil
	}

	if err := walk(filepath.Clean(gameDir), true); err != nil {
		return nil, warnings, err
	}
	return found, warnings, nil
}
