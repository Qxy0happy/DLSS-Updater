package daemon

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strconv"

	"github.com/gofrs/flock"
)

// LockFileName is the single-instance lock inside the data directory.
const LockFileName = "daemon.lock"

// ErrAlreadyRunning means another process holds the data directory lock.
var ErrAlreadyRunning = errors.New("another dlssd instance is using this data directory")

// Lock is an exclusive advisory lock on <data-dir>/daemon.lock. The kernel
// releases it when the process exits, so a crash never leaves a stale lock.
type Lock struct {
	flock *flock.Flock
	path  string
}

// AcquireLock takes the data directory lock without blocking. The second
// instance gets ErrAlreadyRunning instead of waiting or touching the data.
func AcquireLock(dataDir string) (*Lock, error) {
	path := filepath.Join(dataDir, LockFileName)
	fl := flock.New(path)
	locked, err := fl.TryLock()
	if err != nil {
		return nil, fmt.Errorf("lock %s: %w", path, err)
	}
	if !locked {
		return nil, fmt.Errorf("%w: %s", ErrAlreadyRunning, path)
	}
	// The pid is diagnostic only; the lock lives on the open file description.
	if err := os.WriteFile(path, []byte(strconv.Itoa(os.Getpid())+"\n"), 0o600); err != nil {
		_ = fl.Unlock()
		return nil, fmt.Errorf("write lock owner to %s: %w", path, err)
	}
	return &Lock{flock: fl, path: path}, nil
}

// Release drops the lock. The lock file itself stays behind; it never holds
// state of its own.
func (l *Lock) Release() error {
	if l == nil || l.flock == nil {
		return nil
	}
	return l.flock.Unlock()
}
