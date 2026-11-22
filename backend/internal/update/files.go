package update

import (
	"os"
	"path/filepath"
	"strings"
)

// backupPathFor returns the .dlsss path beside target. Like the old
// application, the target's extension is replaced rather than appended:
// nvngx_dlss.dll becomes nvngx_dlss.dlsss.
func backupPathFor(target string) string {
	return strings.TrimSuffix(target, filepath.Ext(target)) + ".dlsss"
}

// findSource looks filename up in dir, case-insensitively, and returns the
// first regular file whose base name matches. An unreadable directory simply
// has no sources.
func findSource(dir, filename string) (string, bool) {
	if dir == "" {
		return "", false
	}
	entries, err := os.ReadDir(dir)
	if err != nil {
		return "", false
	}
	for _, entry := range entries {
		if !strings.EqualFold(entry.Name(), filename) {
			continue
		}
		path := filepath.Join(dir, entry.Name())
		info, err := os.Stat(path)
		if err != nil || !info.Mode().IsRegular() {
			continue
		}
		return path, true
	}
	return "", false
}
