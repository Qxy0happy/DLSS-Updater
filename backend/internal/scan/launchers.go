package scan

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"errors"
	"net/url"
	"os"
	"path/filepath"
	"strings"

	_ "modernc.org/sqlite"
)

// launcherDiscovery is the planned result of one auto-detected launcher
// source. Readable is false only when a present database or configuration
// cannot be read at all; a launcher that is simply not installed is a warning
// with nothing to scan.
type launcherDiscovery struct {
	Games    []game
	Warnings []warning
	Path     string
	Readable bool
}

// heroicConfigRoots returns the native and Flatpak Heroic configuration
// directories that exist, in preference order.
func heroicConfigRoots() []string {
	var candidates []string
	if xdg := strings.TrimSpace(os.Getenv("XDG_CONFIG_HOME")); xdg != "" {
		candidates = append(candidates, filepath.Join(xdg, "heroic"))
	}
	if home := strings.TrimSpace(os.Getenv("HOME")); home != "" {
		candidates = append(candidates,
			filepath.Join(home, ".config", "heroic"),
			filepath.Join(home, ".var", "app", "com.heroicgameslauncher.hgl", "config", "heroic"),
		)
	}
	if dir, err := os.UserConfigDir(); err == nil {
		candidates = append(candidates, filepath.Join(dir, "heroic"))
	}
	return existingDirs(candidates)
}

// discoverHeroic reads the installed-game manifests Heroic writes for Epic,
// GOG and sideloaded games.
func discoverHeroic() launcherDiscovery {
	discovery := launcherDiscovery{}
	roots := heroicConfigRoots()
	if len(roots) == 0 {
		discovery.Readable = true
		discovery.Warnings = append(discovery.Warnings, warning{
			Message: "Heroic is not installed or its configuration is not accessible; it is skipped.",
		})
		return discovery
	}
	discovery.Path = roots[0]
	discovery.Readable = false
	for _, root := range roots {
		if err := readableDir(root); err != nil {
			discovery.Warnings = append(discovery.Warnings, warning{
				Path:    root,
				Message: "The Heroic configuration folder could not be read; it is skipped.",
			})
			continue
		}
		discovery.Readable = true
		discovery.Warnings = append(discovery.Warnings, discoverHeroicRoot(root, &discovery.Games)...)
	}
	discovery.Games = dedupeLauncherGames(discovery.Games)
	return discovery
}

func discoverHeroicRoot(root string, games *[]game) []warning {
	var warnings []warning
	warnings = append(warnings, readLegendaryGames(root, games)...)
	warnings = append(warnings, readGOGGames(root, games)...)
	warnings = append(warnings, readSideloadGames(root, games)...)
	return warnings
}

func readLegendaryGames(root string, games *[]game) []warning {
	path := filepath.Join(root, "legendaryConfig", "legendary", "installed.json")
	data, found, warn := readLauncherFile(path)
	if warn != nil {
		return []warning{*warn}
	}
	if !found {
		return nil
	}

	var entries map[string]struct {
		InstallPath string `json:"install_path"`
		Title       string `json:"title"`
		IsDLC       bool   `json:"is_dlc"`
	}
	if err := json.Unmarshal(data, &entries); err != nil {
		return []warning{{
			Path:    path,
			Message: "This Heroic game list could not be parsed; it is skipped.",
		}}
	}

	var warnings []warning
	for _, entry := range entries {
		if entry.IsDLC {
			continue
		}
		appendLauncherGame(games, &warnings, entry.InstallPath, entry.Title, root, "Heroic")
	}
	return warnings
}

func readGOGGames(root string, games *[]game) []warning {
	path := filepath.Join(root, "gog_store", "installed.json")
	data, found, warn := readLauncherFile(path)
	if warn != nil {
		return []warning{*warn}
	}
	if !found {
		return nil
	}

	type entry struct {
		InstallPath string `json:"install_path"`
		Title       string `json:"title"`
	}
	var entries []entry
	trimmed := bytes.TrimSpace(data)
	if len(trimmed) > 0 && trimmed[0] == '[' {
		if err := json.Unmarshal(data, &entries); err != nil {
			return []warning{{
				Path:    path,
				Message: "This Heroic game list could not be parsed; it is skipped.",
			}}
		}
	} else {
		var wrapped struct {
			Installed []entry `json:"installed"`
		}
		if err := json.Unmarshal(data, &wrapped); err != nil {
			return []warning{{
				Path:    path,
				Message: "This Heroic game list could not be parsed; it is skipped.",
			}}
		}
		entries = wrapped.Installed
	}

	var warnings []warning
	for _, game := range entries {
		appendLauncherGame(games, &warnings, game.InstallPath, game.Title, root, "Heroic")
	}
	return warnings
}

func readSideloadGames(root string, games *[]game) []warning {
	path := filepath.Join(root, "sideload_apps", "library.json")
	data, found, warn := readLauncherFile(path)
	if warn != nil {
		return []warning{*warn}
	}
	if !found {
		return nil
	}

	var library struct {
		Games []struct {
			Title       string `json:"title"`
			FolderName  string `json:"folder_name"`
			IsInstalled *bool  `json:"is_installed"`
			Install     struct {
				Executable string `json:"executable"`
			} `json:"install"`
		} `json:"games"`
	}
	if err := json.Unmarshal(data, &library); err != nil {
		return []warning{{
			Path:    path,
			Message: "This Heroic game list could not be parsed; it is skipped.",
		}}
	}

	var warnings []warning
	for _, entry := range library.Games {
		if entry.IsInstalled != nil && !*entry.IsInstalled {
			continue
		}
		dir := strings.TrimSpace(entry.FolderName)
		if dir == "" || !filepath.IsAbs(dir) {
			exe := strings.TrimSpace(entry.Install.Executable)
			if exe == "" || !filepath.IsAbs(exe) {
				continue
			}
			dir = filepath.Dir(exe)
		}
		appendLauncherGame(games, &warnings, dir, entry.Title, root, "Heroic")
	}
	return warnings
}

// lutrisDatabasePaths returns the XDG and native Lutris database locations.
func lutrisDatabasePaths() []string {
	var candidates []string
	if xdg := strings.TrimSpace(os.Getenv("XDG_DATA_HOME")); xdg != "" {
		candidates = append(candidates, filepath.Join(xdg, "lutris", "pga.db"))
	}
	if home := strings.TrimSpace(os.Getenv("HOME")); home != "" {
		candidates = append(candidates,
			filepath.Join(home, ".local", "share", "lutris", "pga.db"),
			filepath.Join(home, ".var", "app", "net.lutris.Lutris", "data", "lutris", "pga.db"),
		)
	}
	var paths []string
	seen := map[string]struct{}{}
	for _, candidate := range candidates {
		candidate = filepath.Clean(candidate)
		if _, ok := seen[candidate]; ok {
			continue
		}
		seen[candidate] = struct{}{}
		if info, err := os.Stat(candidate); err == nil && info.Mode().IsRegular() {
			paths = append(paths, candidate)
		}
	}
	return paths
}

// discoverLutris reads installed games from every Lutris pga.db candidate
// using a read-only connection so a running Lutris instance is not disturbed.
func discoverLutris() launcherDiscovery {
	paths := lutrisDatabasePaths()
	if len(paths) == 0 {
		return launcherDiscovery{
			Readable: true,
			Warnings: []warning{{
				Message: "Lutris is not installed or its game database is not accessible; it is skipped.",
			}},
		}
	}

	discovery := launcherDiscovery{Path: paths[0]}
	for _, dbPath := range paths {
		games, warnings, readable := readLutrisDatabase(dbPath)
		discovery.Warnings = append(discovery.Warnings, warnings...)
		if !readable {
			continue
		}
		discovery.Readable = true
		discovery.Games = append(discovery.Games, games...)
	}
	discovery.Games = dedupeLauncherGames(discovery.Games)
	return discovery
}

// readLutrisDatabase opens one pga.db read-only and returns its installed
// games. The bool is false when the file itself could not be read.
func readLutrisDatabase(dbPath string) ([]game, []warning, bool) {
	u := url.URL{Scheme: "file", Path: dbPath}
	query := u.Query()
	query.Set("mode", "ro")
	u.RawQuery = query.Encode()
	db, err := sql.Open("sqlite", u.String())
	if err != nil {
		return nil, []warning{{
			Path:    dbPath,
			Message: "The Lutris game database could not be opened; it is skipped.",
		}}, false
	}
	defer func() { _ = db.Close() }()
	db.SetMaxOpenConns(1)

	rows, err := db.Query(`SELECT name, directory FROM games WHERE installed = 1`)
	if err != nil {
		return nil, []warning{{
			Path:    dbPath,
			Message: "The Lutris game database could not be read; it is skipped.",
		}}, false
	}
	defer func() { _ = rows.Close() }()

	var games []game
	var warnings []warning
	for rows.Next() {
		var name, directory sql.NullString
		if err := rows.Scan(&name, &directory); err != nil {
			return nil, append(warnings, warning{
				Path:    dbPath,
				Message: "The Lutris game database could not be read; it is skipped.",
			}), false
		}
		appendLauncherGame(&games, &warnings, directory.String, name.String, dbPath, "Lutris")
	}
	if err := rows.Err(); err != nil {
		return nil, append(warnings, warning{
			Path:    dbPath,
			Message: "The Lutris game database could not be read; it is skipped.",
		}), false
	}
	return games, warnings, true
}

// appendLauncherGame validates one manifest row and records it as a game.
func appendLauncherGame(games *[]game, warnings *[]warning, dir, title, libraryRoot, launcher string) {
	dir = strings.TrimSpace(dir)
	if dir == "" || !filepath.IsAbs(dir) {
		return
	}
	info, err := os.Stat(dir)
	if err != nil || !info.IsDir() {
		*warnings = append(*warnings, warning{
			Path:    dir,
			Message: "This " + launcher + " game folder is missing or unreadable; the game is skipped.",
		})
		return
	}
	if err := readableDir(dir); err != nil {
		*warnings = append(*warnings, warning{
			Path:    dir,
			Message: "This " + launcher + " game folder is missing or unreadable; the game is skipped.",
		})
		return
	}
	name := strings.TrimSpace(title)
	if name == "" {
		name = filepath.Base(filepath.Clean(dir))
	}
	*games = append(*games, game{
		Name:        name,
		InstallPath: realPath(dir),
		LibraryRoot: libraryRoot,
	})
}

// dedupeLauncherGames collapses manifests that point at the same physical
// install, preferring an explicit title over a directory basename.
func dedupeLauncherGames(games []game) []game {
	index := map[string]int{}
	out := make([]game, 0, len(games))
	for _, g := range games {
		key := realPath(g.InstallPath)
		if existing, ok := index[key]; ok {
			if out[existing].Name == filepath.Base(out[existing].InstallPath) &&
				g.Name != filepath.Base(g.InstallPath) {
				out[existing].Name = g.Name
			}
			continue
		}
		index[key] = len(out)
		out = append(out, g)
	}
	return out
}

// readLauncherFile reads an optional launcher manifest. A missing file is not
// a warning; an unreadable or malformed file is.
func readLauncherFile(path string) ([]byte, bool, *warning) {
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return nil, false, nil
	}
	if err != nil {
		return nil, true, &warning{
			Path:    path,
			Message: "This Heroic game list could not be read; it is skipped.",
		}
	}
	return data, true, nil
}

// existingDirs keeps the directory candidates that exist, deduplicated by
// cleaned path.
func existingDirs(candidates []string) []string {
	var dirs []string
	seen := map[string]struct{}{}
	for _, candidate := range candidates {
		candidate = filepath.Clean(candidate)
		if _, ok := seen[candidate]; ok {
			continue
		}
		seen[candidate] = struct{}{}
		if info, err := os.Stat(candidate); err == nil && info.IsDir() {
			dirs = append(dirs, candidate)
		}
	}
	return dirs
}
