package update

import (
	"strconv"
	"strings"

	"github.com/Qxy0happy/DLSS-Updater/backend/internal/peversion"
)

// dlssMinimumVersion is the lowest installed nvngx_dlss.dll this sidecar is
// willing to replace. Older builds predate the version scheme the rest of the
// application assumes; the old implementation skipped them too.
const dlssMinimumVersion = "2.0.0"

// dlssFilename is the one catalog file with a minimum-version rule.
const dlssFilename = "nvngx_dlss.dll"

// minimumVersion returns the minimum installed version for filename, and
// whether the file has such a floor at all.
func minimumVersion(filename string) (string, bool) {
	if strings.EqualFold(filename, dlssFilename) {
		return dlssMinimumVersion, true
	}
	return "", false
}

// belowMinimum reports whether the installed version of filename is older than
// its floor. Files without a floor are never below it.
func belowMinimum(filename, version string) bool {
	minimum, ok := minimumVersion(filename)
	if !ok {
		return false
	}
	return compareVersions(version, minimum) < 0
}

// compareVersions orders two version strings the way the old application did:
// commas normalize to dots, only the first three numeric segments matter,
// missing segments are zero and an unparsable version is 0.0.0.
func compareVersions(a, b string) int {
	left, right := versionSegments(a), versionSegments(b)
	for i := range left {
		switch {
		case left[i] < right[i]:
			return -1
		case left[i] > right[i]:
			return 1
		}
	}
	return 0
}

// versionSegments splits a version into its first three numeric segments.
func versionSegments(version string) [3]uint64 {
	var segments [3]uint64
	parts := strings.Split(peversion.Normalize(version), ".")
	for i := 0; i < len(parts) && i < len(segments); i++ {
		segment, err := strconv.ParseUint(parts[i], 10, 64)
		if err != nil {
			// Normalize already rejects non-numeric text; an overflowed
			// segment is treated like any other unparsable version.
			return [3]uint64{}
		}
		segments[i] = segment
	}
	return segments
}
