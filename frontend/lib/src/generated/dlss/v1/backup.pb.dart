// This is a generated file - do not edit.
//
// Generated from dlss/v1/backup.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'common.pb.dart' as $1;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class ListBackupsRequest extends $pb.GeneratedMessage {
  factory ListBackupsRequest({
    $core.String? gameId,
    $core.bool? includeInactive,
  }) {
    final result = ListBackupsRequest._();
    if (gameId != null) result.gameId = gameId;
    if (includeInactive != null) result.includeInactive = includeInactive;
    return result;
  }

  ListBackupsRequest._();

  factory ListBackupsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListBackupsRequest()..mergeFromBuffer(data, registry);
  factory ListBackupsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListBackupsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListBackupsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: ListBackupsRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'gameId')
    ..aOB(2, _omitFieldNames ? '' : 'includeInactive')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListBackupsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListBackupsRequest copyWith(void Function(ListBackupsRequest) updates) =>
      super.copyWith((message) => updates(message as ListBackupsRequest))
          as ListBackupsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListBackupsRequest() / ListBackupsRequest.new instead')
  static ListBackupsRequest create() => ListBackupsRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListBackupsRequest._();
  @$core.override
  ListBackupsRequest createEmptyInstance() => ListBackupsRequest._();
  @$core.pragma('dart2js:noInline')
  static ListBackupsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListBackupsRequest>(
          ListBackupsRequest.$_createMessage);
  static ListBackupsRequest? _defaultInstance;

  /// Optional game id filter; empty lists every game.
  @$pb.TagNumber(1)
  $core.String get gameId => $_getSZ(0);
  @$pb.TagNumber(1)
  set gameId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGameId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGameId() => $_clearField(1);

  /// Include restored and superseded backups in the response.
  @$pb.TagNumber(2)
  $core.bool get includeInactive => $_getBF(1);
  @$pb.TagNumber(2)
  set includeInactive($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIncludeInactive() => $_has(1);
  @$pb.TagNumber(2)
  void clearIncludeInactive() => $_clearField(2);
}

class ListBackupsResponse extends $pb.GeneratedMessage {
  factory ListBackupsResponse({
    $core.Iterable<$1.BackupRecord>? backups,
  }) {
    final result = ListBackupsResponse._();
    if (backups != null) result.backups.addAll(backups);
    return result;
  }

  ListBackupsResponse._();

  factory ListBackupsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListBackupsResponse()..mergeFromBuffer(data, registry);
  factory ListBackupsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListBackupsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListBackupsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: ListBackupsResponse.$_createMessage)
    ..pPM<$1.BackupRecord>(1, _omitFieldNames ? '' : 'backups',
        subBuilder: $1.BackupRecord.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListBackupsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListBackupsResponse copyWith(void Function(ListBackupsResponse) updates) =>
      super.copyWith((message) => updates(message as ListBackupsResponse))
          as ListBackupsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use ListBackupsResponse() / ListBackupsResponse.new instead')
  static ListBackupsResponse create() => ListBackupsResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListBackupsResponse._();
  @$core.override
  ListBackupsResponse createEmptyInstance() => ListBackupsResponse._();
  @$core.pragma('dart2js:noInline')
  static ListBackupsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListBackupsResponse>(
          ListBackupsResponse.$_createMessage);
  static ListBackupsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$1.BackupRecord> get backups => $_getList(0);
}

class RestoreBackupRequest extends $pb.GeneratedMessage {
  factory RestoreBackupRequest({
    $core.String? backupId,
  }) {
    final result = RestoreBackupRequest._();
    if (backupId != null) result.backupId = backupId;
    return result;
  }

  RestoreBackupRequest._();

  factory RestoreBackupRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RestoreBackupRequest()..mergeFromBuffer(data, registry);
  factory RestoreBackupRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RestoreBackupRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RestoreBackupRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: RestoreBackupRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'backupId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RestoreBackupRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RestoreBackupRequest copyWith(void Function(RestoreBackupRequest) updates) =>
      super.copyWith((message) => updates(message as RestoreBackupRequest))
          as RestoreBackupRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RestoreBackupRequest() / RestoreBackupRequest.new instead')
  static RestoreBackupRequest create() => RestoreBackupRequest._();
  static $pb.GeneratedMessage $_createMessage() => RestoreBackupRequest._();
  @$core.override
  RestoreBackupRequest createEmptyInstance() => RestoreBackupRequest._();
  @$core.pragma('dart2js:noInline')
  static RestoreBackupRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RestoreBackupRequest>(
          RestoreBackupRequest.$_createMessage);
  static RestoreBackupRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get backupId => $_getSZ(0);
  @$pb.TagNumber(1)
  set backupId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBackupId() => $_has(0);
  @$pb.TagNumber(1)
  void clearBackupId() => $_clearField(1);
}

class RestoreBackupResponse extends $pb.GeneratedMessage {
  factory RestoreBackupResponse({
    $1.GameDLL? dll,
    $1.BackupRecord? backup,
  }) {
    final result = RestoreBackupResponse._();
    if (dll != null) result.dll = dll;
    if (backup != null) result.backup = backup;
    return result;
  }

  RestoreBackupResponse._();

  factory RestoreBackupResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RestoreBackupResponse()..mergeFromBuffer(data, registry);
  factory RestoreBackupResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RestoreBackupResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RestoreBackupResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: RestoreBackupResponse.$_createMessage)
    ..aOM<$1.GameDLL>(1, _omitFieldNames ? '' : 'dll',
        subBuilder: $1.GameDLL.$_createMessage)
    ..aOM<$1.BackupRecord>(2, _omitFieldNames ? '' : 'backup',
        subBuilder: $1.BackupRecord.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RestoreBackupResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RestoreBackupResponse copyWith(
          void Function(RestoreBackupResponse) updates) =>
      super.copyWith((message) => updates(message as RestoreBackupResponse))
          as RestoreBackupResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RestoreBackupResponse() / RestoreBackupResponse.new instead')
  static RestoreBackupResponse create() => RestoreBackupResponse._();
  static $pb.GeneratedMessage $_createMessage() => RestoreBackupResponse._();
  @$core.override
  RestoreBackupResponse createEmptyInstance() => RestoreBackupResponse._();
  @$core.pragma('dart2js:noInline')
  static RestoreBackupResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RestoreBackupResponse>(
          RestoreBackupResponse.$_createMessage);
  static RestoreBackupResponse? _defaultInstance;

  /// The target DLL after the restore, with its refreshed version.
  @$pb.TagNumber(1)
  $1.GameDLL get dll => $_getN(0);
  @$pb.TagNumber(1)
  set dll($1.GameDLL value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasDll() => $_has(0);
  @$pb.TagNumber(1)
  void clearDll() => $_clearField(1);
  @$pb.TagNumber(1)
  $1.GameDLL ensureDll() => $_ensure(0);

  /// The backup record after the restore.
  @$pb.TagNumber(2)
  $1.BackupRecord get backup => $_getN(1);
  @$pb.TagNumber(2)
  set backup($1.BackupRecord value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasBackup() => $_has(1);
  @$pb.TagNumber(2)
  void clearBackup() => $_clearField(2);
  @$pb.TagNumber(2)
  $1.BackupRecord ensureBackup() => $_ensure(1);
}

class DeleteBackupRequest extends $pb.GeneratedMessage {
  factory DeleteBackupRequest({
    $core.String? backupId,
  }) {
    final result = DeleteBackupRequest._();
    if (backupId != null) result.backupId = backupId;
    return result;
  }

  DeleteBackupRequest._();

  factory DeleteBackupRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteBackupRequest()..mergeFromBuffer(data, registry);
  factory DeleteBackupRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteBackupRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteBackupRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: DeleteBackupRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'backupId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteBackupRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteBackupRequest copyWith(void Function(DeleteBackupRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteBackupRequest))
          as DeleteBackupRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use DeleteBackupRequest() / DeleteBackupRequest.new instead')
  static DeleteBackupRequest create() => DeleteBackupRequest._();
  static $pb.GeneratedMessage $_createMessage() => DeleteBackupRequest._();
  @$core.override
  DeleteBackupRequest createEmptyInstance() => DeleteBackupRequest._();
  @$core.pragma('dart2js:noInline')
  static DeleteBackupRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteBackupRequest>(
          DeleteBackupRequest.$_createMessage);
  static DeleteBackupRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get backupId => $_getSZ(0);
  @$pb.TagNumber(1)
  set backupId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBackupId() => $_has(0);
  @$pb.TagNumber(1)
  void clearBackupId() => $_clearField(1);
}

class DeleteBackupResponse extends $pb.GeneratedMessage {
  factory DeleteBackupResponse() => DeleteBackupResponse._();

  DeleteBackupResponse._();

  factory DeleteBackupResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteBackupResponse()..mergeFromBuffer(data, registry);
  factory DeleteBackupResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteBackupResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteBackupResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: DeleteBackupResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteBackupResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteBackupResponse copyWith(void Function(DeleteBackupResponse) updates) =>
      super.copyWith((message) => updates(message as DeleteBackupResponse))
          as DeleteBackupResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use DeleteBackupResponse() / DeleteBackupResponse.new instead')
  static DeleteBackupResponse create() => DeleteBackupResponse._();
  static $pb.GeneratedMessage $_createMessage() => DeleteBackupResponse._();
  @$core.override
  DeleteBackupResponse createEmptyInstance() => DeleteBackupResponse._();
  @$core.pragma('dart2js:noInline')
  static DeleteBackupResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteBackupResponse>(
          DeleteBackupResponse.$_createMessage);
  static DeleteBackupResponse? _defaultInstance;
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
