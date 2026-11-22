// Package streams centralizes the gRPC status mapping every server stream
// uses, so cancellation and write failures mean the same thing everywhere.
package streams

import (
	"context"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// Error maps a failed stream send. A context that is already done becomes the
// matching gRPC status; anything else is an internal stream failure described
// by message.
func Error(ctx context.Context, message string) error {
	if err := ctx.Err(); err != nil {
		return status.FromContextError(err).Err()
	}
	return status.Error(codes.Internal, message)
}

// Cancelled makes one best-effort attempt to deliver the cancelled summary
// through send. A client that cancelled the stream has already closed it, so
// gRPC normally rejects that send; the persisted rows are the durable evidence.
func Cancelled(ctx context.Context, send func() error, message string) error {
	_ = send()
	if err := ctx.Err(); err != nil {
		return status.FromContextError(err).Err()
	}
	return status.Error(codes.Canceled, message)
}
