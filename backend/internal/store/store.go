// Package store persists scanned games, DLLs, backups and update history in
// the sidecar's SQLite database.
//
// The database lives at <data-dir>/db.sqlite3 and is opened with WAL,
// busy_timeout=5000 ms, foreign keys enabled and a single connection. Schema
// v1 is created from an empty data directory; later versions are applied by
// appending to migrations. Timestamps are UTC Unix milliseconds everywhere.
package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"time"

	_ "modernc.org/sqlite"
)

// SchemaVersion is the newest schema this build understands.
const SchemaVersion = 1

// DBFileName is the database file inside the data directory.
const DBFileName = "db.sqlite3"

// ErrNotFound is returned when a requested row does not exist.
var ErrNotFound = errors.New("store: not found")

// Store is the sidecar's SQLite store. It is safe for concurrent use; the
// underlying pool holds a single connection.
type Store struct {
	db   *sql.DB
	path string
}

// Game is one scanned game with its known DLLs.
type Game struct {
	ID            int64
	AppID         uint32
	Name          string
	Path          string
	LibraryPath   string
	CreatedAt     time.Time
	LastScannedAt time.Time
	DLLs          []DLL
}

// DLL is one known-technology file inside a game directory.
type DLL struct {
	ID             int64
	GameID         int64
	Type           string
	Filename       string
	Path           string
	CurrentVersion string
	DetectedAt     time.Time
	// MissingAt is set when the most recent scan no longer found the file.
	MissingAt *time.Time
}

// Backup is one .dlsss backup record.
type Backup struct {
	ID        int64
	GameID    int64
	GameDLLID int64
	GameName  string
	DLLType   string
	// DLLFilename is the original DLL's base name.
	DLLFilename string
	// BackupPath is the .dlsss file.
	BackupPath string
	// TargetPath is the current path of the GameDLL row the backup belongs to.
	TargetPath        string
	OriginalVersion   string
	SizeBytes         int64
	CreatedAt         time.Time
	IsActive          bool
	WasAdded          bool
	RestoredAt        *time.Time
	PostUpdateVersion string
}

// GameInput upserts a game by Path. A zero ScannedAt means now.
type GameInput struct {
	AppID       uint32
	Name        string
	Path        string
	LibraryPath string
	ScannedAt   time.Time
}

// DLLInput upserts a DLL by Path and clears MissingAt. A zero DetectedAt means
// now.
type DLLInput struct {
	GameID     int64
	Type       string
	Filename   string
	Path       string
	Version    string
	DetectedAt time.Time
}

// BackupInput creates an active backup. A zero CreatedAt means now.
type BackupInput struct {
	GameDLLID         int64
	GameName          string
	DLLType           string
	DLLFilename       string
	BackupPath        string
	OriginalVersion   string
	SizeBytes         int64
	WasAdded          bool
	PostUpdateVersion string
	CreatedAt         time.Time
}

// BackupFilter narrows ListBackups. A zero GameID means every game.
type BackupFilter struct {
	GameID          int64
	IncludeInactive bool
}

// Open opens (creating when needed) <dataDir>/db.sqlite3 and applies pending
// migrations. dataDir must be absolute: the sidecar never guesses paths.
func Open(ctx context.Context, dataDir string) (*Store, error) {
	if dataDir == "" {
		return nil, errors.New("store: data directory must not be empty")
	}
	if !filepath.IsAbs(dataDir) {
		return nil, fmt.Errorf("store: data directory %q must be absolute", dataDir)
	}
	if err := os.MkdirAll(dataDir, 0o700); err != nil {
		return nil, fmt.Errorf("store: create data directory %s: %w", dataDir, err)
	}

	dbPath := filepath.Join(dataDir, DBFileName)
	db, err := sql.Open("sqlite", dsn(dbPath))
	if err != nil {
		return nil, fmt.Errorf("store: open %s: %w", dbPath, err)
	}
	// One connection keeps transaction ordering and PRAGMA state obvious; the
	// slice optimises for correctness, not throughput.
	db.SetMaxOpenConns(1)
	db.SetMaxIdleConns(1)
	db.SetConnMaxLifetime(0)

	s := &Store{db: db, path: dbPath}
	if err := s.configure(ctx); err != nil {
		_ = db.Close()
		return nil, err
	}
	if err := s.migrate(ctx); err != nil {
		_ = db.Close()
		return nil, err
	}
	return s, nil
}

// Close closes the database.
func (s *Store) Close() error {
	if s == nil || s.db == nil {
		return nil
	}
	return s.db.Close()
}

func dsn(path string) string {
	u := url.URL{Scheme: "file", Path: path}
	q := u.Query()
	q.Set("_journal_mode", "WAL")
	q.Set("_busy_timeout", "5000")
	q.Set("_foreign_keys", "1")
	u.RawQuery = q.Encode()
	return u.String()
}

// configure verifies the connection-level settings the rest of the store
// depends on instead of assuming the DSN was honoured.
func (s *Store) configure(ctx context.Context) error {
	if err := s.db.PingContext(ctx); err != nil {
		return fmt.Errorf("store: connect %s: %w", s.path, err)
	}
	var journalMode string
	if err := s.db.QueryRowContext(ctx, "PRAGMA journal_mode").Scan(&journalMode); err != nil {
		return fmt.Errorf("store: read journal_mode: %w", err)
	}
	if journalMode != "wal" {
		return fmt.Errorf("store: journal_mode is %q, want wal", journalMode)
	}
	var foreignKeys int
	if err := s.db.QueryRowContext(ctx, "PRAGMA foreign_keys").Scan(&foreignKeys); err != nil {
		return fmt.Errorf("store: read foreign_keys: %w", err)
	}
	if foreignKeys != 1 {
		return fmt.Errorf("store: foreign_keys is %d, want 1", foreignKeys)
	}
	var busyTimeout int
	if err := s.db.QueryRowContext(ctx, "PRAGMA busy_timeout").Scan(&busyTimeout); err != nil {
		return fmt.Errorf("store: read busy_timeout: %w", err)
	}
	if busyTimeout != 5000 {
		return fmt.Errorf("store: busy_timeout is %d, want 5000", busyTimeout)
	}
	return nil
}

const schemaMetaDDL = `CREATE TABLE IF NOT EXISTS schema_meta (
	id INTEGER PRIMARY KEY CHECK (id = 1),
	version INTEGER NOT NULL,
	applied_at INTEGER NOT NULL
)`

// migrations holds one statement list per schema version. Index i upgrades a
// database from version i to i+1.
var migrations = [][]string{
	{
		`CREATE TABLE games (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			app_id INTEGER NOT NULL DEFAULT 0,
			name TEXT NOT NULL,
			path TEXT NOT NULL UNIQUE,
			library_path TEXT NOT NULL,
			created_at INTEGER NOT NULL,
			last_scanned_at INTEGER NOT NULL
		)`,
		`CREATE TABLE game_dlls (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			game_id INTEGER NOT NULL REFERENCES games(id) ON DELETE CASCADE,
			dll_type TEXT NOT NULL,
			filename TEXT NOT NULL,
			dll_path TEXT NOT NULL UNIQUE,
			current_version TEXT NOT NULL,
			detected_at INTEGER NOT NULL,
			missing_at INTEGER
		)`,
		`CREATE INDEX idx_game_dlls_game_id ON game_dlls(game_id)`,
		`CREATE TABLE dll_backups (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			game_dll_id INTEGER NOT NULL REFERENCES game_dlls(id) ON DELETE CASCADE,
			game_name TEXT NOT NULL,
			dll_type TEXT NOT NULL,
			dll_filename TEXT NOT NULL,
			backup_path TEXT NOT NULL,
			original_version TEXT NOT NULL,
			backup_size INTEGER NOT NULL,
			created_at INTEGER NOT NULL,
			is_active INTEGER NOT NULL DEFAULT 1,
			was_added INTEGER NOT NULL DEFAULT 0,
			restored_at INTEGER,
			post_update_version TEXT
		)`,
		`CREATE INDEX idx_dll_backups_game_dll_id ON dll_backups(game_dll_id)`,
		`CREATE INDEX idx_dll_backups_is_active ON dll_backups(is_active)`,
		`CREATE TABLE update_history (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			game_dll_id INTEGER NOT NULL REFERENCES game_dlls(id) ON DELETE CASCADE,
			success INTEGER NOT NULL,
			from_version TEXT NOT NULL,
			to_version TEXT NOT NULL,
			updated_at INTEGER NOT NULL
		)`,
		`CREATE INDEX idx_update_history_game_dll_id ON update_history(game_dll_id)`,
	},
}

func (s *Store) migrate(ctx context.Context) error {
	if _, err := s.db.ExecContext(ctx, schemaMetaDDL); err != nil {
		return fmt.Errorf("store: create schema_meta: %w", err)
	}

	var current int
	err := s.db.QueryRowContext(ctx, `SELECT version FROM schema_meta WHERE id = 1`).Scan(&current)
	switch {
	case errors.Is(err, sql.ErrNoRows):
		current = 0
	case err != nil:
		return fmt.Errorf("store: read schema version: %w", err)
	}
	if current > SchemaVersion {
		return fmt.Errorf("store: database schema version %d is newer than supported version %d", current, SchemaVersion)
	}
	for version := current; version < SchemaVersion; version++ {
		if err := s.applyMigration(ctx, version); err != nil {
			return err
		}
	}
	return nil
}

func (s *Store) applyMigration(ctx context.Context, from int) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("store: begin migration %d: %w", from+1, err)
	}
	defer func() { _ = tx.Rollback() }()

	for _, stmt := range migrations[from] {
		if _, err := tx.ExecContext(ctx, stmt); err != nil {
			return fmt.Errorf("store: migration %d: %w", from+1, err)
		}
	}
	if _, err := tx.ExecContext(ctx, `INSERT INTO schema_meta (id, version, applied_at)
		VALUES (1, ?, ?)
		ON CONFLICT(id) DO UPDATE SET version = excluded.version, applied_at = excluded.applied_at`,
		from+1, nowMillis()); err != nil {
		return fmt.Errorf("store: record schema version %d: %w", from+1, err)
	}
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("store: commit migration %d: %w", from+1, err)
	}
	return nil
}

// nowMillis is the store's clock in UTC Unix milliseconds.
func nowMillis() int64 { return time.Now().UTC().UnixMilli() }

// stamp converts a caller timestamp to UTC Unix milliseconds, defaulting to
// now when the caller left it zero.
func stamp(t time.Time) int64 {
	if t.IsZero() {
		return nowMillis()
	}
	return t.UTC().UnixMilli()
}

// timestamp converts stored UTC Unix milliseconds back to time.Time.
func timestamp(ms int64) time.Time { return time.UnixMilli(ms).UTC() }
