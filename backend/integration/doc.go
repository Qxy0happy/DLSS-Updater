// Package integration holds behavior tests that start the real dlssd binary
// and drive it over a real Unix socket with the generated gRPC client.
//
// Build them with `go test -tags=integration ./...` (make backend-integration).
package integration
