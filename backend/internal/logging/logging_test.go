package logging

import (
	"context"
	"log/slog"
	"testing"

	"google.golang.org/grpc"
)

// recordingHandler captures records and their accumulated attrs so the test
// can assert structured fields instead of parsing log text.
type recordingHandler struct {
	records *[]slog.Record
	attrs   []slog.Attr
}

func newRecordingHandler() (*recordingHandler, *[]slog.Record) {
	records := &[]slog.Record{}
	return &recordingHandler{records: records}, records
}

func (h *recordingHandler) Enabled(context.Context, slog.Level) bool { return true }

func (h *recordingHandler) Handle(_ context.Context, record slog.Record) error {
	record.AddAttrs(h.attrs...)
	*h.records = append(*h.records, record.Clone())
	return nil
}

func (h *recordingHandler) WithAttrs(attrs []slog.Attr) slog.Handler {
	return &recordingHandler{records: h.records, attrs: append(h.attrs, attrs...)}
}

func (h *recordingHandler) WithGroup(string) slog.Handler { return h }

func attrValue(t *testing.T, record slog.Record, key string) string {
	t.Helper()
	var value string
	record.Attrs(func(attr slog.Attr) bool {
		if attr.Key == key {
			value = attr.Value.String()
			return false
		}
		return true
	})
	return value
}

func TestFromAddsTheOperationID(t *testing.T) {
	handler, records := newRecordingHandler()
	ctx := WithOperationID(context.Background(), "op-123")

	From(ctx, slog.New(handler)).Info("business event", "games", 3)

	if len(*records) != 1 {
		t.Fatalf("records = %d, want 1", len(*records))
	}
	if got := attrValue(t, (*records)[0], "op_id"); got != "op-123" {
		t.Errorf("op_id = %q, want op-123", got)
	}
	if got := attrValue(t, (*records)[0], "games"); got != "3" {
		t.Errorf("games = %q, want 3", got)
	}
}

func TestFromWithoutOperationIDKeepsTheLogger(t *testing.T) {
	handler, records := newRecordingHandler()

	From(context.Background(), slog.New(handler)).Info("business event")

	if len(*records) != 1 {
		t.Fatalf("records = %d, want 1", len(*records))
	}
	if got := attrValue(t, (*records)[0], "op_id"); got != "" {
		t.Errorf("op_id = %q, want none", got)
	}
}

func TestUnaryInterceptorPutsTheOperationIDInTheHandlerContext(t *testing.T) {
	logger := slog.New(slog.DiscardHandler)
	var got string
	_, err := UnaryInterceptor(logger)(
		context.Background(),
		nil,
		&grpc.UnaryServerInfo{FullMethod: "/dlss.v1.Scan/StartScan"},
		func(ctx context.Context, _ any) (any, error) {
			got = OperationID(ctx)
			return nil, nil
		},
	)
	if err != nil {
		t.Fatalf("interceptor: %v", err)
	}
	if got == "" {
		t.Fatal("handler context has no operation id")
	}
}

func TestStreamInterceptorPutsTheOperationIDInTheHandlerContext(t *testing.T) {
	logger := slog.New(slog.DiscardHandler)
	var got string
	stream := &stubStream{ctx: context.Background()}
	err := StreamInterceptor(logger)(
		nil,
		stream,
		&grpc.StreamServerInfo{FullMethod: "/dlss.v1.Scan/StartScan"},
		func(_ any, ss grpc.ServerStream) error {
			got = OperationID(ss.Context())
			return nil
		},
	)
	if err != nil {
		t.Fatalf("interceptor: %v", err)
	}
	if got == "" {
		t.Fatal("handler stream context has no operation id")
	}
	if stream.ctx != context.Background() {
		t.Error("the wrapped stream mutated the original context")
	}
}

// stubStream implements only the embedded method the interceptor needs.
type stubStream struct {
	grpc.ServerStream
	ctx context.Context
}

func (s *stubStream) Context() context.Context { return s.ctx }
