// Package library serves the games and DLLs the last scan persisted.
package library

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	dlssv1 "github.com/Qxy0happy/DLSS-Updater/backend/gen/dlss/v1"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/contract"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/peversion"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/protomap"
	"github.com/Qxy0happy/DLSS-Updater/backend/internal/store"
)

// Server implements dlss.v1.Library on top of the store and the configured DLL
// source directory.
type Server struct {
	dlssv1.UnimplementedLibraryServer

	store     *store.Store
	sourceDir string
}

// NewServer builds the Library service. sourceDir is the daemon's
// --dll-source-dir; it may be empty in tests that never read source versions.
func NewServer(st *store.Store, sourceDir string) *Server {
	return &Server{store: st, sourceDir: sourceDir}
}

// ListGames returns every stored game with its DLLs.
func (s *Server) ListGames(ctx context.Context, _ *dlssv1.ListGamesRequest) (*dlssv1.ListGamesResponse, error) {
	games, err := s.store.ListGames(ctx)
	if err != nil {
		return nil, contract.Detail{Reason: contract.ReasonInternal}.Err("The game list could not be read.")
	}
	sources := s.sourceVersions()
	resp := &dlssv1.ListGamesResponse{Games: make([]*dlssv1.Game, 0, len(games))}
	for _, g := range games {
		protoGame := protomap.Game(g)
		applySourceVersions(protoGame, sources)
		resp.Games = append(resp.Games, protoGame)
	}
	return resp, nil
}

// GetGame returns one stored game with source versions resolved from the
// configured DLL source directory.
func (s *Server) GetGame(ctx context.Context, req *dlssv1.GetGameRequest) (*dlssv1.Game, error) {
	id, err := strconv.ParseInt(strings.TrimSpace(req.GetGameId()), 10, 64)
	if err != nil || id <= 0 {
		return nil, notFound(req.GetGameId())
	}
	g, err := s.store.GetGame(ctx, id)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return nil, notFound(req.GetGameId())
		}
		return nil, contract.Detail{Reason: contract.ReasonInternal}.Err("The game could not be read.")
	}
	protoGame := protomap.Game(g)
	applySourceVersions(protoGame, s.sourceVersions())
	return protoGame, nil
}

func notFound(id string) error {
	return contract.Detail{
		Reason: contract.ReasonTargetMissing,
	}.Err("Game " + strconv.Quote(id) + " was not found.")
}

// sourceVersions maps lower-case filenames in the DLL source directory to the
// version read from that file. A missing or unreadable directory simply means
// no source versions are available.
func (s *Server) sourceVersions() map[string]string {
	versions := map[string]string{}
	if s.sourceDir == "" {
		return versions
	}
	entries, err := os.ReadDir(s.sourceDir)
	if err != nil {
		return versions
	}
	for _, entry := range entries {
		if !entry.Type().IsRegular() {
			continue
		}
		key := strings.ToLower(entry.Name())
		if _, ok := versions[key]; ok {
			continue
		}
		versions[key] = peversion.Read(filepath.Join(s.sourceDir, entry.Name()))
	}
	return versions
}

func applySourceVersions(g *dlssv1.Game, sources map[string]string) {
	for _, dll := range g.GetDlls() {
		if version, ok := sources[strings.ToLower(dll.GetFilename())]; ok {
			dll.SourceVersion = version
		}
	}
}
