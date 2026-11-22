//go:build linux

package daemon

import "golang.org/x/sys/unix"

// SetParentDeathSignal asks the kernel to deliver SIGTERM to this process when
// its parent dies, so a crashed frontend cannot leave an orphaned sidecar.
func SetParentDeathSignal() error {
	return unix.Prctl(unix.PR_SET_PDEATHSIG, uintptr(unix.SIGTERM), 0, 0, 0)
}
