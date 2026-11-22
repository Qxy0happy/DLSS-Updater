package daemon

import (
	"errors"
	"fmt"
	"os"
)

// dataDirMode is the owner-only mode of the data directory.
const dataDirMode os.FileMode = 0o700

// PrepareDataDir creates the data directory when needed and verifies that it is
// a directory. The sidecar never falls back to a guessed user location.
func PrepareDataDir(path string) error {
	if err := os.MkdirAll(path, dataDirMode); err != nil {
		return fmt.Errorf("create data directory %s: %w", path, err)
	}
	info, err := os.Stat(path)
	if err != nil {
		return fmt.Errorf("inspect data directory %s: %w", path, err)
	}
	if !info.IsDir() {
		return fmt.Errorf("data directory %s is not a directory", path)
	}
	// The database contains absolute game paths; keep the directory owner-only
	// even when the frontend created it with a broader umask.
	if err := os.Chmod(path, dataDirMode); err != nil {
		return fmt.Errorf("set mode %#o on data directory %s: %w", dataDirMode, path, err)
	}
	return nil
}

// ValidateDLLSourceDir checks that the explicit DLL source directory exists and
// is a directory. It never creates it: the frontend owns that choice.
func ValidateDLLSourceDir(path string) error {
	info, err := os.Stat(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return fmt.Errorf("DLL source directory %s does not exist", path)
		}
		return fmt.Errorf("inspect DLL source directory %s: %w", path, err)
	}
	if !info.IsDir() {
		return fmt.Errorf("DLL source directory %s is not a directory", path)
	}
	return nil
}
