package daemon

import (
	"testing"

	"golang.org/x/sys/unix"
)

// peerAllowed is the only daemon unit left: it is a pure predicate over one
// credential. Socket, lock, data-directory and runtime-state behavior is
// asserted by the integration suite, which drives the real dlssd binary over a
// real Unix socket.
func TestPeerAllowed(t *testing.T) {
	tests := []struct {
		name    string
		cred    *unix.Ucred
		wantErr bool
	}{
		{name: "same uid", cred: &unix.Ucred{Uid: 1000}, wantErr: false},
		{name: "foreign uid", cred: &unix.Ucred{Uid: 1001}, wantErr: true},
		{name: "missing credential", cred: nil, wantErr: true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := peerAllowed(tt.cred, 1000)
			if tt.wantErr && err == nil {
				t.Fatal("peerAllowed accepted the credential")
			}
			if !tt.wantErr && err != nil {
				t.Fatalf("peerAllowed rejected the credential: %v", err)
			}
		})
	}
}
