package scan

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	dlssv1 "github.com/Qxy0happy/DLSS-Updater/backend/gen/dlss/v1"
)

// sourceKind is the origin a scan unit came from. The wire carries a typed
// ScanSource; this is its internal projection.
type sourceKind uint8

const (
	sourceUnknown sourceKind = iota
	sourceSteam
	sourceCustomFolder
)

// source is one validated-or-rejected request entry. Path may be empty when
// the client sent a variant without its path; planning turns that into a
// warning.
type source struct {
	Kind sourceKind
	Path string
}

// scanUnit is one progress-visible unit of work: a Steam library or one custom
// game folder. Games holds everything planned for the unit before the scan
// starts, so warnings and protected roots are known up front.
type scanUnit struct {
	Kind sourceKind
	// Path is the progress-visible path: a Steam library or a custom folder.
	Path string
	// SourceGroup identifies the ScanSource this unit belongs to; several
	// Steam libraries share one group. SourceIndex/SourceCount are filled
	// after duplicate sources are removed so the UI counts origins.
	SourceGroup int
	SourceIndex int
	SourceCount int
	Library     library
	Games       []game
}

// scanPlan is the fully resolved work list for one scan. Protected holds the
// real paths of every game root that a directory walk must not descend into;
// this is what keeps a shared DLL owned by exactly one game.
type scanPlan struct {
	Units     []scanUnit
	Warnings  []warning
	SteamRoot string
	Protected realPathSet
}

// sourcesFromRequest projects the additive sources field, falling back to the
// legacy single steam_root when sources is empty.
func sourcesFromRequest(req *dlssv1.StartScanRequest) []source {
	if len(req.GetSources()) > 0 {
		sources := make([]source, 0, len(req.GetSources()))
		for _, entry := range req.GetSources() {
			switch {
			case entry.GetSteam() != nil:
				sources = append(sources, source{
					Kind: sourceSteam,
					Path: strings.TrimSpace(entry.GetSteam().GetRoot()),
				})
			case entry.GetCustomFolder() != nil:
				sources = append(sources, source{
					Kind: sourceCustomFolder,
					Path: strings.TrimSpace(entry.GetCustomFolder().GetPath()),
				})
			default:
				sources = append(sources, source{Kind: sourceUnknown})
			}
		}
		return sources
	}
	root := strings.TrimSpace(req.GetSteamRoot())
	if root == "" {
		return nil
	}
	return []source{{Kind: sourceSteam, Path: root}}
}

// buildScanPlan resolves every requested source into scan units. A source that
// cannot be read becomes a warning; only a plan with no units at all is fatal.
func buildScanPlan(ctx context.Context, sources []source) (scanPlan, error) {
	plan := scanPlan{Protected: realPathSet{}}
	seenSteamRoots := realPathSet{}
	readableSources := 0
	nextGroup := 0

	for _, src := range sources {
		switch src.Kind {
		case sourceSteam:
			libraries, warnings, err := discoverLibraries(src.Path)
			plan.Warnings = append(plan.Warnings, warnings...)
			if err != nil {
				plan.Warnings = append(plan.Warnings, warning{
					Path:    src.Path,
					Message: "This Steam folder is missing or unreadable; it is skipped.",
				})
				continue
			}
			readableSources++
			if plan.SteamRoot == "" {
				plan.SteamRoot = filepath.Clean(src.Path)
			}
			group := 0
			for _, lib := range libraries {
				if !seenSteamRoots.add(lib.Root) {
					continue
				}
				if group == 0 {
					nextGroup++
					group = nextGroup
				}
				plan.Units = append(plan.Units, scanUnit{
					Kind:        sourceSteam,
					Path:        lib.Root,
					SourceGroup: group,
					Library:     lib,
				})
			}
		case sourceCustomFolder:
			dir, err := validateCustomFolder(src.Path)
			if err != nil {
				plan.Warnings = append(plan.Warnings, warning{
					Path:    src.Path,
					Message: "This custom folder is missing or unreadable; it is skipped.",
				})
				continue
			}
			readableSources++
			nextGroup++
			installPath := realPath(dir)
			plan.Units = append(plan.Units, scanUnit{
				Kind:        sourceCustomFolder,
				Path:        dir,
				SourceGroup: nextGroup,
				Games: []game{{
					Name:        filepath.Base(dir),
					InstallPath: installPath,
					LibraryRoot: installPath,
				}},
			})
		default:
			plan.Warnings = append(plan.Warnings, warning{
				Message: "This scan source is not supported; it is skipped.",
			})
		}
	}

	// Enumerate Steam libraries before resolving custom folders: a custom
	// folder that overlaps a real Steam game must be recognisable as a
	// duplicate, and the walk needs every Steam game root as a fence.
	for i := range plan.Units {
		unit := &plan.Units[i]
		if unit.Kind != sourceSteam {
			continue
		}
		games, warnings := enumerateGames(ctx, unit.Library)
		plan.Warnings = append(plan.Warnings, warnings...)
		unit.Games = games
		for _, g := range games {
			plan.Protected.add(g.InstallPath)
		}
	}

	custom := make([]scanUnit, 0, len(plan.Units))
	for _, unit := range plan.Units {
		if unit.Kind == sourceCustomFolder {
			custom = append(custom, unit)
		}
	}

	// A custom folder inside a Steam game would create a second game for one
	// physical install and make the same DLL change owners on every scan.
	insideSteam := make([]scanUnit, 0, len(custom))
	for _, unit := range custom {
		if coveredByAny(unit.Path, plan.Protected) {
			plan.Warnings = append(plan.Warnings, warning{
				Path:    unit.Path,
				Message: "This folder is already covered by a Steam game; it is skipped.",
			})
			continue
		}
		insideSteam = append(insideSteam, unit)
	}

	// Equal real paths are the same folder spelled twice; keep the first.
	unique := make([]scanUnit, 0, len(insideSteam))
	seenCustom := realPathSet{}
	for _, unit := range insideSteam {
		if !seenCustom.add(unit.Path) {
			plan.Warnings = append(plan.Warnings, warning{
				Path:    unit.Path,
				Message: "This custom folder is listed twice; the duplicate is skipped.",
			})
			continue
		}
		unique = append(unique, unit)
	}

	// Nested custom folders keep the most specific one. Scanning the parent as
	// well would hand the child's DLLs to whichever game persisted last.
	kept := make([]scanUnit, 0, len(unique))
	for i, unit := range unique {
		covered := false
		for j, other := range unique {
			if i == j {
				continue
			}
			if isStrictDescendant(other.Path, unit.Path) {
				covered = true
				break
			}
		}
		if covered {
			plan.Warnings = append(plan.Warnings, warning{
				Path:    unit.Path,
				Message: "This folder contains another custom folder; only the most specific folder is scanned.",
			})
			continue
		}
		kept = append(kept, unit)
	}

	keptCustomGroups := make(map[int]struct{}, len(kept))
	for _, unit := range kept {
		keptCustomGroups[unit.SourceGroup] = struct{}{}
	}
	units := make([]scanUnit, 0, len(plan.Units))
	for _, unit := range plan.Units {
		if unit.Kind == sourceSteam {
			units = append(units, unit)
			continue
		}
		if _, ok := keptCustomGroups[unit.SourceGroup]; ok {
			units = append(units, unit)
		}
	}

	groupIndex := map[int]int{}
	order := make([]int, 0, readableSources)
	for _, unit := range units {
		if _, ok := groupIndex[unit.SourceGroup]; ok {
			continue
		}
		order = append(order, unit.SourceGroup)
		groupIndex[unit.SourceGroup] = len(order)
	}
	for i := range units {
		units[i].SourceIndex = groupIndex[units[i].SourceGroup]
		units[i].SourceCount = len(order)
	}
	plan.Units = units

	if readableSources == 0 {
		return plan, fmt.Errorf("%w: no scan source could be read", errInvalidRoot)
	}
	return plan, nil
}

// validateCustomFolder accepts an absolute, enumerable directory and returns
// its cleaned form.
func validateCustomFolder(path string) (string, error) {
	path = strings.TrimSpace(path)
	if path == "" || !filepath.IsAbs(path) {
		return "", errors.New("custom folder must be an absolute path")
	}
	info, err := os.Stat(path)
	if err != nil {
		return "", err
	}
	if !info.IsDir() {
		return "", fmt.Errorf("%s is not a directory", path)
	}
	if err := readableDir(path); err != nil {
		return "", err
	}
	return filepath.Clean(path), nil
}

// coveredByAny reports whether path is one of roots or sits below one.
func coveredByAny(path string, roots realPathSet) bool {
	real := realPath(path)
	for root := range roots {
		if real == root || strings.HasPrefix(real, root+string(filepath.Separator)) {
			return true
		}
	}
	return false
}

// isStrictDescendant reports whether path sits below root.
func isStrictDescendant(path, root string) bool {
	real := realPath(path)
	base := realPath(root)
	return real != base && strings.HasPrefix(real, base+string(filepath.Separator))
}
