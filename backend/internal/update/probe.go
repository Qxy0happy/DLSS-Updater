//go:build !integration

package update

import "github.com/Qxy0happy/DLSS-Updater/backend/internal/peversion"

// postReplaceVersion re-reads a target after replacement. Production always
// reads the actual file.
func postReplaceVersion(path string) string { return peversion.Read(path) }
