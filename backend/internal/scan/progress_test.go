package scan

import (
	"testing"
	"time"

	dlssv1 "github.com/Qxy0happy/DLSS-Updater/backend/gen/dlss/v1"
)

// fakeClock is a deterministic time source for the coalescer.
type fakeClock struct{ at time.Time }

func (c *fakeClock) now() time.Time          { return c.at }
func (c *fakeClock) advance(d time.Duration) { c.at = c.at.Add(d) }

func progressAt(library string, index int32, games, dlls int32, game string) *dlssv1.ScanLibraryProgress {
	return &dlssv1.ScanLibraryProgress{
		LibraryPath:  library,
		LibraryIndex: index,
		LibraryCount: 2,
		CurrentGame:  game,
		GamesFound:   games,
		DllsFound:    dlls,
	}
}

func TestProgressEmitterFirstEventIsImmediateAndDuplicatesAreDropped(t *testing.T) {
	clock := &fakeClock{at: time.Date(2026, 11, 22, 10, 0, 0, 0, time.UTC)}
	var sent []*dlssv1.ScanLibraryProgress
	e := newProgressEmitter(func(p *dlssv1.ScanLibraryProgress) error {
		sent = append(sent, p)
		return nil
	}, clock.now)

	first := progressAt("/steam", 1, 0, 0, "")
	if err := e.send(first); err != nil {
		t.Fatalf("send first: %v", err)
	}
	if len(sent) != 1 {
		t.Fatalf("sent = %d after the first event, want 1", len(sent))
	}
	if err := e.send(progressAt("/steam", 1, 0, 0, "")); err != nil {
		t.Fatalf("send duplicate: %v", err)
	}
	if len(sent) != 1 {
		t.Fatalf("sent = %d after a duplicate, want 1", len(sent))
	}
}

func TestProgressEmitterCoalescesAndFlushesTheNewestSnapshot(t *testing.T) {
	clock := &fakeClock{at: time.Date(2026, 11, 22, 10, 0, 0, 0, time.UTC)}
	var sent []*dlssv1.ScanLibraryProgress
	e := newProgressEmitter(func(p *dlssv1.ScanLibraryProgress) error {
		sent = append(sent, p)
		return nil
	}, clock.now)

	if err := e.send(progressAt("/steam", 1, 0, 0, "")); err != nil {
		t.Fatal(err)
	}
	clock.advance(10 * time.Millisecond)
	if err := e.send(progressAt("/steam", 1, 1, 2, "Game A")); err != nil {
		t.Fatal(err)
	}
	clock.advance(10 * time.Millisecond)
	if err := e.send(progressAt("/steam", 1, 2, 4, "Game B")); err != nil {
		t.Fatal(err)
	}
	if len(sent) != 1 {
		t.Fatalf("sent = %d inside the interval, want only the immediate first event", len(sent))
	}
	if err := e.flush(); err != nil {
		t.Fatalf("flush: %v", err)
	}
	if len(sent) != 2 {
		t.Fatalf("sent = %d after flush, want 2", len(sent))
	}
	if got := sent[1].GetCurrentGame(); got != "Game B" {
		t.Errorf("flushed current_game = %q, want the newest snapshot Game B", got)
	}
	if got := sent[1].GetGamesFound(); got != 2 {
		t.Errorf("flushed games_found = %d, want 2", got)
	}
	if err := e.flush(); err != nil {
		t.Fatal(err)
	}
	if len(sent) != 2 {
		t.Fatalf("sent = %d after a second flush, want 2", len(sent))
	}
}

func TestProgressEmitterSendsAfterIntervalAndOnLibraryChange(t *testing.T) {
	clock := &fakeClock{at: time.Date(2026, 11, 22, 10, 0, 0, 0, time.UTC)}
	var sent []*dlssv1.ScanLibraryProgress
	e := newProgressEmitter(func(p *dlssv1.ScanLibraryProgress) error {
		sent = append(sent, p)
		return nil
	}, clock.now)

	if err := e.send(progressAt("/steam", 1, 0, 0, "")); err != nil {
		t.Fatal(err)
	}
	clock.advance(progressInterval)
	if err := e.send(progressAt("/steam", 1, 1, 1, "Game A")); err != nil {
		t.Fatal(err)
	}
	if len(sent) != 2 {
		t.Fatalf("sent = %d after the interval elapsed, want 2", len(sent))
	}

	// A pending event for the first library is superseded by the second
	// library's start, which is never delayed.
	clock.advance(10 * time.Millisecond)
	if err := e.send(progressAt("/steam", 1, 2, 2, "Game B")); err != nil {
		t.Fatal(err)
	}
	if err := e.send(progressAt("/games", 2, 2, 2, "")); err != nil {
		t.Fatal(err)
	}
	if len(sent) != 3 {
		t.Fatalf("sent = %d after the library changed, want 3", len(sent))
	}
	if got := sent[2].GetLibraryPath(); got != "/games" {
		t.Errorf("last library = %q, want /games", got)
	}
}
