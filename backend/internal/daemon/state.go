package daemon

import "sync/atomic"

// RuntimeState is the process-wide operation state reported by
// Daemon.GetStatus. The scan and update services flip the flags while they own
// a run, so a fresh process reports both as idle.
type RuntimeState struct {
	scanRunning   atomic.Bool
	updateRunning atomic.Bool
}

// ScanRunning reports whether a scan is in progress.
func (s *RuntimeState) ScanRunning() bool { return s.scanRunning.Load() }

// SetScanRunning marks a scan as started (true) or finished (false).
func (s *RuntimeState) SetScanRunning(running bool) { s.scanRunning.Store(running) }

// UpdateRunning reports whether an update run is in progress.
func (s *RuntimeState) UpdateRunning() bool { return s.updateRunning.Load() }

// SetUpdateRunning marks an update run as started (true) or finished (false).
func (s *RuntimeState) SetUpdateRunning(running bool) { s.updateRunning.Store(running) }
