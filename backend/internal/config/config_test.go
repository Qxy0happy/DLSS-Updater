package config_test

import (
	"errors"
	"path/filepath"
	"strings"
	"testing"

	"github.com/Qxy0happy/DLSS-Updater/backend/internal/config"
)

func abs(parts ...string) string {
	return filepath.Join(append([]string{"/"}, parts...)...)
}

func TestParse(t *testing.T) {
	valid := []string{
		"--data-dir", abs("data"),
		"--socket", abs("run", "daemon-1.sock"),
		"--dll-source-dir", abs("source"),
	}

	tests := []struct {
		name    string
		args    []string
		want    config.Config
		wantErr error
	}{
		{
			name: "all required flags",
			args: valid,
			want: config.Config{
				DataDir:      abs("data"),
				SocketPath:   abs("run", "daemon-1.sock"),
				DLLSourceDir: abs("source"),
			},
		},
		{
			name:    "missing data dir",
			args:    []string{"--socket", abs("run", "s.sock"), "--dll-source-dir", abs("source")},
			wantErr: config.ErrMissingRequiredFlag,
		},
		{
			name:    "missing socket",
			args:    []string{"--data-dir", abs("data"), "--dll-source-dir", abs("source")},
			wantErr: config.ErrMissingRequiredFlag,
		},
		{
			name:    "missing dll source dir",
			args:    []string{"--data-dir", abs("data"), "--socket", abs("run", "s.sock")},
			wantErr: config.ErrMissingRequiredFlag,
		},
		{
			name:    "blank data dir",
			args:    []string{"--data-dir", "   ", "--socket", abs("run", "s.sock"), "--dll-source-dir", abs("source")},
			wantErr: config.ErrMissingRequiredFlag,
		},
		{
			name:    "relative data dir",
			args:    []string{"--data-dir", "data", "--socket", abs("run", "s.sock"), "--dll-source-dir", abs("source")},
			wantErr: config.ErrPathNotAbsolute,
		},
		{
			name:    "relative socket",
			args:    []string{"--data-dir", abs("data"), "--socket", "run/s.sock", "--dll-source-dir", abs("source")},
			wantErr: config.ErrPathNotAbsolute,
		},
		{
			name:    "relative dll source dir",
			args:    []string{"--data-dir", abs("data"), "--socket", abs("run", "s.sock"), "--dll-source-dir", "source"},
			wantErr: config.ErrPathNotAbsolute,
		},
		{
			name: "socket path too long for sun_path",
			args: []string{
				"--data-dir", abs("data"),
				"--socket", "/" + strings.Repeat("a", config.MaxSocketPathLength),
				"--dll-source-dir", abs("source"),
			},
			wantErr: config.ErrSocketPathTooLong,
		},
		{
			name:    "positional argument",
			args:    append(append([]string{}, valid...), "extra"),
			wantErr: config.ErrUnexpectedArguments,
		},
		{
			name:    "unknown flag",
			args:    append(append([]string{}, valid...), "--unknown=1"),
			wantErr: config.ErrInvalidFlags,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got, err := config.Parse(tc.args)
			if tc.wantErr != nil {
				if !errors.Is(err, tc.wantErr) {
					t.Fatalf("Parse() error = %v, want errors.Is(%v)", err, tc.wantErr)
				}
				if got != (config.Config{}) {
					t.Fatalf("Parse() returned config %+v on error", got)
				}
				return
			}
			if err != nil {
				t.Fatalf("Parse() error = %v", err)
			}
			if got != tc.want {
				t.Fatalf("Parse() = %+v, want %+v", got, tc.want)
			}
		})
	}
}

func TestParseAcceptsLeadingSingleDash(t *testing.T) {
	got, err := config.Parse([]string{
		"-data-dir", abs("data"),
		"-socket", abs("run", "s.sock"),
		"-dll-source-dir", abs("source"),
	})
	if err != nil {
		t.Fatalf("Parse() error = %v", err)
	}
	if got.DataDir != abs("data") {
		t.Fatalf("DataDir = %q", got.DataDir)
	}
}

func TestSocketPathFromEnv(t *testing.T) {
	tests := []struct {
		name       string
		runtimeDir string
		pid        int
		want       string
		wantErr    error
	}{
		{
			name:       "default runtime socket",
			runtimeDir: "/run/user/1000",
			pid:        4242,
			want:       "/run/user/1000/dlss-updater/daemon-4242.sock",
		},
		{
			name:       "unset runtime dir",
			runtimeDir: "",
			pid:        4242,
			wantErr:    config.ErrRuntimeDirUnset,
		},
		{
			name:       "relative runtime dir",
			runtimeDir: "run",
			pid:        4242,
			wantErr:    config.ErrPathNotAbsolute,
		},
		{
			name:       "invalid pid",
			runtimeDir: "/run/user/1000",
			pid:        0,
			wantErr:    config.ErrInvalidPID,
		},
		{
			name:       "long runtime dir overflows sun_path",
			runtimeDir: "/" + strings.Repeat("d", config.MaxSocketPathLength),
			pid:        4242,
			wantErr:    config.ErrSocketPathTooLong,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			getenv := func(key string) string {
				if key != "XDG_RUNTIME_DIR" {
					t.Fatalf("unexpected env lookup %q", key)
				}
				return tc.runtimeDir
			}
			got, err := config.SocketPathFromEnv(getenv, tc.pid)
			if tc.wantErr != nil {
				if !errors.Is(err, tc.wantErr) {
					t.Fatalf("SocketPathFromEnv() error = %v, want errors.Is(%v)", err, tc.wantErr)
				}
				return
			}
			if err != nil {
				t.Fatalf("SocketPathFromEnv() error = %v", err)
			}
			if got != tc.want {
				t.Fatalf("SocketPathFromEnv() = %q, want %q", got, tc.want)
			}
		})
	}
}

func TestDevDataDir(t *testing.T) {
	tests := []struct {
		name    string
		value   string
		want    string
		wantErr error
	}{
		{name: "explicit override", value: "/tmp/dlss-dev-data", want: "/tmp/dlss-dev-data"},
		{name: "unset", value: "", wantErr: config.ErrDataDirUnset},
		{name: "relative", value: "dev-data", wantErr: config.ErrPathNotAbsolute},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			getenv := func(key string) string {
				if key != config.EnvDataDir {
					t.Fatalf("unexpected env lookup %q", key)
				}
				return tc.value
			}
			got, err := config.DevDataDir(getenv)
			if tc.wantErr != nil {
				if !errors.Is(err, tc.wantErr) {
					t.Fatalf("DevDataDir() error = %v, want errors.Is(%v)", err, tc.wantErr)
				}
				return
			}
			if err != nil {
				t.Fatalf("DevDataDir() error = %v", err)
			}
			if got != tc.want {
				t.Fatalf("DevDataDir() = %q, want %q", got, tc.want)
			}
		})
	}
}

func TestValidateSocketPath(t *testing.T) {
	tests := []struct {
		name    string
		path    string
		wantErr error
	}{
		{name: "short absolute path", path: "/tmp/d.sock"},
		{name: "exactly at sun_path limit", path: "/" + strings.Repeat("a", config.MaxSocketPathLength-1)},
		{name: "one byte over sun_path limit", path: "/" + strings.Repeat("a", config.MaxSocketPathLength), wantErr: config.ErrSocketPathTooLong},
		{name: "relative", path: "d.sock", wantErr: config.ErrPathNotAbsolute},
		{name: "empty", path: "", wantErr: config.ErrMissingRequiredFlag},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			err := config.ValidateSocketPath(tc.path)
			if tc.wantErr == nil {
				if err != nil {
					t.Fatalf("ValidateSocketPath(%q) error = %v", tc.path, err)
				}
				return
			}
			if !errors.Is(err, tc.wantErr) {
				t.Fatalf("ValidateSocketPath(%q) error = %v, want errors.Is(%v)", tc.path, err, tc.wantErr)
			}
		})
	}
}
