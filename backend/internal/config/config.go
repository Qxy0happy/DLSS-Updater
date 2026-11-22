// Package config validates the explicit paths the frontend passes to dlssd.
//
// The sidecar never guesses a user directory: --data-dir, --socket and
// --dll-source-dir are all required and must be absolute. Everything here is
// pure so the lifecycle ticket can test it without starting a process.
package config

import (
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

// MaxSocketPathLength is the longest usable Linux socket path in bytes.
// sockaddr_un reserves 108 bytes for sun_path including the terminating NUL,
// so the path itself may occupy at most 107 bytes.
const MaxSocketPathLength = 107

// EnvRuntimeDir is the environment variable holding the per-user runtime dir.
const EnvRuntimeDir = "XDG_RUNTIME_DIR"

// EnvDataDir overrides the development data directory.
const EnvDataDir = "DLSS_DATA_DIR"

// Sentinel errors. Callers use errors.Is to tell failures apart; the wrapped
// message names the offending flag or path.
var (
	ErrMissingRequiredFlag = errors.New("missing required flag")
	ErrPathNotAbsolute     = errors.New("path must be absolute")
	ErrSocketPathTooLong   = errors.New("socket path exceeds the sun_path limit")
	ErrUnexpectedArguments = errors.New("unexpected positional arguments")
	ErrInvalidFlags        = errors.New("invalid flags")
	ErrRuntimeDirUnset     = errors.New("XDG_RUNTIME_DIR is not set")
	ErrInvalidPID          = errors.New("pid must be positive")
	ErrDataDirUnset        = errors.New("DLSS_DATA_DIR is not set")
)

// Config is the fully validated set of paths the daemon runs on.
type Config struct {
	DataDir      string
	SocketPath   string
	DLLSourceDir string
}

// LookupFunc reads an environment variable; nil means os.Getenv.
type LookupFunc func(string) string

func lookup(getenv LookupFunc, key string) string {
	if getenv != nil {
		return getenv(key)
	}
	return os.Getenv(key)
}

// Parse parses daemon flags and validates the result.
//
// Both flag spellings (--name and -name) are accepted, matching the rest of
// the repository. On failure the zero Config is returned.
func Parse(args []string) (Config, error) {
	fs := flag.NewFlagSet("dlssd", flag.ContinueOnError)
	fs.SetOutput(io.Discard)

	var cfg Config
	fs.StringVar(&cfg.DataDir, "data-dir", "", "absolute path of the data directory (required)")
	fs.StringVar(&cfg.SocketPath, "socket", "", "absolute path of the Unix socket (required)")
	fs.StringVar(&cfg.DLLSourceDir, "dll-source-dir", "", "absolute path of the DLL source directory (required)")

	if err := fs.Parse(args); err != nil {
		return Config{}, fmt.Errorf("%w: %v", ErrInvalidFlags, err)
	}
	if fs.NArg() > 0 {
		return Config{}, fmt.Errorf("%w: %s", ErrUnexpectedArguments, strings.Join(fs.Args(), " "))
	}
	if err := cfg.Validate(); err != nil {
		return Config{}, err
	}
	return cfg, nil
}

// Validate reports whether every required path is present, absolute and short
// enough for a Unix socket where relevant.
func (c Config) Validate() error {
	for _, field := range []struct {
		flag  string
		value string
	}{
		{"--data-dir", c.DataDir},
		{"--socket", c.SocketPath},
		{"--dll-source-dir", c.DLLSourceDir},
	} {
		if strings.TrimSpace(field.value) == "" {
			return fmt.Errorf("%w: %s", ErrMissingRequiredFlag, field.flag)
		}
		if !filepath.IsAbs(field.value) {
			return fmt.Errorf("%w: %s = %q", ErrPathNotAbsolute, field.flag, field.value)
		}
	}
	return ValidateSocketPath(c.SocketPath)
}

// ValidateSocketPath checks that path is a non-empty absolute path that fits
// in sockaddr_un.sun_path.
func ValidateSocketPath(path string) error {
	if strings.TrimSpace(path) == "" {
		return fmt.Errorf("%w: --socket", ErrMissingRequiredFlag)
	}
	if !filepath.IsAbs(path) {
		return fmt.Errorf("%w: --socket = %q", ErrPathNotAbsolute, path)
	}
	if len(path) > MaxSocketPathLength {
		return fmt.Errorf("%w: %d bytes, limit %d", ErrSocketPathTooLong, len(path), MaxSocketPathLength)
	}
	return nil
}

// SocketPathFromEnv derives the default runtime socket path
// $XDG_RUNTIME_DIR/dlss-updater/daemon-<pid>.sock.
func SocketPathFromEnv(getenv LookupFunc, pid int) (string, error) {
	runtimeDir := lookup(getenv, EnvRuntimeDir)
	if strings.TrimSpace(runtimeDir) == "" {
		return "", fmt.Errorf("%w: %s", ErrRuntimeDirUnset, EnvRuntimeDir)
	}
	return SocketPath(runtimeDir, pid)
}

// SocketPath joins runtimeDir with dlss-updater/daemon-<pid>.sock and validates
// the result against sun_path.
func SocketPath(runtimeDir string, pid int) (string, error) {
	if !filepath.IsAbs(runtimeDir) {
		return "", fmt.Errorf("%w: %s = %q", ErrPathNotAbsolute, EnvRuntimeDir, runtimeDir)
	}
	if pid <= 0 {
		return "", fmt.Errorf("%w: got %d", ErrInvalidPID, pid)
	}
	path := filepath.Join(runtimeDir, "dlss-updater", fmt.Sprintf("daemon-%d.sock", pid))
	if err := ValidateSocketPath(path); err != nil {
		return "", err
	}
	return path, nil
}

// DevDataDir returns DLSS_DATA_DIR as the development data directory override.
// It is never used to guess a production location.
func DevDataDir(getenv LookupFunc) (string, error) {
	value := lookup(getenv, EnvDataDir)
	if strings.TrimSpace(value) == "" {
		return "", fmt.Errorf("%w: %s", ErrDataDirUnset, EnvDataDir)
	}
	if !filepath.IsAbs(value) {
		return "", fmt.Errorf("%w: %s = %q", ErrPathNotAbsolute, EnvDataDir, value)
	}
	return value, nil
}
