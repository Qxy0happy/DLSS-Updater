# DLSS Updater — Linux rewrite

Linux desktop application for updating **DLSS / XeSS / FSR / Streamline** DLLs in
installed games, with automatic `.dlsss` backups and one-click restore.

This branch contains the Flutter + Go rewrite. The historical Python/Flet
implementation has been removed from the working tree; it remains available in
git history. The current scope is the first end-to-end vertical slice:
controlled scanning of Steam libraries and hand-picked game folders,
single-DLL updates from a local DLL source, backups, restore and delete, with
real progress, cancellation and errors over a private Unix-domain gRPC
contract.

## Architecture

| Layer | Technology | Responsibility |
| --- | --- | --- |
| Frontend | Flutter 3.50 / Dart 3.14, Material 3 | Games, Backups, Settings, connection state; owns the sidecar process |
| Contract | `proto/dlss/v1` | Single source of truth for both stacks; generated code is committed |
| Sidecar | Go 1.27, statically linked `dlssd` | Scan sources, PE versions, atomic replacement, backups, SQLite |
| Transport | gRPC over a private Unix socket | `$XDG_RUNTIME_DIR/dlss-updater/daemon-<pid>.sock`, mode `0600` |

The sidecar never guesses a user directory. The frontend always passes
`--data-dir`, `--socket` and `--dll-source-dir` explicitly.

## Requirements

- Linux with the usual Flutter desktop toolchain (GTK 3, clang, cmake, ninja,
  pkg-config)
- Go 1.27.x
- Flutter 3.50.0 / Dart 3.14.0
- `protoc` 36.1, `protoc-gen-go` 1.36.12, `protoc-gen-go-grpc` 1.6.2,
  `protoc_plugin` 25.1.0

Exact versions and installation checks are in
[`docs/spec-15-runbook.md`](docs/spec-15-runbook.md).

## Build and test

```bash
make codegen-check        # regenerate both stacks and fail on a diff
make backend-test         # Go unit tests
make backend-integration  # real dlssd process over a real Unix socket
make frontend-test        # dart format, flutter analyze, flutter test
make build                # backend/bin/dlssd + Linux release bundle
```

`make run-dev` clears and recreates `build/dev-data` and `build/dev-runtime`,
starts the Flutter app, and lets the app launch the sidecar with those paths.
It never reads the user's real data or Steam library. Stop it with `Ctrl+C` or
by closing the window; the frontend shuts the sidecar down and cleans the socket.

## Repository layout

```
backend/    Go sidecar, generated gRPC code, integration tests
frontend/   Flutter app, generated gRPC code, widget tests
proto/      dlss.v1 contract
fixtures/   synthetic PE and Steam-library fixtures (no real game files)
tools/      code generation entry point
docs/       runbook and engineering notes
```

## Data isolation

- Development runs use repository-local `build/dev-*` directories only.
- Tests use `testing.T.TempDir()` and short-lived runtime directories.
- The app never reads `~/.config/DLSS-Updater` or the legacy application's
  database/backups.
- The daemon holds a `flock` on its data directory, so two writers cannot share
  one database.

## Documentation

- [`docs/spec-15-runbook.md`](docs/spec-15-runbook.md) — toolchain, make targets,
  fixture flow (scan → update → restore → delete), isolation rules, opt-in
  Flutter integration test and known gaps.
- [`proto/dlss/v1`](proto/dlss/v1) — the wire contract and stable error reasons.

## License

AGPL-3.0. See [LICENSE](LICENSE).
