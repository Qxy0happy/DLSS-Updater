//go:build integration

package integration

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"syscall"
	"testing"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"

	dlssv1 "github.com/Qxy0happy/DLSS-Updater/backend/gen/dlss/v1"
)

var (
	buildOnce sync.Once
	binary    string
	buildErr  string
)

var (
	taggedBuildOnce sync.Once
	taggedBinary    string
	taggedBuildErr  string
)

func TestMain(m *testing.M) {
	code := m.Run()
	if binary != "" {
		_ = os.RemoveAll(filepath.Dir(binary))
	}
	if taggedBinary != "" {
		_ = os.RemoveAll(filepath.Dir(taggedBinary))
	}
	os.Exit(code)
}

// dlssdBinary builds the real binary once per test run.
func dlssdBinary(t *testing.T) string {
	t.Helper()
	return buildBinary(t, &buildOnce, &binary, &buildErr, nil)
}

// dlssdBinaryTagged builds dlssd with an extra build tag. Only tests that need
// the integration-only test hooks (for example the forced version-mismatch
// rollback) use it; every other test drives the production build.
func dlssdBinaryTagged(t *testing.T, tag string) string {
	t.Helper()
	return buildBinary(t, &taggedBuildOnce, &taggedBinary, &taggedBuildErr, []string{"-tags=" + tag})
}

func buildBinary(t *testing.T, once *sync.Once, target, buildFailure *string, extra []string) string {
	t.Helper()
	once.Do(func() {
		_, file, _, ok := runtime.Caller(0)
		if !ok {
			*buildFailure = "cannot locate the test source file"
			return
		}
		moduleRoot := filepath.Dir(filepath.Dir(file))
		// Release builds and `make build` inject the root VERSION; the test
		// binary must match so `--version` and GetStatus report the same value
		// the acceptance flow checks.
		version, err := os.ReadFile(filepath.Join(filepath.Dir(moduleRoot), "VERSION"))
		if err != nil {
			*buildFailure = fmt.Sprintf("read VERSION: %v", err)
			return
		}
		dir, err := os.MkdirTemp("", "dlssd-build-")
		if err != nil {
			*buildFailure = err.Error()
			return
		}
		out := filepath.Join(dir, "dlssd")
		ldflags := "-X github.com/Qxy0happy/DLSS-Updater/backend/internal/buildinfo.Version=" +
			strings.TrimSpace(string(version))
		args := append([]string{"build", "-trimpath", "-ldflags", ldflags, "-o", out}, extra...)
		args = append(args, "./cmd/dlssd")
		cmd := exec.Command("go", args...)
		cmd.Dir = moduleRoot
		cmd.Env = append(os.Environ(), "CGO_ENABLED=0")
		combined, err := cmd.CombinedOutput()
		if err != nil {
			*buildFailure = fmt.Sprintf("go %s: %v\n%s", strings.Join(args, " "), err, combined)
			_ = os.RemoveAll(dir)
			return
		}
		*target = out
	})
	if *buildFailure != "" {
		t.Fatalf("%s", *buildFailure)
	}
	return *target
}

// paths are the three explicit locations every sidecar test uses. All of them
// live under temporary directories and are removed by the test.
type paths struct {
	dataDir   string
	socketDir string
	socket    string
	dllSource string
}

func newPaths(t *testing.T) paths {
	t.Helper()
	// t.TempDir() names can be long; the socket lives in a short temp dir so
	// the path stays well under sun_path.
	socketDir, err := os.MkdirTemp("", "dlssd-rt-")
	if err != nil {
		t.Fatalf("create runtime temp dir: %v", err)
	}
	t.Cleanup(func() { _ = os.RemoveAll(socketDir) })

	dllSource := filepath.Join(t.TempDir(), "dll-source")
	if err := os.MkdirAll(dllSource, 0o700); err != nil {
		t.Fatalf("create DLL source dir: %v", err)
	}
	return paths{
		dataDir:   t.TempDir(),
		socketDir: socketDir,
		socket:    filepath.Join(socketDir, "daemon.sock"),
		dllSource: dllSource,
	}
}

// args returns the exact command line the frontend uses.
func (p paths) args() []string {
	return []string{
		"--data-dir", p.dataDir,
		"--socket", p.socket,
		"--dll-source-dir", p.dllSource,
	}
}

// sidecar is a running dlssd process.
type sidecar struct {
	cmd     *exec.Cmd
	stderr  bytes.Buffer
	done    chan error
	exited  bool
	exitErr error
}

func startSidecar(t *testing.T, p paths) *sidecar {
	t.Helper()
	return startSidecarWithEnv(t, p, nil)
}

// startSidecarWithEnv starts dlssd built by build with extra environment
// variables, waits for readiness and registers cleanup.
func startSidecarWithEnv(t *testing.T, p paths, env []string, build ...func(*testing.T) string) *sidecar {
	t.Helper()
	var binaryPath string
	if len(build) > 0 {
		binaryPath = build[0](t)
	} else {
		binaryPath = dlssdBinary(t)
	}
	s := launchSidecarBinary(t, binaryPath, p, env)
	t.Cleanup(func() { s.terminate(t) })
	waitReady(t, p.socket)
	return s
}

// launchSidecar starts the process without waiting for readiness.
func launchSidecar(t *testing.T, p paths) *sidecar {
	t.Helper()
	return launchSidecarBinary(t, dlssdBinary(t), p, nil)
}

func launchSidecarBinary(t *testing.T, binaryPath string, p paths, env []string) *sidecar {
	t.Helper()
	s := &sidecar{done: make(chan error, 1)}
	s.cmd = exec.Command(binaryPath, p.args()...)
	s.cmd.Stdout = &s.stderr
	s.cmd.Stderr = &s.stderr
	if len(env) > 0 {
		s.cmd.Env = append(os.Environ(), env...)
	}
	if err := s.cmd.Start(); err != nil {
		t.Fatalf("start dlssd: %v", err)
	}
	go func() { s.done <- s.cmd.Wait() }()
	return s
}

// runSidecar runs the process to completion and returns its combined output.
func runSidecar(t *testing.T, p paths) ([]byte, error) {
	t.Helper()
	cmd := exec.Command(dlssdBinary(t), p.args()...)
	return cmd.CombinedOutput()
}

func (s *sidecar) wait(timeout time.Duration) bool {
	if s.exited {
		return true
	}
	select {
	case s.exitErr = <-s.done:
		s.exited = true
		return true
	case <-time.After(timeout):
		return false
	}
}

func (s *sidecar) terminate(t *testing.T) {
	t.Helper()
	if s.exited || s.cmd.Process == nil {
		return
	}
	_ = s.cmd.Process.Signal(syscall.SIGTERM)
	if s.wait(3 * time.Second) {
		return
	}
	_ = s.cmd.Process.Kill()
	if !s.wait(3 * time.Second) {
		t.Errorf("dlssd pid %d did not exit after SIGKILL", s.cmd.Process.Pid)
	}
}

func waitReady(t *testing.T, socket string) {
	t.Helper()
	deadline := time.Now().Add(10 * time.Second)
	var last error
	for time.Now().Before(deadline) {
		status, err := probeStatus(socket)
		if err == nil && status != nil {
			return
		}
		last = err
		time.Sleep(20 * time.Millisecond)
	}
	t.Fatalf("dlssd did not become ready on %s: %v", socket, last)
}

// dial opens one channel to the sidecar.
func dial(t *testing.T, socket string) (dlssv1.DaemonClient, func()) {
	t.Helper()
	conn, err := grpc.NewClient("unix://"+socket, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		t.Fatalf("grpc.NewClient(%s): %v", socket, err)
	}
	return dlssv1.NewDaemonClient(conn), func() { _ = conn.Close() }
}

func probeStatus(socket string) (*dlssv1.Status, error) {
	conn, err := grpc.NewClient("unix://"+socket, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return nil, err
	}
	defer func() { _ = conn.Close() }()
	ctx, cancel := context.WithTimeout(context.Background(), 300*time.Millisecond)
	defer cancel()
	return dlssv1.NewDaemonClient(conn).GetStatus(ctx, &dlssv1.GetStatusRequest{})
}

func fileMode(t *testing.T, path string) os.FileMode {
	t.Helper()
	info, err := os.Stat(path)
	if err != nil {
		t.Fatalf("stat %s: %v", path, err)
	}
	return info.Mode().Perm()
}

func waitFor(t *testing.T, timeout time.Duration, what string, condition func() bool) {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if condition() {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	t.Fatalf("timed out waiting for %s", what)
}

func processAlive(pid int) bool {
	err := syscall.Kill(pid, 0)
	return err == nil || errors.Is(err, syscall.EPERM)
}

func containsReason(output []byte, reason string) bool {
	return strings.Contains(string(output), reason)
}
