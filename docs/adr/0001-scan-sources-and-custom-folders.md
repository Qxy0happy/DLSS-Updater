# Scan sources are typed, and one custom folder is one Game

Status: accepted

The v1 scan contract originally accepted a single `steam_root` and enumerated
only appmanifest files. Supporting manually chosen game directories, and later
Heroic and Lutris, required a contract that names each origin without breaking
existing clients. We decided to keep `steam_root` as a legacy fallback and add
`repeated ScanSource sources` with a typed `oneof` (`steam`, `custom_folder`);
`sources` wins when present.

A custom folder is one Game, not a library of games. The scan walks that
directory recursively, names the Game after the basename, and uses the physical
path as identity. Nested custom folders keep the most specific one; a custom
folder inside a Steam game is skipped with a warning. `MergedGame` is retired:
one install path is one Game, even when the same title exists in two places.

We rejected replacing `steam_root` outright (breaks the additive v1 evolution
rule), treating a custom folder as a library (ambiguous Game boundaries and a
poor fit for the ZZZ directory that motivated the change), and the old
`find_game_root` heuristics (unstable results and untestable boundaries).

Consequences: the old `CustomPath1..4` values, which were library roots, map to
one Game each when #9 migrates them; #9 needs a split/adjust path. Per-source
read failures are warnings, and a scan fails only when no source can be read,
so a zero-result scan is never silent. Every scan is full; the database is the
cache, and cancellation keeps the Games already persisted.
