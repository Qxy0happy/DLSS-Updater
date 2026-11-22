package testfixtures

import (
	"os"
	"path/filepath"
	"testing"
)

// DLLSource is a synthetic local DLL source directory, all below one
// t.TempDir().
type DLLSource struct {
	tb      testing.TB
	tmpRoot string
	dir     string
}

// NewDLLSource creates <t.TempDir()>/dll-source.
func NewDLLSource(tb testing.TB) *DLLSource {
	tb.Helper()
	tmp := tb.TempDir()
	dir := filepath.Join(tmp, "dll-source")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		tb.Fatalf("create DLL source dir: %v", err)
	}
	return &DLLSource{tb: tb, tmpRoot: tmp, dir: dir}
}

// TempRoot is the directory every path this builder creates lives under.
func (s *DLLSource) TempRoot() string { return s.tmpRoot }

// Dir is the DLL source directory itself.
func (s *DLLSource) Dir() string { return s.dir }

// Path returns dir/filename without writing anything.
func (s *DLLSource) Path(filename string) string { return filepath.Join(s.dir, filename) }

// Add writes a 64-bit PE named filename with the given version and returns its
// path. The filename case is preserved.
func (s *DLLSource) Add(filename, version string) string {
	s.tb.Helper()
	return WritePE(s.tb, s.dir, filename, PEOptions{Version: version})
}

// Add32 writes a 32-bit PE named filename with the given version.
func (s *DLLSource) Add32(filename, version string) string {
	s.tb.Helper()
	return WritePE(s.tb, s.dir, filename, PEOptions{Bits: 32, Version: version})
}

// AddCorrupt writes a non-PE file named filename.
func (s *DLLSource) AddCorrupt(filename string) string {
	s.tb.Helper()
	return WriteCorruptFile(s.tb, s.dir, filename)
}
