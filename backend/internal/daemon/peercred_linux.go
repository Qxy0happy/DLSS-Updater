//go:build linux

package daemon

import (
	"errors"
	"fmt"
	"net"
	"sync"
	"time"

	"golang.org/x/sys/unix"
)

const (
	rejectInitialDelay = 10 * time.Millisecond
	rejectMaxDelay     = time.Second
)

// peerCredListener rejects connections whose SO_PEERCRED uid is not the
// daemon's own. Rejections back off exponentially (capped at one second) so a
// hostile client cannot make the accept loop spin; the daemon keeps serving.
type peerCredListener struct {
	net.Listener
	uid uint32

	mu    sync.Mutex
	delay time.Duration
}

func (l *peerCredListener) Accept() (net.Conn, error) {
	for {
		conn, err := l.Listener.Accept()
		if err != nil {
			return nil, err
		}
		uc, ok := conn.(*net.UnixConn)
		if !ok {
			_ = conn.Close()
			l.waitAfterReject()
			continue
		}
		cred, err := peerCredential(uc)
		if err != nil {
			_ = conn.Close()
			l.waitAfterReject()
			continue
		}
		if err := peerAllowed(cred, l.uid); err != nil {
			_ = conn.Close()
			l.waitAfterReject()
			continue
		}
		l.resetDelay()
		return conn, nil
	}
}

func (l *peerCredListener) waitAfterReject() {
	l.mu.Lock()
	if l.delay == 0 {
		l.delay = rejectInitialDelay
	} else if l.delay < rejectMaxDelay {
		l.delay *= 2
		if l.delay > rejectMaxDelay {
			l.delay = rejectMaxDelay
		}
	}
	delay := l.delay
	l.mu.Unlock()
	time.Sleep(delay)
}

func (l *peerCredListener) resetDelay() {
	l.mu.Lock()
	l.delay = 0
	l.mu.Unlock()
}

// peerCredential reads SO_PEERCRED from an accepted Unix connection.
func peerCredential(conn *net.UnixConn) (*unix.Ucred, error) {
	raw, err := conn.SyscallConn()
	if err != nil {
		return nil, err
	}
	var cred *unix.Ucred
	var credErr error
	if err := raw.Control(func(fd uintptr) {
		cred, credErr = unix.GetsockoptUcred(int(fd), unix.SOL_SOCKET, unix.SO_PEERCRED)
	}); err != nil {
		return nil, err
	}
	if credErr != nil {
		return nil, credErr
	}
	if cred == nil {
		return nil, errors.New("peer credential unavailable")
	}
	return cred, nil
}

// peerAllowed is the pure uid decision used by tests.
func peerAllowed(cred *unix.Ucred, uid uint32) error {
	if cred == nil {
		return errors.New("peer credential unavailable")
	}
	if cred.Uid != uid {
		return fmt.Errorf("peer uid %d is not allowed", cred.Uid)
	}
	return nil
}
