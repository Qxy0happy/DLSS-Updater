package scan

import (
	"path/filepath"
)

// realPath resolves symlinks so two spellings of the same physical directory
// compare equal (the common ~/.steam/steam -> ~/.local/share/Steam case). A
// path that cannot be resolved falls back to its cleaned absolute form.
func realPath(path string) string {
	if resolved, err := filepath.EvalSymlinks(path); err == nil {
		return filepath.Clean(resolved)
	}
	if abs, err := filepath.Abs(path); err == nil {
		return filepath.Clean(abs)
	}
	return filepath.Clean(path)
}

// realPathSet remembers real paths already visited by one scan.
type realPathSet map[string]struct{}

// add records path and reports whether it was new.
func (s realPathSet) add(path string) bool {
	key := realPath(path)
	if _, ok := s[key]; ok {
		return false
	}
	s[key] = struct{}{}
	return true
}

// has reports whether path's real form is already recorded.
func (s realPathSet) has(path string) bool {
	_, ok := s[realPath(path)]
	return ok
}
