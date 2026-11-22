package scan

import (
	"bytes"
	"sort"
	"strconv"
	"strings"

	"github.com/andygrunwald/vdf"
)

// appManifest is the subset of an appmanifest the scan needs.
type appManifest struct {
	AppID      uint32
	Name       string
	InstallDir string
}

// parseLibraryFolderPaths extracts the library root paths from
// libraryfolders.vdf content. Both the current nested format and the legacy
// flat format (numeric key -> path string) are accepted; entries without a
// usable path are skipped.
func parseLibraryFolderPaths(data []byte) ([]string, error) {
	root, err := vdf.NewParser(bytes.NewReader(data)).Parse()
	if err != nil {
		return nil, err
	}
	body, ok := root["libraryfolders"].(map[string]interface{})
	if !ok {
		body = root
	}

	keys := make([]string, 0, len(body))
	for key := range body {
		keys = append(keys, key)
	}
	sort.Slice(keys, func(i, j int) bool { return keyLess(keys[i], keys[j]) })

	paths := make([]string, 0, len(keys))
	seen := map[string]struct{}{}
	add := func(path string) {
		path = strings.TrimSpace(path)
		if path == "" {
			return
		}
		if _, ok := seen[path]; ok {
			return
		}
		seen[path] = struct{}{}
		paths = append(paths, path)
	}
	for _, key := range keys {
		switch value := body[key].(type) {
		case map[string]interface{}:
			if path, ok := value["path"].(string); ok {
				add(path)
			}
		case string:
			// Legacy format: "libraryfolders" { "1" "/path" }.
			if key == "path" || isDigits(key) {
				add(value)
			}
		}
	}
	return paths, nil
}

// parseAppManifest extracts appid, name and installdir from appmanifest_*.acf
// content. ok is false when the manifest names no install directory, which is
// a manifest this scan cannot use; malformed VDF is an error.
func parseAppManifest(data []byte) (appManifest, bool, error) {
	root, err := vdf.NewParser(bytes.NewReader(data)).Parse()
	if err != nil {
		return appManifest{}, false, err
	}
	state, ok := root["AppState"].(map[string]interface{})
	if !ok {
		state = root
	}

	installDir, _ := state["installdir"].(string)
	installDir = strings.TrimSpace(installDir)
	if installDir == "" {
		return appManifest{}, false, nil
	}

	var appID uint32
	if raw, ok := state["appid"].(string); ok {
		if parsed, err := strconv.ParseUint(strings.TrimSpace(raw), 10, 32); err == nil {
			appID = uint32(parsed)
		}
	}
	name, _ := state["name"].(string)
	name = strings.TrimSpace(name)
	if name == "" {
		name = "App " + strconv.FormatUint(uint64(appID), 10)
	}
	return appManifest{AppID: appID, Name: name, InstallDir: installDir}, true, nil
}

// keyLess orders numeric manifest/library keys numerically so a scan visits
// libraries in the order Steam wrote them, not in lexical order ("10" < "2").
func keyLess(a, b string) bool {
	if isDigits(a) && isDigits(b) {
		ai, aerr := strconv.ParseUint(a, 10, 64)
		bi, berr := strconv.ParseUint(b, 10, 64)
		if aerr == nil && berr == nil {
			return ai < bi
		}
	}
	return a < b
}

func isDigits(s string) bool {
	if s == "" {
		return false
	}
	for _, r := range s {
		if r < '0' || r > '9' {
			return false
		}
	}
	return true
}
