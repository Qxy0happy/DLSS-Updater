package daemon

import (
	"errors"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"time"

	"github.com/Qxy0happy/DLSS-Updater/backend/internal/config"
)

const (
	// socketDirMode keeps the runtime directory private to the user.
	socketDirMode os.FileMode = 0o700
	// socketFileMode keeps the socket reachable only by the user.
	socketFileMode os.FileMode = 0o600
	// staleProbeTimeout bounds the liveness probe of an existing socket path.
	staleProbeTimeout = 300 * time.Millisecond
)

// ErrSocketInUse means another server still answers on the socket path.
var ErrSocketInUse = errors.New("socket path is already served by another process")

// ErrSocketNotSocket means something that is not a socket occupies the path.
// The daemon must never unlink it.
var ErrSocketNotSocket = errors.New("socket path is occupied by a non-socket file")

// ListenUnix prepares the socket path and returns a listener that enforces
// SO_PEERCRED on every accepted connection.
//
// The parent directory is created owner-only. An existing stale socket is
// removed only after a DialTimeout probe fails; a regular file is never
// unlinked and is reported as an actionable startup error.
func ListenUnix(path string) (net.Listener, error) {
	if err := config.ValidateSocketPath(path); err != nil {
		return nil, err
	}
	if err := prepareSocketPath(path); err != nil {
		return nil, err
	}

	ln, err := net.Listen("unix", path)
	if err != nil {
		return nil, fmt.Errorf("listen on %s: %w", path, err)
	}
	if err := os.Chmod(path, socketFileMode); err != nil {
		_ = ln.Close()
		_ = os.Remove(path)
		return nil, fmt.Errorf("set mode %#o on %s: %w", socketFileMode, path, err)
	}
	return &peerCredListener{Listener: ln, uid: uint32(os.Geteuid())}, nil
}

// prepareSocketPath creates the parent directory and clears a stale socket.
func prepareSocketPath(path string) error {
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, socketDirMode); err != nil {
		return fmt.Errorf("create socket directory %s: %w", dir, err)
	}
	if err := os.Chmod(dir, socketDirMode); err != nil {
		return fmt.Errorf("set mode %#o on socket directory %s: %w", socketDirMode, dir, err)
	}

	info, err := os.Lstat(path)
	switch {
	case errors.Is(err, os.ErrNotExist):
		return nil
	case err != nil:
		return fmt.Errorf("inspect socket path %s: %w", path, err)
	}
	if info.Mode()&os.ModeSocket == 0 {
		return fmt.Errorf("%w: %s; remove it yourself if it is safe", ErrSocketNotSocket, path)
	}
	conn, dialErr := net.DialTimeout("unix", path, staleProbeTimeout)
	if dialErr == nil {
		_ = conn.Close()
		return fmt.Errorf("%w: %s", ErrSocketInUse, path)
	}
	if err := os.Remove(path); err != nil {
		return fmt.Errorf("remove stale socket %s: %w", path, err)
	}
	return nil
}

// CleanupSocket removes path only when it still is a socket, so a regular file
// placed there after startup is never deleted by the daemon's exit path.
func CleanupSocket(path string) error {
	info, err := os.Lstat(path)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	if info.Mode()&os.ModeSocket == 0 {
		return nil
	}
	if err := os.Remove(path); err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	return nil
}
