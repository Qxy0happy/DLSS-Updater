// Package logging writes the sidecar log below <data-dir>/logs and tags every
// RPC with an operation id.
package logging

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/status"
)

// LogFileName is the daemon log inside <data-dir>/logs.
const LogFileName = "dlssd.log"

const logDirMode os.FileMode = 0o700

const logFileMode os.FileMode = 0o600

// Open creates <dataDir>/logs/dlssd.log and returns a JSON slog logger plus a
// closer for the file.
func Open(dataDir string) (*slog.Logger, io.Closer, error) {
	dir := filepath.Join(dataDir, "logs")
	if err := os.MkdirAll(dir, logDirMode); err != nil {
		return nil, nil, fmt.Errorf("create log directory %s: %w", dir, err)
	}
	if err := os.Chmod(dir, logDirMode); err != nil {
		return nil, nil, fmt.Errorf("set mode %#o on log directory %s: %w", logDirMode, dir, err)
	}
	file, err := os.OpenFile(filepath.Join(dir, LogFileName), os.O_CREATE|os.O_WRONLY|os.O_APPEND, logFileMode)
	if err != nil {
		return nil, nil, fmt.Errorf("open log file: %w", err)
	}
	handler := slog.NewJSONHandler(file, &slog.HandlerOptions{Level: slog.LevelInfo})
	return slog.New(handler), file, nil
}

// operationIDKey carries the per-RPC operation id inside the handler context.
type operationIDKey struct{}

// WithOperationID returns ctx carrying opID. Interceptors add it to every RPC;
// business code reads it through [From] instead of threading a logger.
func WithOperationID(ctx context.Context, opID string) context.Context {
	return context.WithValue(ctx, operationIDKey{}, opID)
}

// OperationID returns the operation id stored in ctx, or "" outside an RPC.
func OperationID(ctx context.Context) string {
	id, _ := ctx.Value(operationIDKey{}).(string)
	return id
}

// From returns fallback tagged with the operation id of ctx, so every business
// log line of one RPC shares the interceptor's op_id. A nil fallback uses the
// default logger.
func From(ctx context.Context, fallback *slog.Logger) *slog.Logger {
	if fallback == nil {
		fallback = slog.Default()
	}
	if id := OperationID(ctx); id != "" {
		return fallback.With("op_id", id)
	}
	return fallback
}

// UnaryInterceptor logs one line at the start and one at the end of every
// unary call, correlated by op_id, and puts that id in the handler context.
func UnaryInterceptor(logger *slog.Logger) grpc.UnaryServerInterceptor {
	return func(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
		opID := newOperationID()
		started := time.Now()
		logger.InfoContext(ctx, "rpc started", "op_id", opID, "method", info.FullMethod)
		ctx = WithOperationID(ctx, opID)
		resp, err := handler(ctx, req)
		logger.InfoContext(ctx, "rpc finished",
			"op_id", opID,
			"method", info.FullMethod,
			"duration_ms", time.Since(started).Milliseconds(),
			"code", status.Code(err).String(),
		)
		return resp, err
	}
}

// StreamInterceptor mirrors UnaryInterceptor for the streaming services. The
// wrapped stream carries the operation id to every business log line of the
// handler, including after client cancellation.
func StreamInterceptor(logger *slog.Logger) grpc.StreamServerInterceptor {
	return func(srv any, ss grpc.ServerStream, info *grpc.StreamServerInfo, handler grpc.StreamHandler) error {
		opID := newOperationID()
		started := time.Now()
		logger.InfoContext(ss.Context(), "stream started", "op_id", opID, "method", info.FullMethod)
		wrapped := &contextStream{ServerStream: ss, ctx: WithOperationID(ss.Context(), opID)}
		err := handler(srv, wrapped)
		logger.InfoContext(wrapped.ctx, "stream finished",
			"op_id", opID,
			"method", info.FullMethod,
			"duration_ms", time.Since(started).Milliseconds(),
			"code", status.Code(err).String(),
		)
		return err
	}
}

// contextStream replaces the context a handler observes without changing any
// other stream behavior.
type contextStream struct {
	grpc.ServerStream
	ctx context.Context
}

func (s *contextStream) Context() context.Context { return s.ctx }

// newOperationID returns a random 128-bit hex id, falling back to a timestamp
// when the entropy source is unavailable.
func newOperationID() string {
	var buf [16]byte
	if _, err := rand.Read(buf[:]); err != nil {
		return fmt.Sprintf("t%x", time.Now().UnixNano())
	}
	return hex.EncodeToString(buf[:])
}
