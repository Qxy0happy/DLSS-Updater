// This is a generated file - do not edit.
//
// Generated from dlss/v1/scan.proto.

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
    as $2;

import 'common.pb.dart' as $1;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class StartScanRequest extends $pb.GeneratedMessage {
  factory StartScanRequest({
    $core.String? steamRoot,
    $core.Iterable<ScanSource>? sources,
  }) {
    final result = StartScanRequest._();
    if (steamRoot != null) result.steamRoot = steamRoot;
    if (sources != null) result.sources.addAll(sources);
    return result;
  }

  StartScanRequest._();

  factory StartScanRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StartScanRequest()..mergeFromBuffer(data, registry);
  factory StartScanRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StartScanRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StartScanRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: StartScanRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'steamRoot')
    ..pPM<ScanSource>(2, _omitFieldNames ? '' : 'sources',
        subBuilder: ScanSource.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StartScanRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StartScanRequest copyWith(void Function(StartScanRequest) updates) =>
      super.copyWith((message) => updates(message as StartScanRequest))
          as StartScanRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use StartScanRequest() / StartScanRequest.new instead')
  static StartScanRequest create() => StartScanRequest._();
  static $pb.GeneratedMessage $_createMessage() => StartScanRequest._();
  @$core.override
  StartScanRequest createEmptyInstance() => StartScanRequest._();
  @$core.pragma('dart2js:noInline')
  static StartScanRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<StartScanRequest>(
          StartScanRequest.$_createMessage);
  static StartScanRequest? _defaultInstance;

  /// Legacy single Steam root. Ignored when `sources` is non-empty; when
  /// `sources` is empty and this is set, it is treated as one Steam source.
  /// May be empty: a scan of custom folders only is valid.
  @$pb.TagNumber(1)
  $core.String get steamRoot => $_getSZ(0);
  @$pb.TagNumber(1)
  set steamRoot($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSteamRoot() => $_has(0);
  @$pb.TagNumber(1)
  void clearSteamRoot() => $_clearField(1);

  /// Sources to scan, in order. Empty is rejected unless steam_root is set.
  /// Never scan the same physical directory through two sources; the sidecar
  /// deduplicates them and reports a warning.
  @$pb.TagNumber(2)
  $pb.PbList<ScanSource> get sources => $_getList(1);
}

enum ScanSource_Source { steam, customFolder, notSet }

/// ScanSource names one origin to enumerate. Each variant carries only the
/// information that origin needs; the sidecar resolves libraries and prefixes
/// itself.
class ScanSource extends $pb.GeneratedMessage {
  factory ScanSource({
    SteamSource? steam,
    CustomFolderSource? customFolder,
  }) {
    final result = ScanSource._();
    if (steam != null) result.steam = steam;
    if (customFolder != null) result.customFolder = customFolder;
    return result;
  }

  ScanSource._();

  factory ScanSource.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ScanSource()..mergeFromBuffer(data, registry);
  factory ScanSource.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ScanSource()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, ScanSource_Source> _ScanSource_SourceByTag =
      {
    1: ScanSource_Source.steam,
    2: ScanSource_Source.customFolder,
    0: ScanSource_Source.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ScanSource',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: ScanSource.$_createMessage)
    ..oo(0, [1, 2])
    ..aOM<SteamSource>(1, _omitFieldNames ? '' : 'steam',
        subBuilder: SteamSource.$_createMessage)
    ..aOM<CustomFolderSource>(2, _omitFieldNames ? '' : 'customFolder',
        subBuilder: CustomFolderSource.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScanSource clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScanSource copyWith(void Function(ScanSource) updates) =>
      super.copyWith((message) => updates(message as ScanSource)) as ScanSource;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ScanSource() / ScanSource.new instead')
  static ScanSource create() => ScanSource._();
  static $pb.GeneratedMessage $_createMessage() => ScanSource._();
  @$core.override
  ScanSource createEmptyInstance() => ScanSource._();
  @$core.pragma('dart2js:noInline')
  static ScanSource getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ScanSource>(ScanSource.$_createMessage);
  static ScanSource? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  ScanSource_Source whichSource() => _ScanSource_SourceByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  void clearSource() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  SteamSource get steam => $_getN(0);
  @$pb.TagNumber(1)
  set steam(SteamSource value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSteam() => $_has(0);
  @$pb.TagNumber(1)
  void clearSteam() => $_clearField(1);
  @$pb.TagNumber(1)
  SteamSource ensureSteam() => $_ensure(0);

  @$pb.TagNumber(2)
  CustomFolderSource get customFolder => $_getN(1);
  @$pb.TagNumber(2)
  set customFolder(CustomFolderSource value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasCustomFolder() => $_has(1);
  @$pb.TagNumber(2)
  void clearCustomFolder() => $_clearField(2);
  @$pb.TagNumber(2)
  CustomFolderSource ensureCustomFolder() => $_ensure(1);
}

/// SteamSource scans one Steam installation root and every library listed in
/// its steamapps/libraryfolders.vdf.
class SteamSource extends $pb.GeneratedMessage {
  factory SteamSource({
    $core.String? root,
  }) {
    final result = SteamSource._();
    if (root != null) result.root = root;
    return result;
  }

  SteamSource._();

  factory SteamSource.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SteamSource()..mergeFromBuffer(data, registry);
  factory SteamSource.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SteamSource()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SteamSource',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: SteamSource.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'root')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SteamSource clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SteamSource copyWith(void Function(SteamSource) updates) =>
      super.copyWith((message) => updates(message as SteamSource))
          as SteamSource;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SteamSource() / SteamSource.new instead')
  static SteamSource create() => SteamSource._();
  static $pb.GeneratedMessage $_createMessage() => SteamSource._();
  @$core.override
  SteamSource createEmptyInstance() => SteamSource._();
  @$core.pragma('dart2js:noInline')
  static SteamSource getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SteamSource>(
          SteamSource.$_createMessage);
  static SteamSource? _defaultInstance;

  /// Absolute path of the Steam root, for example ~/.local/share/Steam.
  @$pb.TagNumber(1)
  $core.String get root => $_getSZ(0);
  @$pb.TagNumber(1)
  set root($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRoot() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoot() => $_clearField(1);
}

/// CustomFolderSource scans one user-selected game directory recursively. The
/// directory itself is one game; its name is the directory basename.
class CustomFolderSource extends $pb.GeneratedMessage {
  factory CustomFolderSource({
    $core.String? path,
  }) {
    final result = CustomFolderSource._();
    if (path != null) result.path = path;
    return result;
  }

  CustomFolderSource._();

  factory CustomFolderSource.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CustomFolderSource()..mergeFromBuffer(data, registry);
  factory CustomFolderSource.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CustomFolderSource()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CustomFolderSource',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: CustomFolderSource.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'path')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CustomFolderSource clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CustomFolderSource copyWith(void Function(CustomFolderSource) updates) =>
      super.copyWith((message) => updates(message as CustomFolderSource))
          as CustomFolderSource;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CustomFolderSource() / CustomFolderSource.new instead')
  static CustomFolderSource create() => CustomFolderSource._();
  static $pb.GeneratedMessage $_createMessage() => CustomFolderSource._();
  @$core.override
  CustomFolderSource createEmptyInstance() => CustomFolderSource._();
  @$core.pragma('dart2js:noInline')
  static CustomFolderSource getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CustomFolderSource>(
          CustomFolderSource.$_createMessage);
  static CustomFolderSource? _defaultInstance;

  /// Absolute path of the game directory.
  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => $_clearField(1);
}

enum ScanEvent_Event {
  started,
  libraryProgress,
  gameFound,
  finished,
  failed,
  warning,
  notSet
}

class ScanEvent extends $pb.GeneratedMessage {
  factory ScanEvent({
    ScanStarted? started,
    ScanLibraryProgress? libraryProgress,
    $1.Game? gameFound,
    ScanFinished? finished,
    ScanFailed? failed,
    ScanWarning? warning,
  }) {
    final result = ScanEvent._();
    if (started != null) result.started = started;
    if (libraryProgress != null) result.libraryProgress = libraryProgress;
    if (gameFound != null) result.gameFound = gameFound;
    if (finished != null) result.finished = finished;
    if (failed != null) result.failed = failed;
    if (warning != null) result.warning = warning;
    return result;
  }

  ScanEvent._();

  factory ScanEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ScanEvent()..mergeFromBuffer(data, registry);
  factory ScanEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ScanEvent()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, ScanEvent_Event> _ScanEvent_EventByTag = {
    1: ScanEvent_Event.started,
    2: ScanEvent_Event.libraryProgress,
    3: ScanEvent_Event.gameFound,
    4: ScanEvent_Event.finished,
    5: ScanEvent_Event.failed,
    6: ScanEvent_Event.warning,
    0: ScanEvent_Event.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ScanEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: ScanEvent.$_createMessage)
    ..oo(0, [1, 2, 3, 4, 5, 6])
    ..aOM<ScanStarted>(1, _omitFieldNames ? '' : 'started',
        subBuilder: ScanStarted.$_createMessage)
    ..aOM<ScanLibraryProgress>(2, _omitFieldNames ? '' : 'libraryProgress',
        subBuilder: ScanLibraryProgress.$_createMessage)
    ..aOM<$1.Game>(3, _omitFieldNames ? '' : 'gameFound',
        subBuilder: $1.Game.$_createMessage)
    ..aOM<ScanFinished>(4, _omitFieldNames ? '' : 'finished',
        subBuilder: ScanFinished.$_createMessage)
    ..aOM<ScanFailed>(5, _omitFieldNames ? '' : 'failed',
        subBuilder: ScanFailed.$_createMessage)
    ..aOM<ScanWarning>(6, _omitFieldNames ? '' : 'warning',
        subBuilder: ScanWarning.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScanEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScanEvent copyWith(void Function(ScanEvent) updates) =>
      super.copyWith((message) => updates(message as ScanEvent)) as ScanEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ScanEvent() / ScanEvent.new instead')
  static ScanEvent create() => ScanEvent._();
  static $pb.GeneratedMessage $_createMessage() => ScanEvent._();
  @$core.override
  ScanEvent createEmptyInstance() => ScanEvent._();
  @$core.pragma('dart2js:noInline')
  static ScanEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ScanEvent>(ScanEvent.$_createMessage);
  static ScanEvent? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  ScanEvent_Event whichEvent() => _ScanEvent_EventByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  void clearEvent() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  ScanStarted get started => $_getN(0);
  @$pb.TagNumber(1)
  set started(ScanStarted value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasStarted() => $_has(0);
  @$pb.TagNumber(1)
  void clearStarted() => $_clearField(1);
  @$pb.TagNumber(1)
  ScanStarted ensureStarted() => $_ensure(0);

  @$pb.TagNumber(2)
  ScanLibraryProgress get libraryProgress => $_getN(1);
  @$pb.TagNumber(2)
  set libraryProgress(ScanLibraryProgress value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasLibraryProgress() => $_has(1);
  @$pb.TagNumber(2)
  void clearLibraryProgress() => $_clearField(2);
  @$pb.TagNumber(2)
  ScanLibraryProgress ensureLibraryProgress() => $_ensure(1);

  @$pb.TagNumber(3)
  $1.Game get gameFound => $_getN(2);
  @$pb.TagNumber(3)
  set gameFound($1.Game value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasGameFound() => $_has(2);
  @$pb.TagNumber(3)
  void clearGameFound() => $_clearField(3);
  @$pb.TagNumber(3)
  $1.Game ensureGameFound() => $_ensure(2);

  @$pb.TagNumber(4)
  ScanFinished get finished => $_getN(3);
  @$pb.TagNumber(4)
  set finished(ScanFinished value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasFinished() => $_has(3);
  @$pb.TagNumber(4)
  void clearFinished() => $_clearField(4);
  @$pb.TagNumber(4)
  ScanFinished ensureFinished() => $_ensure(3);

  @$pb.TagNumber(5)
  ScanFailed get failed => $_getN(4);
  @$pb.TagNumber(5)
  set failed(ScanFailed value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasFailed() => $_has(4);
  @$pb.TagNumber(5)
  void clearFailed() => $_clearField(5);
  @$pb.TagNumber(5)
  ScanFailed ensureFailed() => $_ensure(4);

  /// Non-fatal problem; the scan continues. It can be a read failure, an
  /// unsupported or duplicate source, an overlap, or a folder without known
  /// technology DLLs.
  @$pb.TagNumber(6)
  ScanWarning get warning => $_getN(5);
  @$pb.TagNumber(6)
  set warning(ScanWarning value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasWarning() => $_has(5);
  @$pb.TagNumber(6)
  void clearWarning() => $_clearField(6);
  @$pb.TagNumber(6)
  ScanWarning ensureWarning() => $_ensure(5);
}

class ScanStarted extends $pb.GeneratedMessage {
  factory ScanStarted({
    $core.String? steamRoot,
    $2.Timestamp? startedAt,
  }) {
    final result = ScanStarted._();
    if (steamRoot != null) result.steamRoot = steamRoot;
    if (startedAt != null) result.startedAt = startedAt;
    return result;
  }

  ScanStarted._();

  factory ScanStarted.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ScanStarted()..mergeFromBuffer(data, registry);
  factory ScanStarted.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ScanStarted()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ScanStarted',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: ScanStarted.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'steamRoot')
    ..aOM<$2.Timestamp>(2, _omitFieldNames ? '' : 'startedAt',
        subBuilder: $2.Timestamp.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScanStarted clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScanStarted copyWith(void Function(ScanStarted) updates) =>
      super.copyWith((message) => updates(message as ScanStarted))
          as ScanStarted;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ScanStarted() / ScanStarted.new instead')
  static ScanStarted create() => ScanStarted._();
  static $pb.GeneratedMessage $_createMessage() => ScanStarted._();
  @$core.override
  ScanStarted createEmptyInstance() => ScanStarted._();
  @$core.pragma('dart2js:noInline')
  static ScanStarted getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ScanStarted>(
          ScanStarted.$_createMessage);
  static ScanStarted? _defaultInstance;

  /// Steam root of the first Steam source, or empty when the scan has no Steam
  /// source (for example a custom-folders-only scan).
  @$pb.TagNumber(1)
  $core.String get steamRoot => $_getSZ(0);
  @$pb.TagNumber(1)
  set steamRoot($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSteamRoot() => $_has(0);
  @$pb.TagNumber(1)
  void clearSteamRoot() => $_clearField(1);

  @$pb.TagNumber(2)
  $2.Timestamp get startedAt => $_getN(1);
  @$pb.TagNumber(2)
  set startedAt($2.Timestamp value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStartedAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearStartedAt() => $_clearField(2);
  @$pb.TagNumber(2)
  $2.Timestamp ensureStartedAt() => $_ensure(1);
}

class ScanLibraryProgress extends $pb.GeneratedMessage {
  factory ScanLibraryProgress({
    $core.String? libraryPath,
    $core.int? libraryIndex,
    $core.int? libraryCount,
    $core.String? currentGame,
    $core.int? gamesFound,
    $core.int? dllsFound,
  }) {
    final result = ScanLibraryProgress._();
    if (libraryPath != null) result.libraryPath = libraryPath;
    if (libraryIndex != null) result.libraryIndex = libraryIndex;
    if (libraryCount != null) result.libraryCount = libraryCount;
    if (currentGame != null) result.currentGame = currentGame;
    if (gamesFound != null) result.gamesFound = gamesFound;
    if (dllsFound != null) result.dllsFound = dllsFound;
    return result;
  }

  ScanLibraryProgress._();

  factory ScanLibraryProgress.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ScanLibraryProgress()..mergeFromBuffer(data, registry);
  factory ScanLibraryProgress.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ScanLibraryProgress()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ScanLibraryProgress',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: ScanLibraryProgress.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'libraryPath')
    ..aI(2, _omitFieldNames ? '' : 'libraryIndex')
    ..aI(3, _omitFieldNames ? '' : 'libraryCount')
    ..aOS(4, _omitFieldNames ? '' : 'currentGame')
    ..aI(5, _omitFieldNames ? '' : 'gamesFound')
    ..aI(6, _omitFieldNames ? '' : 'dllsFound')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScanLibraryProgress clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScanLibraryProgress copyWith(void Function(ScanLibraryProgress) updates) =>
      super.copyWith((message) => updates(message as ScanLibraryProgress))
          as ScanLibraryProgress;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use ScanLibraryProgress() / ScanLibraryProgress.new instead')
  static ScanLibraryProgress create() => ScanLibraryProgress._();
  static $pb.GeneratedMessage $_createMessage() => ScanLibraryProgress._();
  @$core.override
  ScanLibraryProgress createEmptyInstance() => ScanLibraryProgress._();
  @$core.pragma('dart2js:noInline')
  static ScanLibraryProgress getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ScanLibraryProgress>(
          ScanLibraryProgress.$_createMessage);
  static ScanLibraryProgress? _defaultInstance;

  /// Absolute path of the Steam library or custom game folder currently being
  /// traversed.
  @$pb.TagNumber(1)
  $core.String get libraryPath => $_getSZ(0);
  @$pb.TagNumber(1)
  set libraryPath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLibraryPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearLibraryPath() => $_clearField(1);

  /// 1-based index of the ScanSource being scanned. A Steam source counts
  /// once even when it contains several libraries.
  @$pb.TagNumber(2)
  $core.int get libraryIndex => $_getIZ(1);
  @$pb.TagNumber(2)
  set libraryIndex($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLibraryIndex() => $_has(1);
  @$pb.TagNumber(2)
  void clearLibraryIndex() => $_clearField(2);

  /// Total number of ScanSources in this scan.
  @$pb.TagNumber(3)
  $core.int get libraryCount => $_getIZ(2);
  @$pb.TagNumber(3)
  set libraryCount($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLibraryCount() => $_has(2);
  @$pb.TagNumber(3)
  void clearLibraryCount() => $_clearField(3);

  /// Name of the game currently being traversed; empty between games.
  @$pb.TagNumber(4)
  $core.String get currentGame => $_getSZ(3);
  @$pb.TagNumber(4)
  set currentGame($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCurrentGame() => $_has(3);
  @$pb.TagNumber(4)
  void clearCurrentGame() => $_clearField(4);

  /// Counters accumulated so far.
  @$pb.TagNumber(5)
  $core.int get gamesFound => $_getIZ(4);
  @$pb.TagNumber(5)
  set gamesFound($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasGamesFound() => $_has(4);
  @$pb.TagNumber(5)
  void clearGamesFound() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get dllsFound => $_getIZ(5);
  @$pb.TagNumber(6)
  set dllsFound($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDllsFound() => $_has(5);
  @$pb.TagNumber(6)
  void clearDllsFound() => $_clearField(6);
}

class ScanWarning extends $pb.GeneratedMessage {
  factory ScanWarning({
    $core.String? path,
    $core.String? message,
  }) {
    final result = ScanWarning._();
    if (path != null) result.path = path;
    if (message != null) result.message = message;
    return result;
  }

  ScanWarning._();

  factory ScanWarning.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ScanWarning()..mergeFromBuffer(data, registry);
  factory ScanWarning.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ScanWarning()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ScanWarning',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: ScanWarning.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'path')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScanWarning clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScanWarning copyWith(void Function(ScanWarning) updates) =>
      super.copyWith((message) => updates(message as ScanWarning))
          as ScanWarning;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ScanWarning() / ScanWarning.new instead')
  static ScanWarning create() => ScanWarning._();
  static $pb.GeneratedMessage $_createMessage() => ScanWarning._();
  @$core.override
  ScanWarning createEmptyInstance() => ScanWarning._();
  @$core.pragma('dart2js:noInline')
  static ScanWarning getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ScanWarning>(
          ScanWarning.$_createMessage);
  static ScanWarning? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => $_clearField(1);

  /// English, user-facing explanation.
  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);
}

class ScanFinished extends $pb.GeneratedMessage {
  factory ScanFinished({
    $core.int? gameCount,
    $core.int? dllCount,
    $core.bool? cancelled,
    $fixnum.Int64? durationMs,
  }) {
    final result = ScanFinished._();
    if (gameCount != null) result.gameCount = gameCount;
    if (dllCount != null) result.dllCount = dllCount;
    if (cancelled != null) result.cancelled = cancelled;
    if (durationMs != null) result.durationMs = durationMs;
    return result;
  }

  ScanFinished._();

  factory ScanFinished.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ScanFinished()..mergeFromBuffer(data, registry);
  factory ScanFinished.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ScanFinished()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ScanFinished',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: ScanFinished.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'gameCount')
    ..aI(2, _omitFieldNames ? '' : 'dllCount')
    ..aOB(3, _omitFieldNames ? '' : 'cancelled')
    ..aInt64(4, _omitFieldNames ? '' : 'durationMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScanFinished clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScanFinished copyWith(void Function(ScanFinished) updates) =>
      super.copyWith((message) => updates(message as ScanFinished))
          as ScanFinished;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ScanFinished() / ScanFinished.new instead')
  static ScanFinished create() => ScanFinished._();
  static $pb.GeneratedMessage $_createMessage() => ScanFinished._();
  @$core.override
  ScanFinished createEmptyInstance() => ScanFinished._();
  @$core.pragma('dart2js:noInline')
  static ScanFinished getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ScanFinished>(
          ScanFinished.$_createMessage);
  static ScanFinished? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get gameCount => $_getIZ(0);
  @$pb.TagNumber(1)
  set gameCount($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGameCount() => $_has(0);
  @$pb.TagNumber(1)
  void clearGameCount() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get dllCount => $_getIZ(1);
  @$pb.TagNumber(2)
  set dllCount($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDllCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearDllCount() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get cancelled => $_getBF(2);
  @$pb.TagNumber(3)
  set cancelled($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCancelled() => $_has(2);
  @$pb.TagNumber(3)
  void clearCancelled() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get durationMs => $_getI64(3);
  @$pb.TagNumber(4)
  set durationMs($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDurationMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearDurationMs() => $_clearField(4);
}

class ScanFailed extends $pb.GeneratedMessage {
  factory ScanFailed({
    $core.String? reason,
    $core.String? message,
  }) {
    final result = ScanFailed._();
    if (reason != null) result.reason = reason;
    if (message != null) result.message = message;
    return result;
  }

  ScanFailed._();

  factory ScanFailed.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ScanFailed()..mergeFromBuffer(data, registry);
  factory ScanFailed.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ScanFailed()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ScanFailed',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: ScanFailed.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'reason')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScanFailed clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScanFailed copyWith(void Function(ScanFailed) updates) =>
      super.copyWith((message) => updates(message as ScanFailed)) as ScanFailed;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ScanFailed() / ScanFailed.new instead')
  static ScanFailed create() => ScanFailed._();
  static $pb.GeneratedMessage $_createMessage() => ScanFailed._();
  @$core.override
  ScanFailed createEmptyInstance() => ScanFailed._();
  @$core.pragma('dart2js:noInline')
  static ScanFailed getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ScanFailed>(ScanFailed.$_createMessage);
  static ScanFailed? _defaultInstance;

  /// Stable reason, the same value carried by the terminating status.
  @$pb.TagNumber(1)
  $core.String get reason => $_getSZ(0);
  @$pb.TagNumber(1)
  set reason($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasReason() => $_has(0);
  @$pb.TagNumber(1)
  void clearReason() => $_clearField(1);

  /// English, user-facing explanation.
  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
