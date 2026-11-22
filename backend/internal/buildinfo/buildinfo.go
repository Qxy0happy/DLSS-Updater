// Package buildinfo carries the version injected at build time.
package buildinfo

// Version is the application version. Release builds set it with
//
//	-ldflags "-X github.com/Qxy0happy/DLSS-Updater/backend/internal/buildinfo.Version=$(VERSION)"
//
// The default keeps `go test` and local `go run` honest when no linker flags
// are supplied.
var Version = "0.0.0-dev"
