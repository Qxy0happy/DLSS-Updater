// Package peversion reads the FileVersion resource of a PE image and
// normalizes it for display and comparison.
//
// Unreadable or unparsable files yield "0.0.0": a missing version is data, not
// an error the sidecar should abort a scan over.
package peversion

import (
	"strconv"
	"strings"

	"github.com/saferwall/pe"
)

// Zero is the version recorded when a file cannot be parsed.
const Zero = "0.0.0"

// options disables every directory the version resource does not need. A scan
// reads version resources from many files, so the parse stays minimal.
var options = pe.Options{
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

// Read returns the normalized FileVersion of path, or Zero when the file is
// not a PE image or carries no usable version resource.
func Read(path string) string {
	f, err := pe.New(path, &options)
	if err != nil {
		return Zero
	}
	defer func() { _ = f.Close() }()
	if err := f.Parse(); err != nil {
		return Zero
	}
	versions, err := f.ParseVersionResources()
	if err != nil {
		return Zero
	}
	return Normalize(versions["FileVersion"])
}

// Normalize turns a raw version string into dotted numeric form, accepting the
// comma-separated spelling PE resources often use ("2, 4, 2, 0" -> "2.4.2.0").
// Anything that is not one or more numeric dot- or comma-separated segments
// becomes Zero.
func Normalize(raw string) string {
	trimmed := strings.ReplaceAll(strings.TrimSpace(raw), ",", ".")
	trimmed = strings.ReplaceAll(trimmed, " ", "")
	if trimmed == "" {
		return Zero
	}
	parts := strings.Split(trimmed, ".")
	for _, part := range parts {
		if part == "" {
			return Zero
		}
		if _, err := strconv.ParseUint(part, 10, 64); err != nil {
			return Zero
		}
	}
	return strings.Join(parts, ".")
}
