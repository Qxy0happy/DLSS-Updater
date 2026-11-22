package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"
)

// execer is satisfied by *sql.DB and *sql.Tx, so one upsert helper serves
// both the transaction-free and the transactional callers.
type execer interface {
	ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
}

// queryer is satisfied by *sql.DB and *sql.Tx.
type queryer interface {
	QueryContext(ctx context.Context, query string, args ...any) (*sql.Rows, error)
	QueryRowContext(ctx context.Context, query string, args ...any) *sql.Row
}

// The column lists live in one place so a SELECT and its scan helper cannot
// drift apart.
const (
	gameColumns = `id, app_id, name, path, library_path, created_at, last_scanned_at`
	dllColumns  = `id, game_id, dll_type, filename, dll_path, current_version, detected_at, missing_at`
)

// UpsertGame inserts a game or updates the row with the same path. created_at
// is preserved on update; last_scanned_at always moves to ScannedAt.
func (s *Store) UpsertGame(ctx context.Context, in GameInput) (Game, error) {
	if err := upsertGame(ctx, s.db, in); err != nil {
		return Game{}, err
	}
	return s.gameByPath(ctx, in.Path)
}

// upsertGame writes the game row keyed by path. SyncGame calls it inside its
// transaction; UpsertGame uses the pool directly.
func upsertGame(ctx context.Context, q execer, in GameInput) error {
	if in.Path == "" {
		return errors.New("store: game path must not be empty")
	}
	_, err := q.ExecContext(ctx, `
		INSERT INTO games (app_id, name, path, library_path, created_at, last_scanned_at)
		VALUES (?, ?, ?, ?, ?, ?)
		ON CONFLICT(path) DO UPDATE SET
			app_id = excluded.app_id,
			name = excluded.name,
			library_path = excluded.library_path,
			last_scanned_at = excluded.last_scanned_at`,
		int64(in.AppID), in.Name, in.Path, in.LibraryPath, nowMillis(), stamp(in.ScannedAt))
	if err != nil {
		return fmt.Errorf("store: upsert game %s: %w", in.Path, err)
	}
	return nil
}

// UpsertDLL inserts a DLL or updates the row with the same path. Rediscovering
// a file always clears missing_at.
func (s *Store) UpsertDLL(ctx context.Context, in DLLInput) (DLL, error) {
	if err := upsertDLL(ctx, s.db, in); err != nil {
		return DLL{}, err
	}
	return s.dllByPath(ctx, in.Path)
}

func upsertDLL(ctx context.Context, q execer, in DLLInput) error {
	if in.Path == "" {
		return errors.New("store: DLL path must not be empty")
	}
	_, err := q.ExecContext(ctx, `
		INSERT INTO game_dlls (game_id, dll_type, filename, dll_path, current_version, detected_at, missing_at)
		VALUES (?, ?, ?, ?, ?, ?, NULL)
		ON CONFLICT(dll_path) DO UPDATE SET
			game_id = excluded.game_id,
			dll_type = excluded.dll_type,
			filename = excluded.filename,
			current_version = excluded.current_version,
			detected_at = excluded.detected_at,
			missing_at = NULL`,
		in.GameID, in.Type, in.Filename, in.Path, in.Version, stamp(in.DetectedAt))
	if err != nil {
		return fmt.Errorf("store: upsert DLL %s: %w", in.Path, err)
	}
	return nil
}

// ListGames returns every game ordered by name, each with its DLLs.
func (s *Store) ListGames(ctx context.Context) ([]Game, error) {
	games, err := queryGames(ctx, s.db, `
		SELECT `+gameColumns+`
		FROM games
		ORDER BY name COLLATE NOCASE, path`)
	if err != nil {
		return nil, err
	}

	dllsByGame, err := s.allDLLs(ctx)
	if err != nil {
		return nil, err
	}
	for i := range games {
		games[i].DLLs = dllsByGame[games[i].ID]
		if games[i].DLLs == nil {
			games[i].DLLs = []DLL{}
		}
	}
	return games, nil
}

// GetGame returns one game with its DLLs.
func (s *Store) GetGame(ctx context.Context, id int64) (Game, error) {
	g, err := gameByID(ctx, s.db, id)
	if err != nil {
		return Game{}, err
	}
	dlls, err := queryDLLsForGame(ctx, s.db, id)
	if err != nil {
		return Game{}, err
	}
	g.DLLs = dlls
	return g, nil
}

// DeleteGame removes a game; its DLLs, backups and history rows are removed by
// the foreign-key cascades.
func (s *Store) DeleteGame(ctx context.Context, id int64) error {
	res, err := s.db.ExecContext(ctx, `DELETE FROM games WHERE id = ?`, id)
	if err != nil {
		return fmt.Errorf("store: delete game %d: %w", id, err)
	}
	n, err := res.RowsAffected()
	if err != nil {
		return fmt.Errorf("store: delete game %d: %w", id, err)
	}
	if n == 0 {
		return fmt.Errorf("store: game %d: %w", id, ErrNotFound)
	}
	return nil
}

// UpdateDLLVersion records the current on-disk version of a DLL.
func (s *Store) UpdateDLLVersion(ctx context.Context, id int64, version string) error {
	return s.updateDLL(ctx, id,
		`UPDATE game_dlls SET current_version = ? WHERE id = ?`, version, id)
}

// SetDLLMissing marks a DLL as no longer present on disk.
func (s *Store) SetDLLMissing(ctx context.Context, id int64, at time.Time) error {
	return s.updateDLL(ctx, id,
		`UPDATE game_dlls SET missing_at = ? WHERE id = ?`, stamp(at), id)
}

// ClearDLLMissing removes the missing mark without changing the version.
func (s *Store) ClearDLLMissing(ctx context.Context, id int64) error {
	return s.updateDLL(ctx, id,
		`UPDATE game_dlls SET missing_at = NULL WHERE id = ?`, id)
}

func (s *Store) updateDLL(ctx context.Context, id int64, query string, args ...any) error {
	res, err := s.db.ExecContext(ctx, query, args...)
	if err != nil {
		return fmt.Errorf("store: update DLL %d: %w", id, err)
	}
	n, err := res.RowsAffected()
	if err != nil {
		return fmt.Errorf("store: update DLL %d: %w", id, err)
	}
	if n == 0 {
		return fmt.Errorf("store: DLL %d: %w", id, ErrNotFound)
	}
	return nil
}

func (s *Store) gameByPath(ctx context.Context, path string) (Game, error) {
	g, err := queryGame(ctx, s.db,
		`SELECT `+gameColumns+` FROM games WHERE path = ?`, path)
	if err != nil {
		return Game{}, fmt.Errorf("store: read game %s: %w", path, err)
	}
	dlls, err := queryDLLsForGame(ctx, s.db, g.ID)
	if err != nil {
		return Game{}, err
	}
	g.DLLs = dlls
	return g, nil
}

func (s *Store) dllByID(ctx context.Context, id int64) (DLL, error) {
	d, err := queryDLL(ctx, s.db, `SELECT `+dllColumns+` FROM game_dlls WHERE id = ?`, id)
	if errors.Is(err, sql.ErrNoRows) {
		return DLL{}, fmt.Errorf("store: DLL %d: %w", id, ErrNotFound)
	}
	if err != nil {
		return DLL{}, fmt.Errorf("store: get DLL %d: %w", id, err)
	}
	return d, nil
}

func (s *Store) dllByPath(ctx context.Context, path string) (DLL, error) {
	d, err := queryDLL(ctx, s.db,
		`SELECT `+dllColumns+` FROM game_dlls WHERE dll_path = ?`, path)
	if err != nil {
		return DLL{}, fmt.Errorf("store: read DLL %s: %w", path, err)
	}
	return d, nil
}

// gameByID loads one game without its DLLs and maps a missing row to
// ErrNotFound.
func gameByID(ctx context.Context, q queryer, id int64) (Game, error) {
	g, err := queryGame(ctx, q, `SELECT `+gameColumns+` FROM games WHERE id = ?`, id)
	if errors.Is(err, sql.ErrNoRows) {
		return Game{}, fmt.Errorf("store: game %d: %w", id, ErrNotFound)
	}
	if err != nil {
		return Game{}, fmt.Errorf("store: get game %d: %w", id, err)
	}
	return g, nil
}

func queryGame(ctx context.Context, q queryer, query string, args ...any) (Game, error) {
	return scanGame(q.QueryRowContext(ctx, query, args...))
}

// queryGames runs a game SELECT and scans every row.
func queryGames(ctx context.Context, q queryer, query string, args ...any) ([]Game, error) {
	rows, err := q.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("store: list games: %w", err)
	}
	defer rows.Close()

	games := []Game{}
	for rows.Next() {
		g, err := scanGame(rows)
		if err != nil {
			return nil, fmt.Errorf("store: list games: %w", err)
		}
		games = append(games, g)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("store: list games: %w", err)
	}
	return games, nil
}

// queryDLLsForGame returns one game's DLLs in display order.
func queryDLLsForGame(ctx context.Context, q queryer, gameID int64) ([]DLL, error) {
	dlls, err := queryDLLs(ctx, q, `
		SELECT `+dllColumns+`
		FROM game_dlls
		WHERE game_id = ?
		ORDER BY filename COLLATE NOCASE, id`, gameID)
	if err != nil {
		return nil, fmt.Errorf("store: list DLLs of game %d: %w", gameID, err)
	}
	return dlls, nil
}

func (s *Store) allDLLs(ctx context.Context) (map[int64][]DLL, error) {
	dlls, err := queryDLLs(ctx, s.db, `
		SELECT `+dllColumns+`
		FROM game_dlls
		ORDER BY game_id, filename COLLATE NOCASE, id`)
	if err != nil {
		return nil, fmt.Errorf("store: list all DLLs: %w", err)
	}
	byGame := map[int64][]DLL{}
	for _, d := range dlls {
		byGame[d.GameID] = append(byGame[d.GameID], d)
	}
	return byGame, nil
}

// queryDLLs runs a DLL SELECT and scans every row.
func queryDLLs(ctx context.Context, q queryer, query string, args ...any) ([]DLL, error) {
	rows, err := q.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("store: list DLLs: %w", err)
	}
	defer rows.Close()

	dlls := []DLL{}
	for rows.Next() {
		d, err := scanDLL(rows)
		if err != nil {
			return nil, fmt.Errorf("store: list DLLs: %w", err)
		}
		dlls = append(dlls, d)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("store: list DLLs: %w", err)
	}
	return dlls, nil
}

func queryDLL(ctx context.Context, q queryer, query string, args ...any) (DLL, error) {
	return scanDLL(q.QueryRowContext(ctx, query, args...))
}

// scanner is satisfied by *sql.Row and *sql.Rows.
type scanner interface {
	Scan(dest ...any) error
}

func scanGame(sc scanner) (Game, error) {
	var (
		g                    Game
		appID                int64
		createdAt, scannedAt int64
	)
	if err := sc.Scan(&g.ID, &appID, &g.Name, &g.Path, &g.LibraryPath, &createdAt, &scannedAt); err != nil {
		return Game{}, err
	}
	g.AppID = uint32(appID)
	g.CreatedAt = timestamp(createdAt)
	g.LastScannedAt = timestamp(scannedAt)
	return g, nil
}

func scanDLL(sc scanner) (DLL, error) {
	var (
		d         DLL
		detected  int64
		missingAt sql.NullInt64
	)
	if err := sc.Scan(&d.ID, &d.GameID, &d.Type, &d.Filename, &d.Path,
		&d.CurrentVersion, &detected, &missingAt); err != nil {
		return DLL{}, err
	}
	d.DetectedAt = timestamp(detected)
	if missingAt.Valid {
		at := timestamp(missingAt.Int64)
		d.MissingAt = &at
	}
	return d, nil
}
