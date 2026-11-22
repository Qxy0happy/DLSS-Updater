// This is a generated file - do not edit.
//
// Generated from dlss/v1/common.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart'
    as $0;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// Game is one installed game discovered by a scan.
class Game extends $pb.GeneratedMessage {
  factory Game({
    $core.String? id,
    $core.int? appId,
    $core.String? name,
    $core.String? installPath,
    $core.String? libraryPath,
    $core.Iterable<GameDLL>? dlls,
  }) {
    final result = Game._();
    if (id != null) result.id = id;
    if (appId != null) result.appId = appId;
    if (name != null) result.name = name;
    if (installPath != null) result.installPath = installPath;
    if (libraryPath != null) result.libraryPath = libraryPath;
    if (dlls != null) result.dlls.addAll(dlls);
    return result;
  }

  Game._();

  factory Game.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Game()..mergeFromBuffer(data, registry);
  factory Game.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Game()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Game',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: Game.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aI(2, _omitFieldNames ? '' : 'appId', fieldType: $pb.PbFieldType.OU3)
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aOS(4, _omitFieldNames ? '' : 'installPath')
    ..aOS(5, _omitFieldNames ? '' : 'libraryPath')
    ..pPM<GameDLL>(6, _omitFieldNames ? '' : 'dlls',
        subBuilder: GameDLL.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Game clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Game copyWith(void Function(Game) updates) =>
      super.copyWith((message) => updates(message as Game)) as Game;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Game() / Game.new instead')
  static Game create() => Game._();
  static $pb.GeneratedMessage $_createMessage() => Game._();
  @$core.override
  Game createEmptyInstance() => Game._();
  @$core.pragma('dart2js:noInline')
  static Game getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Game>(Game.$_createMessage);
  static Game? _defaultInstance;

  /// Stable identifier assigned by the sidecar store.
  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  /// Steam app id from the appmanifest; 0 for custom folders and other sources.
  @$pb.TagNumber(2)
  $core.int get appId => $_getIZ(1);
  @$pb.TagNumber(2)
  set appId($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAppId() => $_has(1);
  @$pb.TagNumber(2)
  void clearAppId() => $_clearField(2);

  /// Display name: the appmanifest name for Steam, the launcher title when one
  /// exists, otherwise the game directory basename.
  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  /// Absolute path of the installed game directory.
  @$pb.TagNumber(4)
  $core.String get installPath => $_getSZ(3);
  @$pb.TagNumber(4)
  set installPath($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasInstallPath() => $_has(3);
  @$pb.TagNumber(4)
  void clearInstallPath() => $_clearField(4);

  /// Absolute path of the owning scan source (Steam library root or custom
  /// game folder).
  @$pb.TagNumber(5)
  $core.String get libraryPath => $_getSZ(4);
  @$pb.TagNumber(5)
  set libraryPath($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLibraryPath() => $_has(4);
  @$pb.TagNumber(5)
  void clearLibraryPath() => $_clearField(5);

  /// Known technology DLLs found inside the game directory.
  @$pb.TagNumber(6)
  $pb.PbList<GameDLL> get dlls => $_getList(5);
}

/// GameDLL is one concrete known-technology file inside a game directory.
class GameDLL extends $pb.GeneratedMessage {
  factory GameDLL({
    $core.String? id,
    $core.String? gameId,
    $core.String? dllType,
    $core.String? filename,
    $core.String? path,
    $core.String? currentVersion,
    $core.String? sourceVersion,
    $core.bool? exists,
    $0.Timestamp? missingAt,
  }) {
    final result = GameDLL._();
    if (id != null) result.id = id;
    if (gameId != null) result.gameId = gameId;
    if (dllType != null) result.dllType = dllType;
    if (filename != null) result.filename = filename;
    if (path != null) result.path = path;
    if (currentVersion != null) result.currentVersion = currentVersion;
    if (sourceVersion != null) result.sourceVersion = sourceVersion;
    if (exists != null) result.exists = exists;
    if (missingAt != null) result.missingAt = missingAt;
    return result;
  }

  GameDLL._();

  factory GameDLL.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GameDLL()..mergeFromBuffer(data, registry);
  factory GameDLL.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GameDLL()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GameDLL',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: GameDLL.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'gameId')
    ..aOS(3, _omitFieldNames ? '' : 'dllType')
    ..aOS(4, _omitFieldNames ? '' : 'filename')
    ..aOS(5, _omitFieldNames ? '' : 'path')
    ..aOS(6, _omitFieldNames ? '' : 'currentVersion')
    ..aOS(7, _omitFieldNames ? '' : 'sourceVersion')
    ..aOB(8, _omitFieldNames ? '' : 'exists')
    ..aOM<$0.Timestamp>(9, _omitFieldNames ? '' : 'missingAt',
        subBuilder: $0.Timestamp.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GameDLL clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GameDLL copyWith(void Function(GameDLL) updates) =>
      super.copyWith((message) => updates(message as GameDLL)) as GameDLL;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GameDLL() / GameDLL.new instead')
  static GameDLL create() => GameDLL._();
  static $pb.GeneratedMessage $_createMessage() => GameDLL._();
  @$core.override
  GameDLL createEmptyInstance() => GameDLL._();
  @$core.pragma('dart2js:noInline')
  static GameDLL getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GameDLL>(GameDLL.$_createMessage);
  static GameDLL? _defaultInstance;

  /// Stable identifier assigned by the sidecar store.
  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  /// Identifier of the owning game.
  @$pb.TagNumber(2)
  $core.String get gameId => $_getSZ(1);
  @$pb.TagNumber(2)
  set gameId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasGameId() => $_has(1);
  @$pb.TagNumber(2)
  void clearGameId() => $_clearField(2);

  /// Stable lowercase catalog id, for example "dlss" or "dlss_g".
  @$pb.TagNumber(3)
  $core.String get dllType => $_getSZ(2);
  @$pb.TagNumber(3)
  set dllType($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDllType() => $_has(2);
  @$pb.TagNumber(3)
  void clearDllType() => $_clearField(3);

  /// Base file name, for example "nvngx_dlss.dll".
  @$pb.TagNumber(4)
  $core.String get filename => $_getSZ(3);
  @$pb.TagNumber(4)
  set filename($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasFilename() => $_has(3);
  @$pb.TagNumber(4)
  void clearFilename() => $_clearField(4);

  /// Absolute path of the target file.
  @$pb.TagNumber(5)
  $core.String get path => $_getSZ(4);
  @$pb.TagNumber(5)
  set path($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPath() => $_has(4);
  @$pb.TagNumber(5)
  void clearPath() => $_clearField(5);

  /// Version read from the target PE file, normalized to dotted form.
  /// "0.0.0" when it could not be parsed.
  @$pb.TagNumber(6)
  $core.String get currentVersion => $_getSZ(5);
  @$pb.TagNumber(6)
  set currentVersion($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCurrentVersion() => $_has(5);
  @$pb.TagNumber(6)
  void clearCurrentVersion() => $_clearField(6);

  /// Version of the same file name in the configured DLL source directory.
  /// Empty when no source file exists.
  @$pb.TagNumber(7)
  $core.String get sourceVersion => $_getSZ(6);
  @$pb.TagNumber(7)
  set sourceVersion($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSourceVersion() => $_has(6);
  @$pb.TagNumber(7)
  void clearSourceVersion() => $_clearField(7);

  /// Whether the target file exists on disk right now.
  @$pb.TagNumber(8)
  $core.bool get exists => $_getBF(7);
  @$pb.TagNumber(8)
  set exists($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasExists() => $_has(7);
  @$pb.TagNumber(8)
  void clearExists() => $_clearField(8);

  /// Set when the last scan no longer found the target file.
  @$pb.TagNumber(9)
  $0.Timestamp get missingAt => $_getN(8);
  @$pb.TagNumber(9)
  set missingAt($0.Timestamp value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasMissingAt() => $_has(8);
  @$pb.TagNumber(9)
  void clearMissingAt() => $_clearField(9);
  @$pb.TagNumber(9)
  $0.Timestamp ensureMissingAt() => $_ensure(8);
}

/// BackupRecord describes a `.dlsss` backup file and its bookkeeping row.
class BackupRecord extends $pb.GeneratedMessage {
  factory BackupRecord({
    $core.String? id,
    $core.String? gameId,
    $core.String? dllId,
    $core.String? gameName,
    $core.String? dllFilename,
    $core.String? dllType,
    $core.String? backupPath,
    $core.String? originalVersion,
    $fixnum.Int64? sizeBytes,
    $0.Timestamp? createdAt,
    $core.bool? isActive,
    $0.Timestamp? restoredAt,
    $core.bool? targetExists,
  }) {
    final result = BackupRecord._();
    if (id != null) result.id = id;
    if (gameId != null) result.gameId = gameId;
    if (dllId != null) result.dllId = dllId;
    if (gameName != null) result.gameName = gameName;
    if (dllFilename != null) result.dllFilename = dllFilename;
    if (dllType != null) result.dllType = dllType;
    if (backupPath != null) result.backupPath = backupPath;
    if (originalVersion != null) result.originalVersion = originalVersion;
    if (sizeBytes != null) result.sizeBytes = sizeBytes;
    if (createdAt != null) result.createdAt = createdAt;
    if (isActive != null) result.isActive = isActive;
    if (restoredAt != null) result.restoredAt = restoredAt;
    if (targetExists != null) result.targetExists = targetExists;
    return result;
  }

  BackupRecord._();

  factory BackupRecord.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BackupRecord()..mergeFromBuffer(data, registry);
  factory BackupRecord.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BackupRecord()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BackupRecord',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: BackupRecord.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'gameId')
    ..aOS(3, _omitFieldNames ? '' : 'dllId')
    ..aOS(4, _omitFieldNames ? '' : 'gameName')
    ..aOS(5, _omitFieldNames ? '' : 'dllFilename')
    ..aOS(6, _omitFieldNames ? '' : 'dllType')
    ..aOS(7, _omitFieldNames ? '' : 'backupPath')
    ..aOS(8, _omitFieldNames ? '' : 'originalVersion')
    ..aInt64(9, _omitFieldNames ? '' : 'sizeBytes')
    ..aOM<$0.Timestamp>(10, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $0.Timestamp.$_createMessage)
    ..aOB(11, _omitFieldNames ? '' : 'isActive')
    ..aOM<$0.Timestamp>(12, _omitFieldNames ? '' : 'restoredAt',
        subBuilder: $0.Timestamp.$_createMessage)
    ..aOB(13, _omitFieldNames ? '' : 'targetExists')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupRecord clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupRecord copyWith(void Function(BackupRecord) updates) =>
      super.copyWith((message) => updates(message as BackupRecord))
          as BackupRecord;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use BackupRecord() / BackupRecord.new instead')
  static BackupRecord create() => BackupRecord._();
  static $pb.GeneratedMessage $_createMessage() => BackupRecord._();
  @$core.override
  BackupRecord createEmptyInstance() => BackupRecord._();
  @$core.pragma('dart2js:noInline')
  static BackupRecord getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BackupRecord>(
          BackupRecord.$_createMessage);
  static BackupRecord? _defaultInstance;

  /// Stable identifier assigned by the sidecar store.
  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  /// Identifier of the game the backup belongs to.
  @$pb.TagNumber(2)
  $core.String get gameId => $_getSZ(1);
  @$pb.TagNumber(2)
  set gameId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasGameId() => $_has(1);
  @$pb.TagNumber(2)
  void clearGameId() => $_clearField(2);

  /// Identifier of the GameDLL the backup was taken from.
  @$pb.TagNumber(3)
  $core.String get dllId => $_getSZ(2);
  @$pb.TagNumber(3)
  set dllId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDllId() => $_has(2);
  @$pb.TagNumber(3)
  void clearDllId() => $_clearField(3);

  /// Game display name, copied for display after a rescan.
  @$pb.TagNumber(4)
  $core.String get gameName => $_getSZ(3);
  @$pb.TagNumber(4)
  set gameName($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasGameName() => $_has(3);
  @$pb.TagNumber(4)
  void clearGameName() => $_clearField(4);

  /// Backup file name of the original DLL.
  @$pb.TagNumber(5)
  $core.String get dllFilename => $_getSZ(4);
  @$pb.TagNumber(5)
  set dllFilename($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDllFilename() => $_has(4);
  @$pb.TagNumber(5)
  void clearDllFilename() => $_clearField(5);

  /// Stable lowercase catalog id of the original DLL.
  @$pb.TagNumber(6)
  $core.String get dllType => $_getSZ(5);
  @$pb.TagNumber(6)
  set dllType($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDllType() => $_has(5);
  @$pb.TagNumber(6)
  void clearDllType() => $_clearField(6);

  /// Absolute path of the `.dlsss` backup file.
  @$pb.TagNumber(7)
  $core.String get backupPath => $_getSZ(6);
  @$pb.TagNumber(7)
  set backupPath($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasBackupPath() => $_has(6);
  @$pb.TagNumber(7)
  void clearBackupPath() => $_clearField(7);

  /// Version the target had before the update.
  @$pb.TagNumber(8)
  $core.String get originalVersion => $_getSZ(7);
  @$pb.TagNumber(8)
  set originalVersion($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasOriginalVersion() => $_has(7);
  @$pb.TagNumber(8)
  void clearOriginalVersion() => $_clearField(8);

  /// Size of the backup file in bytes.
  @$pb.TagNumber(9)
  $fixnum.Int64 get sizeBytes => $_getI64(8);
  @$pb.TagNumber(9)
  set sizeBytes($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasSizeBytes() => $_has(8);
  @$pb.TagNumber(9)
  void clearSizeBytes() => $_clearField(9);

  /// When the backup was created.
  @$pb.TagNumber(10)
  $0.Timestamp get createdAt => $_getN(9);
  @$pb.TagNumber(10)
  set createdAt($0.Timestamp value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasCreatedAt() => $_has(9);
  @$pb.TagNumber(10)
  void clearCreatedAt() => $_clearField(10);
  @$pb.TagNumber(10)
  $0.Timestamp ensureCreatedAt() => $_ensure(9);

  /// Whether the backup is still restore-able as the current backup.
  @$pb.TagNumber(11)
  $core.bool get isActive => $_getBF(10);
  @$pb.TagNumber(11)
  set isActive($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(11)
  $core.bool hasIsActive() => $_has(10);
  @$pb.TagNumber(11)
  void clearIsActive() => $_clearField(11);

  /// When the backup was restored, if it ever was.
  @$pb.TagNumber(12)
  $0.Timestamp get restoredAt => $_getN(11);
  @$pb.TagNumber(12)
  set restoredAt($0.Timestamp value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasRestoredAt() => $_has(11);
  @$pb.TagNumber(12)
  void clearRestoredAt() => $_clearField(12);
  @$pb.TagNumber(12)
  $0.Timestamp ensureRestoredAt() => $_ensure(11);

  /// Whether the target DLL still exists on disk. False marks an orphan backup.
  @$pb.TagNumber(13)
  $core.bool get targetExists => $_getBF(12);
  @$pb.TagNumber(13)
  set targetExists($core.bool value) => $_setBool(12, value);
  @$pb.TagNumber(13)
  $core.bool hasTargetExists() => $_has(12);
  @$pb.TagNumber(13)
  void clearTargetExists() => $_clearField(13);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
