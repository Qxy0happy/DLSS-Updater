package scan

import (
	"time"

	dlssv1 "github.com/Qxy0happy/DLSS-Updater/backend/gen/dlss/v1"
)

// progressInterval is the minimum time between two coalesced scan progress
// events. The first event, a library change and the final flush are sent
// immediately regardless.
const progressInterval = 200 * time.Millisecond

// progressEmitter coalesces scan progress. A scan that touches hundreds of
// games would otherwise emit one event per game, which no UI can render and
// which makes the stream mostly redundant. The emitter sends the first event
// immediately, drops consecutive duplicates, coalesces later events to the
// newest one within progressInterval, and flushes that pending event before
// the summary so the counters always match finished.
type progressEmitter struct {
	deliver  func(*dlssv1.ScanLibraryProgress) error
	now      func() time.Time
	interval time.Duration

	sent    bool
	last    *dlssv1.ScanLibraryProgress
	lastAt  time.Time
	pending *dlssv1.ScanLibraryProgress
}

func newProgressEmitter(send func(*dlssv1.ScanLibraryProgress) error, now func() time.Time) *progressEmitter {
	return &progressEmitter{deliver: send, now: now, interval: progressInterval}
}

// send offers one progress snapshot. Identical consecutive snapshots are
// dropped; otherwise it is emitted when the library changed, when the
// interval elapsed or when nothing has been sent yet, and kept as the pending
// snapshot in between.
func (e *progressEmitter) send(p *dlssv1.ScanLibraryProgress) error {
	if sameProgress(e.last, p) {
		return nil
	}
	if !e.sent || e.last.GetLibraryPath() != p.GetLibraryPath() ||
		e.now().Sub(e.lastAt) >= e.interval {
		return e.emit(p)
	}
	e.pending = p
	return nil
}

// flush emits the last coalesced snapshot, if any. It is a no-op when every
// snapshot was already emitted.
func (e *progressEmitter) flush() error {
	if e.pending == nil {
		return nil
	}
	pending := e.pending
	e.pending = nil
	return e.emit(pending)
}

func (e *progressEmitter) emit(p *dlssv1.ScanLibraryProgress) error {
	if err := e.deliver(p); err != nil {
		return err
	}
	e.sent = true
	e.last = p
	e.lastAt = e.now()
	e.pending = nil
	return nil
}

func sameProgress(a, b *dlssv1.ScanLibraryProgress) bool {
	if a == nil || b == nil {
		return false
	}
	return a.GetLibraryPath() == b.GetLibraryPath() &&
		a.GetLibraryIndex() == b.GetLibraryIndex() &&
		a.GetLibraryCount() == b.GetLibraryCount() &&
		a.GetCurrentGame() == b.GetCurrentGame() &&
		a.GetGamesFound() == b.GetGamesFound() &&
		a.GetDllsFound() == b.GetDllsFound()
}
