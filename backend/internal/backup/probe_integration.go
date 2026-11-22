//go:build integration

package backup

import (
	"errors"
	"os"
	"path/filepath"
)

// EnvTestRestoreFailAfterReplace names a DLL base name whose restore fails
// right after the atomic replacement. The switch exists only in binaries built
// with the integration tag; a normal `go build ./cmd/dlssd` compiles probe.go
// instead and has no override at all.
const EnvTestRestoreFailAfterReplace = "DLSS_TEST_RESTORE_FAIL_AFTER_REPLACE"

// postReplaceCheck fails deterministically for the named target so the
// integration suite can prove the safety copy restores the original bytes.
func postReplaceCheck(target string) error {
	want := os.Getenv(EnvTestRestoreFailAfterReplace)
	if want != "" && filepath.Base(target) == want {
		return errors.New("injected post-replace failure")
	}
	return nil
}
