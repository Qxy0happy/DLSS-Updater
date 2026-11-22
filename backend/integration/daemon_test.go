//go:build integration

package integration

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"

	dlssv1 "github.com/Qxy0happy/DLSS-Updater/backend/gen/dlss/v1"
)

func TestStatusAndSocketPermissions(t *testing.T) {
	p := newPaths(t)
	s := startSidecar(t, p)
	client, closeClient := dial(t, p.socket)
	defer closeClient()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	status, err := client.GetStatus(ctx, &dlssv1.GetStatusRequest{})
	if err != nil {
		t.Fatalf("GetStatus: %v", err)
	}

	if status.GetProtoVersion() != "dlss.v1" {
		t.Errorf("proto_version = %q, want dlss.v1", status.GetProtoVersion())
	}
	if status.GetAppVersion() == "" {
		t.Error("app_version is empty")
	}
	if got, want := int(status.GetPid()), s.cmd.Process.Pid; got != want {
		t.Errorf("pid = %d, want %d", got, want)
	}
	if status.GetStartTime() == nil {
		t.Error("start_time is missing")
	}
	if status.GetScanRunning() || status.GetUpdateRunning() {
		t.Errorf("fresh daemon reports running work: scan=%v update=%v", status.GetScanRunning(), status.GetUpdateRunning())
	}

	if got, want := fileMode(t, p.socketDir), os.FileMode(0o700); got != want {
		t.Errorf("socket directory mode = %#o, want %#o", got, want)
	}
	if got, want := fileMode(t, p.socket), os.FileMode(0o600); got != want {
		t.Errorf("socket mode = %#o, want %#o", got, want)
	}
	for _, owned := range []string{
		filepath.Join(p.dataDir, "db.sqlite3"),
		filepath.Join(p.dataDir, "logs", "dlssd.log"),
	} {
		if _, err := os.Stat(owned); err != nil {
			t.Errorf("sidecar-owned path %s: %v", owned, err)
		}
	}
}

func TestDataDirIsTightenedToOwnerOnly(t *testing.T) {
	p := newPaths(t)
	// The frontend may create the data directory with a broader umask; the
	// sidecar must tighten it before opening the database.
	p.dataDir = filepath.Join(t.TempDir(), "data")
	if err := os.Mkdir(p.dataDir, 0o755); err != nil {
		t.Fatalf("create data dir: %v", err)
	}
	if err := os.Chmod(p.dataDir, 0o755); err != nil {
		t.Fatalf("widen data dir mode: %v", err)
	}

	startSidecar(t, p)

	if got, want := fileMode(t, p.dataDir), os.FileMode(0o700); got != want {
		t.Errorf("data directory mode = %#o, want %#o", got, want)
	}
}

func TestSecondInstanceRejected(t *testing.T) {
	p := newPaths(t)
	first := startSidecar(t, p)

	// A different socket proves the rejection comes from the data directory
	// lock, not from the socket path.
	second := p
	runtimeDir, err := os.MkdirTemp("", "dlssd-rt-")
	if err != nil {
		t.Fatalf("create second runtime dir: %v", err)
	}
	second.socketDir = runtimeDir
	t.Cleanup(func() { _ = os.RemoveAll(second.socketDir) })
	second.socket = filepath.Join(second.socketDir, "daemon.sock")

	output, err := runSidecar(t, second)
	if err == nil {
		t.Fatalf("second instance exited 0, want ALREADY_RUNNING; output: %s", output)
	}
	if !containsReason(output, "ALREADY_RUNNING") {
		t.Errorf("second instance output lacks ALREADY_RUNNING: %s", output)
	}

	// The first instance must still serve after the rejection.
	status, err := probeStatus(p.socket)
	if err != nil {
		t.Fatalf("first instance stopped serving: %v", err)
	}
	if int(status.GetPid()) != first.cmd.Process.Pid {
		t.Errorf("serving pid = %d, want %d", status.GetPid(), first.cmd.Process.Pid)
	}
}

func TestStaleSocketIsReplaced(t *testing.T) {
	p := newPaths(t)
	if err := os.MkdirAll(filepath.Dir(p.socket), 0o700); err != nil {
		t.Fatalf("create socket dir: %v", err)
	}
	// Bind and close without unlinking: the file left behind is a stale socket.
	stale, err := net.ListenUnix("unix", &net.UnixAddr{Name: p.socket, Net: "unix"})
	if err != nil {
		t.Fatalf("create stale socket: %v", err)
	}
	stale.SetUnlinkOnClose(false)
	if err := stale.Close(); err != nil {
		t.Fatalf("close stale socket: %v", err)
	}
	if info, err := os.Lstat(p.socket); err != nil || info.Mode()&os.ModeSocket == 0 {
		t.Fatalf("stale socket file missing or not a socket: %v", err)
	}

	startSidecar(t, p)
	if _, err := probeStatus(p.socket); err != nil {
		t.Fatalf("daemon did not serve after stale socket cleanup: %v", err)
	}
}

func TestRegularFileAtSocketPathIsNeverDeleted(t *testing.T) {
	p := newPaths(t)
	if err := os.MkdirAll(filepath.Dir(p.socket), 0o700); err != nil {
		t.Fatalf("create socket dir: %v", err)
	}
	const content = "not a socket"
	if err := os.WriteFile(p.socket, []byte(content), 0o600); err != nil {
		t.Fatalf("write regular file: %v", err)
	}

	output, err := runSidecar(t, p)
	if err == nil {
		t.Fatalf("daemon started with a regular file at the socket path; output: %s", output)
	}
	got, readErr := os.ReadFile(p.socket)
	if readErr != nil {
		t.Fatalf("regular file at the socket path was removed: %v", readErr)
	}
	if string(got) != content {
		t.Errorf("regular file content = %q, want %q", got, content)
	}
}

func TestShutdownExitsAndRemovesSocket(t *testing.T) {
	p := newPaths(t)
	s := startSidecar(t, p)
	client, closeClient := dial(t, p.socket)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if _, err := client.Shutdown(ctx, &dlssv1.ShutdownRequest{}); err != nil {
		t.Fatalf("Shutdown: %v", err)
	}
	closeClient()

	if !s.wait(3 * time.Second) {
		t.Fatalf("dlssd did not exit within the shutdown timeout; stderr: %s", s.stderr.String())
	}
	if s.exitErr != nil {
		t.Errorf("dlssd exit: %v; stderr: %s", s.exitErr, s.stderr.String())
	}
	waitFor(t, 2*time.Second, "socket removal", func() bool {
		_, err := os.Lstat(p.socket)
		return errors.Is(err, os.ErrNotExist)
	})

	// The data directory lock must be free again.
	next := p
	nextRuntimeDir, err := os.MkdirTemp("", "dlssd-rt-")
	if err != nil {
		t.Fatalf("create next runtime dir: %v", err)
	}
	next.socketDir = nextRuntimeDir
	t.Cleanup(func() { _ = os.RemoveAll(next.socketDir) })
	next.socket = filepath.Join(next.socketDir, "daemon.sock")
	restarted := startSidecar(t, next)
	if restarted.cmd.Process == nil {
		t.Fatal("restart after shutdown failed")
	}
}

func TestParentDeathLeavesNoOrphan(t *testing.T) {
	p := newPaths(t)
	script := fmt.Sprintf(
		"%q --data-dir %q --socket %q --dll-source-dir %q & echo $!; wait",
		dlssdBinary(t), p.dataDir, p.socket, p.dllSource,
	)
	parent := exec.Command("bash", "-c", script)
	stdout, err := parent.StdoutPipe()
	if err != nil {
		t.Fatalf("stdout pipe: %v", err)
	}
	parent.Stderr = os.Stderr
	if err := parent.Start(); err != nil {
		t.Fatalf("start parent shell: %v", err)
	}

	line, err := bufio.NewReader(stdout).ReadString('\n')
	if err != nil {
		_ = parent.Process.Kill()
		_ = parent.Wait()
		t.Fatalf("read daemon pid: %v", err)
	}
	pid, err := strconv.Atoi(strings.TrimSpace(line))
	if err != nil {
		_ = parent.Process.Kill()
		_ = parent.Wait()
		t.Fatalf("parse daemon pid %q: %v", line, err)
	}
	t.Cleanup(func() {
		_ = syscall.Kill(pid, syscall.SIGKILL)
		_ = parent.Process.Kill()
		_, _ = parent.Process.Wait()
	})

	waitReady(t, p.socket)
	if !processAlive(pid) {
		t.Fatalf("daemon pid %d is not alive after readiness", pid)
	}

	// SIGKILL the parent: only PDEATHSIG can stop the daemon now.
	if err := parent.Process.Kill(); err != nil {
		t.Fatalf("kill parent: %v", err)
	}
	_ = parent.Wait()

	waitFor(t, 5*time.Second, "daemon exit after parent death", func() bool {
		return !processAlive(pid)
	})
	waitFor(t, 2*time.Second, "socket removal after parent death", func() bool {
		_, err := os.Lstat(p.socket)
		return errors.Is(err, os.ErrNotExist)
	})
}
