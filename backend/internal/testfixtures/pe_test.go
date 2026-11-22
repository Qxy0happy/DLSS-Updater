// Package testfixtures_test verifies the builders with parsers independent
// from the code that wrote the fixtures.
package testfixtures_test

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/Qxy0happy/DLSS-Updater/backend/internal/testfixtures"
	"github.com/saferwall/pe"
)

// versionOptions keeps saferwall/pe's work to what a version read needs.
func versionOptions() *pe.Options {
	return &pe.Options{
		OmitExportDirectory:       true,
		OmitImportDirectory:       true,
		OmitExceptionDirectory:    true,
		OmitSecurityDirectory:     true,
		OmitRelocDirectory:        true,
		OmitDebugDirectory:        true,
		OmitArchitectureDirectory: true,
		OmitGlobalPtrDirectory:    true,
		OmitTLSDirectory:          true,
		OmitLoadConfigDirectory:   true,
		OmitBoundImportDirectory:  true,
		OmitIATDirectory:          true,
		OmitDelayImportDirectory:  true,
		OmitCLRHeaderDirectory:    true,
		OmitCLRMetadata:           true,
	}
}

func readVersion(t *testing.T, path string) poInfo {
	t.Helper()
	f, err := pe.New(path, versionOptions())
	if err != nil {
		t.Fatalf("saferwall/pe.New(%s): %v", path, err)
	}
	defer f.Close()
	if err := f.Parse(); err != nil {
		t.Fatalf("saferwall/pe.Parse(%s): %v", path, err)
	}
	versions, err := f.ParseVersionResources()
	if err != nil {
		t.Fatalf("saferwall/pe.ParseVersionResources(%s): %v", path, err)
	}
	return poInfo{
		is64:           f.Is64,
		machine:        f.NtHeader.FileHeader.Machine,
		fileVersion:    versions["FileVersion"],
		productVersion: versions["ProductVersion"],
	}
}

type poInfo struct {
	is64           bool
	machine        pe.ImageFileHeaderMachineType
	fileVersion    string
	productVersion string
}

func TestWritePEIsReadableWithExpectedVersion(t *testing.T) {
	tests := []struct {
		name    string
		bits    int
		version string
	}{
		{"32-bit below minimum", 32, testfixtures.VersionBelowMinimum},
		{"64-bit at minimum", 64, testfixtures.VersionAtMinimum},
		{"32-bit installed", 32, testfixtures.VersionInstalled},
		{"64-bit update", 64, testfixtures.VersionUpdate},
		{"64-bit newest", 64, testfixtures.VersionNewest},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			dir := t.TempDir()
			path := testfixtures.WritePE(t, dir, "nvngx_dlss.dll", testfixtures.PEOptions{
				Bits:    tt.bits,
				Version: tt.version,
			})
			if got := filepath.Dir(path); got != dir {
				t.Fatalf("WritePE wrote to %q, want %q", got, dir)
			}
			got := readVersion(t, path)
			if got.fileVersion != tt.version {
				t.Errorf("FileVersion = %q, want %q", got.fileVersion, tt.version)
			}
			if got.productVersion != tt.version {
				t.Errorf("ProductVersion = %q, want %q", got.productVersion, tt.version)
			}
			if want64 := tt.bits == 64; got.is64 != want64 {
				t.Errorf("Is64 = %v, want %v", got.is64, want64)
			}
			wantMachine := pe.ImageFileMachineI386
			if tt.bits == 64 {
				wantMachine = pe.ImageFileMachineAMD64
			}
			if got.machine != wantMachine {
				t.Errorf("machine = %#x, want %#x", got.machine, wantMachine)
			}
		})
	}
}

func TestWritePEDefaultsTo64Bit(t *testing.T) {
	dir := t.TempDir()
	path := testfixtures.WritePE(t, dir, "libxess.dll", testfixtures.PEOptions{Version: "2.4.2.0"})
	if got := readVersion(t, path); !got.is64 {
		t.Error("WritePE without Bits produced a 32-bit image")
	}
}

func TestWriteCorruptFileIsNotAValidPE(t *testing.T) {
	dir := t.TempDir()
	path := testfixtures.WriteCorruptFile(t, dir, "nvngx_dlss.dll")

	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read corrupt fixture: %v", err)
	}
	if len(data) == 0 {
		t.Fatal("corrupt fixture is empty")
	}

	f, err := pe.New(path, versionOptions())
	if err == nil {
		defer f.Close()
		if perr := f.Parse(); perr == nil {
			t.Fatal("saferwall/pe parsed the corrupt fixture as a PE")
		}
	}
}
