package store

import (
	"context"
	"errors"
	"fmt"
	"time"
)

// SyncGame upserts a game and the DLLs one scan pass discovered for it in a
// single transaction. Previously known DLLs of the same game that are not in
// dlls are marked missing; the first absence time is preserved. DLLInput.GameID
// is ignored (the game row is resolved from game.Path) and a zero DetectedAt
// falls back to scannedAt.
//
// The returned game carries the state committed by the transaction.
func (s *Store) SyncGame(ctx context.Context, game GameInput, dlls []DLLInput, scannedAt time.Time) (Game, error) {
	if game.Path == "" {
		return Game{}, errors.New("store: game path must not be empty")
	}
	if game.ScannedAt.IsZero() {
		game.ScannedAt = scannedAt
	}
	scanned := stamp(game.ScannedAt)

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return Game{}, fmt.Errorf("store: begin sync game %s: %w", game.Path, err)
	}
	defer func() { _ = tx.Rollback() }()

	if err := upsertGame(ctx, tx, game); err != nil {
		return Game{}, fmt.Errorf("store: sync game %s: %w", game.Path, err)
	}

	var gameID int64
	if err := tx.QueryRowContext(ctx, `SELECT id FROM games WHERE path = ?`, game.Path).Scan(&gameID); err != nil {
		return Game{}, fmt.Errorf("store: read synced game %s: %w", game.Path, err)
	}

	known := map[string]int64{}
	rows, err := tx.QueryContext(ctx, `SELECT id, dll_path FROM game_dlls WHERE game_id = ?`, gameID)
	if err != nil {
		return Game{}, fmt.Errorf("store: list known DLLs of game %d: %w", gameID, err)
	}
	for rows.Next() {
		var id int64
		var path string
		if err := rows.Scan(&id, &path); err != nil {
			_ = rows.Close()
			return Game{}, fmt.Errorf("store: list known DLLs of game %d: %w", gameID, err)
		}
		known[path] = id
	}
	if err := rows.Err(); err != nil {
		_ = rows.Close()
		return Game{}, fmt.Errorf("store: list known DLLs of game %d: %w", gameID, err)
	}
	if err := rows.Close(); err != nil {
		return Game{}, fmt.Errorf("store: list known DLLs of game %d: %w", gameID, err)
	}

	discovered := make(map[string]struct{}, len(dlls))
	for _, in := range dlls {
		in.GameID = gameID
		if in.DetectedAt.IsZero() {
			in.DetectedAt = game.ScannedAt
		}
		if err := upsertDLL(ctx, tx, in); err != nil {
			return Game{}, fmt.Errorf("store: sync DLL %s: %w", in.Path, err)
		}
		discovered[in.Path] = struct{}{}
	}

	for path, id := range known {
		if _, ok := discovered[path]; ok {
			continue
		}
		if _, err := tx.ExecContext(ctx, `
			UPDATE game_dlls SET missing_at = COALESCE(missing_at, ?) WHERE id = ?`,
			scanned, id); err != nil {
			return Game{}, fmt.Errorf("store: mark DLL %s missing: %w", path, err)
		}
	}

	synced, err := gameByID(ctx, tx, gameID)
	if err != nil {
		return Game{}, fmt.Errorf("store: read synced game %d: %w", gameID, err)
	}
	synced.DLLs, err = queryDLLsForGame(ctx, tx, gameID)
	if err != nil {
		return Game{}, err
	}

	if err := tx.Commit(); err != nil {
		return Game{}, fmt.Errorf("store: commit sync game %s: %w", game.Path, err)
	}
	return synced, nil
}
