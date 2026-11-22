# DLSS Updater

Linux desktop application that discovers games containing DLSS, XeSS, FSR and
Streamline DLLs, updates those files, and keeps restorable backups.

> This is a partial glossary seeded by the scan-behaviour decision (#6). The
> complete v1 domain model and terminology remain owned by #2.

## Language

**Game**:
One physical installation of a game on disk, identified by its install path.
A game installed in two places is two Games.
_Avoid_: Title, entry, merged game

**ScanSource**:
A configured origin that a scan enumerates for Games. A scan can have several
ScanSources, and each contributes Games or a warning.
_Avoid_: Root, path, launcher (unless the source really is a launcher)

**Steam Source**:
A ScanSource that enumerates the libraries of one Steam installation.
_Avoid_: Steam root (when referring to the domain concept)

**Custom Folder**:
A user-chosen game directory that is itself one Game; the scan walks it
recursively for known DLLs.
_Avoid_: Custom path, manual path, custom library

**Launcher**:
Software that installs and starts games and owns the metadata a scan can read
to find their install paths, such as Steam, Heroic or Lutris.
_Avoid_: Store, platform

**MergedGame**:
A retired concept that presented several installed paths as one UI entry. The
current model keeps one Game per install path and has no MergedGame.
_Avoid_: Using it for grouping, display or storage
