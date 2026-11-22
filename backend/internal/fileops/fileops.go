// Package fileops contains the filesystem primitives the sidecar uses to
// replace game files, so update and backup share one crash-safe sequence.
package fileops

import (
	"io"
	"os"
	"path/filepath"
)

// AtomicCopy copies srcPath into a temporary file in dstPath's directory,
// flushes it, applies mode, renames it over dstPath and fsyncs the directory.
// Any failure removes the temporary file; dstPath is either untouched or
// completely replaced.
func AtomicCopy(srcPath, dstPath string, mode os.FileMode) error {
	dir := filepath.Dir(dstPath)
	tmp, err := os.CreateTemp(dir, "."+filepath.Base(dstPath)+".tmp-*")
	if err != nil {
		return err
	}
	tmpName := tmp.Name()
	cleanup := func() {
		_ = tmp.Close()
		_ = os.Remove(tmpName)
	}

	src, err := os.Open(srcPath)
	if err != nil {
		cleanup()
		return err
	}
	_, copyErr := io.Copy(tmp, src)
	closeErr := src.Close()
	if copyErr != nil {
		cleanup()
		return copyErr
	}
	if closeErr != nil {
		cleanup()
		return closeErr
	}
	if err := tmp.Chmod(mode.Perm()); err != nil {
		cleanup()
		return err
	}
	if err := tmp.Sync(); err != nil {
		cleanup()
		return err
	}
	if err := tmp.Close(); err != nil {
		_ = os.Remove(tmpName)
		return err
	}
	if err := os.Rename(tmpName, dstPath); err != nil {
		_ = os.Remove(tmpName)
		return err
	}
	return SyncDir(dir)
}

// SafetyCopy duplicates target into a temporary file beside it and returns the
// copy's path. The copy keeps the target's permissions and is flushed, so a
// failed replacement can put the original bytes back. The caller removes the
// copy.
func SafetyCopy(target string, mode os.FileMode) (string, error) {
	dir := filepath.Dir(target)
	tmp, err := os.CreateTemp(dir, "."+filepath.Base(target)+".safety-*")
	if err != nil {
		return "", err
	}
	name := tmp.Name()
	cleanup := func() {
		_ = tmp.Close()
		_ = os.Remove(name)
	}

	src, err := os.Open(target)
	if err != nil {
		cleanup()
		return "", err
	}
	_, copyErr := io.Copy(tmp, src)
	closeErr := src.Close()
	if copyErr != nil {
		cleanup()
		return "", copyErr
	}
	if closeErr != nil {
		cleanup()
		return "", closeErr
	}
	if err := tmp.Chmod(mode.Perm()); err != nil {
		cleanup()
		return "", err
	}
	if err := tmp.Sync(); err != nil {
		cleanup()
		return "", err
	}
	if err := tmp.Close(); err != nil {
		_ = os.Remove(name)
		return "", err
	}
	return name, nil
}

// SyncDir flushes a directory entry so a rename survives a crash.
func SyncDir(dir string) error {
	d, err := os.Open(dir)
	if err != nil {
		return err
	}
	syncErr := d.Sync()
	closeErr := d.Close()
	if syncErr != nil {
		return syncErr
	}
	return closeErr
}

// Exists reports whether path names an existing filesystem entry. An empty
// path is absent rather than the current directory.
func Exists(path string) bool {
	if path == "" {
		return false
	}
	_, err := os.Stat(path)
	return err == nil
}
