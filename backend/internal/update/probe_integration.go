//go:build integration

package update

import (
	"os"
	"path/filepath"

	"github.com/Qxy0happy/DLSS-Updater/backend/internal/peversion"
)

// EnvTestVersionMismatch names a DLL base name whose post-replacement version
// probe deliberately returns a wrong version. The switch exists only in
// binaries built with the integration tag; a normal `go build ./cmd/dlssd`
// compiles probe.go instead and has no override at all.
const EnvTestVersionMismatch = "DLSS_TEST_VERSION_MISMATCH"

// postReplaceVersion re-reads a target after replacement, optionally forcing
// the deterministic verification failure the rollback test needs.
func postReplaceVersion(path string) string {
	if want := os.Getenv(EnvTestVersionMismatch); want != "" && filepath.Base(path) == want {
		return "0.0.0.1"
	}
	return peversion.Read(path)
}
