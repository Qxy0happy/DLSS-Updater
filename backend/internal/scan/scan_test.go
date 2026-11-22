package scan

import (
	"os"
	"path/filepath"
	"testing"
)

func TestParseLibraryFolderPaths(t *testing.T) {
	tests := []struct {
		name string
		data string
		want []string
	}{
		{
			name: "current nested format",
			data: `"libraryfolders"
{
	"0"
	{
		"path"		"/steam"
		"label"		""
	}
	"1"
	{
		"path"		"/games/steam"
		"label"		""
	}
}`,
			want: []string{"/steam", "/games/steam"},
		},
		{
			name: "legacy flat format",
			data: `"libraryfolders"
{
	"1"		"/steam"
	"2"		"/games/steam"
}`,
			want: []string{"/steam", "/games/steam"},
		},
		{
			name: "numeric keys sort numerically",
			data: `"libraryfolders"
{
	"10" { "path" "/ten" }
	"2"  { "path" "/two" }
}`,
			want: []string{"/two", "/ten"},
		},
		{
			name: "entries without a path are skipped",
			data: `"libraryfolders"
{
	"0" { "label" "missing path" }
	"1" { "path" "" }
	"2" { "path" "/games" }
}`,
			want: []string{"/games"},
		},
		{
			name: "empty body",
			data: `"libraryfolders" { }`,
			want: []string{},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := parseLibraryFolderPaths([]byte(tt.data))
			if err != nil {
				t.Fatalf("parseLibraryFolderPaths: %v", err)
			}
			if len(got) != len(tt.want) {
				t.Fatalf("paths = %q, want %q", got, tt.want)
			}
			for i := range tt.want {
				if got[i] != tt.want[i] {
					t.Fatalf("paths = %q, want %q", got, tt.want)
				}
			}
		})
	}
}

func TestParseLibraryFolderPathsRejectsMalformedVDF(t *testing.T) {
	if _, err := parseLibraryFolderPaths([]byte(`"libraryfolders"`)); err == nil {
		t.Fatal("malformed VDF parsed without error")
	}
}

func TestParseAppManifest(t *testing.T) {
	tests := []struct {
		name      string
		data      string
		want      appManifest
		wantOK    bool
		wantError bool
	}{
		{
			name: "full manifest",
			data: `"AppState"
{
	"appid"		"1234"
	"name"		"Example Game"
	"installdir"	"Example Game"
}`,
			want:   appManifest{AppID: 1234, Name: "Example Game", InstallDir: "Example Game"},
			wantOK: true,
		},
		{
			name: "missing name falls back to the app id",
			data: `"AppState"
{
	"appid"		"77"
	"installdir"	"Game"
}`,
			want:   appManifest{AppID: 77, Name: "App 77", InstallDir: "Game"},
			wantOK: true,
		},
		{
			name: "unparsable app id becomes zero",
			data: `"AppState"
{
	"appid"		"not-a-number"
	"name"		"Game"
	"installdir"	"Game"
}`,
			want:   appManifest{Name: "Game", InstallDir: "Game"},
			wantOK: true,
		},
		{
			name: "missing install dir is not usable",
			data: `"AppState"
{
	"appid"		"1"
	"name"		"No install"
}`,
			wantOK: false,
		},
		{
			name:      "malformed",
			data:      `"AppState"`,
			wantError: true,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, ok, err := parseAppManifest([]byte(tt.data))
			if tt.wantError {
				if err == nil {
					t.Fatal("malformed manifest parsed without error")
				}
				return
			}
			if err != nil {
				t.Fatalf("parseAppManifest: %v", err)
			}
			if ok != tt.wantOK {
				t.Fatalf("ok = %v, want %v", ok, tt.wantOK)
			}
			if got != tt.want {
				t.Fatalf("manifest = %+v, want %+v", got, tt.want)
			}
		})
	}
}

func TestSkipDirectory(t *testing.T) {
	for _, name := range []string{
		"__pycache__", ".git", ".svn", ".hg", "node_modules", "logs", "log",
		"saves", "save", "screenshots", "crash", "crashdumps", "dumps", "temp",
		"tmp", "cache", ".cache", "shader_cache", "shadercache", "gpucache", "webcache",
	} {
		if !skipDirectory(name) {
			t.Errorf("skipDirectory(%q) = false, want true", name)
		}
	}
	for _, name := range []string{"bin", "x64", "Game", "DLSS", "Logs2", ""} {
		if skipDirectory(name) {
			t.Errorf("skipDirectory(%q) = true, want false", name)
		}
	}
	if !skipDirectory(".GIT") || !skipDirectory("Node_Modules") {
		t.Error("skipDirectory is not case-insensitive")
	}
}

func TestDLLTypeIsCaseInsensitive(t *testing.T) {
	tests := map[string]string{
		"nvngx_dlss.dll":                 "dlss",
		"NVNGX_DLSS.DLL":                 "dlss",
		"nvngx_dlssg.dll":                "dlss_g",
		"nvngx_dlssd.dll":                "dlss_d",
		"nvngx_dlssnr.dll":               "dlss_nr",
		"libxess.dll":                    "xess",
		"libxess_fg.dll":                 "xess_fg",
		"sl.common.dll":                  "streamline_common",
		"sl.dlss_g.dll":                  "streamline_dlss_g",
		"amd_fidelityfx_vk.dll":          "fsr_vk",
		"amd_fidelityfx_upscaler_vk.dll": "fsr4_upscaler_vk",
	}
	for filename, want := range tests {
		got, ok := dllType(filename)
		if !ok || got != want {
			t.Errorf("dllType(%q) = %q, %v; want %q, true", filename, got, ok, want)
		}
	}
	if _, ok := dllType("foo.dll"); ok {
		t.Error("dllType(foo.dll) reported a known DLL")
	}
}

func TestRealPathSetCollapsesSymlinkedEntries(t *testing.T) {
	root := t.TempDir()
	real := filepath.Join(root, "real")
	if err := os.Mkdir(real, 0o755); err != nil {
		t.Fatal(err)
	}
	link := filepath.Join(root, "link")
	if err := os.Symlink(real, link); err != nil {
		t.Fatal(err)
	}

	seen := realPathSet{}
	if !seen.add(real) {
		t.Fatal("first add reported a duplicate")
	}
	if seen.add(real) {
		t.Fatal("second add of the same path reported new")
	}
	if seen.add(link) {
		t.Fatal("symlink to an already seen directory reported new")
	}
	if seen.add(filepath.Join(real, "..", "real")) {
		t.Fatal("normalized spelling was treated as new")
	}
}

func TestRealPathFallsBackForMissingPaths(t *testing.T) {
	root := t.TempDir()
	missing := filepath.Join(root, "does-not-exist", "..", "still-missing")
	got := realPath(missing)
	want := filepath.Clean(filepath.Join(root, "still-missing"))
	if got != want {
		t.Fatalf("realPath(%q) = %q, want %q", missing, got, want)
	}
}
