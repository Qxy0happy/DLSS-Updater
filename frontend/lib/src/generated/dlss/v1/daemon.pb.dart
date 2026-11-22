// This is a generated file - do not edit.
//
// Generated from dlss/v1/daemon.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart'
    as $1;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class GetStatusRequest extends $pb.GeneratedMessage {
  factory GetStatusRequest() => GetStatusRequest._();

  GetStatusRequest._();

  factory GetStatusRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetStatusRequest()..mergeFromBuffer(data, registry);
  factory GetStatusRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetStatusRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetStatusRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: GetStatusRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetStatusRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetStatusRequest copyWith(void Function(GetStatusRequest) updates) =>
      super.copyWith((message) => updates(message as GetStatusRequest))
          as GetStatusRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GetStatusRequest() / GetStatusRequest.new instead')
  static GetStatusRequest create() => GetStatusRequest._();
  static $pb.GeneratedMessage $_createMessage() => GetStatusRequest._();
  @$core.override
  GetStatusRequest createEmptyInstance() => GetStatusRequest._();
  @$core.pragma('dart2js:noInline')
  static GetStatusRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetStatusRequest>(
          GetStatusRequest.$_createMessage);
  static GetStatusRequest? _defaultInstance;
}

class Status extends $pb.GeneratedMessage {
  factory Status({
    $core.String? protoVersion,
    $core.String? appVersion,
    $core.int? pid,
    $1.Timestamp? startTime,
    $core.bool? scanRunning,
    $core.bool? updateRunning,
  }) {
    final result = Status._();
    if (protoVersion != null) result.protoVersion = protoVersion;
    if (appVersion != null) result.appVersion = appVersion;
    if (pid != null) result.pid = pid;
    if (startTime != null) result.startTime = startTime;
    if (scanRunning != null) result.scanRunning = scanRunning;
    if (updateRunning != null) result.updateRunning = updateRunning;
    return result;
  }

  Status._();

  factory Status.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Status()..mergeFromBuffer(data, registry);
  factory Status.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Status()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Status',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: Status.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'protoVersion')
    ..aOS(2, _omitFieldNames ? '' : 'appVersion')
    ..aI(3, _omitFieldNames ? '' : 'pid')
    ..aOM<$1.Timestamp>(4, _omitFieldNames ? '' : 'startTime',
        subBuilder: $1.Timestamp.$_createMessage)
    ..aOB(5, _omitFieldNames ? '' : 'scanRunning')
    ..aOB(6, _omitFieldNames ? '' : 'updateRunning')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Status clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Status copyWith(void Function(Status) updates) =>
      super.copyWith((message) => updates(message as Status)) as Status;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Status() / Status.new instead')
  static Status create() => Status._();
  static $pb.GeneratedMessage $_createMessage() => Status._();
  @$core.override
  Status createEmptyInstance() => Status._();
  @$core.pragma('dart2js:noInline')
  static Status getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Status>(Status.$_createMessage);
  static Status? _defaultInstance;

  /// Contract version served by the sidecar, for example "dlss.v1".
  @$pb.TagNumber(1)
  $core.String get protoVersion => $_getSZ(0);
  @$pb.TagNumber(1)
  set protoVersion($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProtoVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearProtoVersion() => $_clearField(1);

  /// Application version of the sidecar binary.
  @$pb.TagNumber(2)
  $core.String get appVersion => $_getSZ(1);
  @$pb.TagNumber(2)
  set appVersion($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAppVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearAppVersion() => $_clearField(2);

  /// Process id of the sidecar.
  @$pb.TagNumber(3)
  $core.int get pid => $_getIZ(2);
  @$pb.TagNumber(3)
  set pid($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPid() => $_has(2);
  @$pb.TagNumber(3)
  void clearPid() => $_clearField(3);

  /// When the sidecar process started.
  @$pb.TagNumber(4)
  $1.Timestamp get startTime => $_getN(3);
  @$pb.TagNumber(4)
  set startTime($1.Timestamp value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasStartTime() => $_has(3);
  @$pb.TagNumber(4)
  void clearStartTime() => $_clearField(4);
  @$pb.TagNumber(4)
  $1.Timestamp ensureStartTime() => $_ensure(3);

  /// Whether a scan is currently running.
  @$pb.TagNumber(5)
  $core.bool get scanRunning => $_getBF(4);
  @$pb.TagNumber(5)
  set scanRunning($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasScanRunning() => $_has(4);
  @$pb.TagNumber(5)
  void clearScanRunning() => $_clearField(5);

  /// Whether an update run is currently running.
  @$pb.TagNumber(6)
  $core.bool get updateRunning => $_getBF(5);
  @$pb.TagNumber(6)
  set updateRunning($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasUpdateRunning() => $_has(5);
  @$pb.TagNumber(6)
  void clearUpdateRunning() => $_clearField(6);
}

class ShutdownRequest extends $pb.GeneratedMessage {
  factory ShutdownRequest() => ShutdownRequest._();

  ShutdownRequest._();

  factory ShutdownRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ShutdownRequest()..mergeFromBuffer(data, registry);
  factory ShutdownRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ShutdownRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ShutdownRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: ShutdownRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShutdownRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShutdownRequest copyWith(void Function(ShutdownRequest) updates) =>
      super.copyWith((message) => updates(message as ShutdownRequest))
          as ShutdownRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ShutdownRequest() / ShutdownRequest.new instead')
  static ShutdownRequest create() => ShutdownRequest._();
  static $pb.GeneratedMessage $_createMessage() => ShutdownRequest._();
  @$core.override
  ShutdownRequest createEmptyInstance() => ShutdownRequest._();
  @$core.pragma('dart2js:noInline')
  static ShutdownRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ShutdownRequest>(
          ShutdownRequest.$_createMessage);
  static ShutdownRequest? _defaultInstance;
}

class ShutdownResponse extends $pb.GeneratedMessage {
  factory ShutdownResponse() => ShutdownResponse._();

  ShutdownResponse._();

  factory ShutdownResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ShutdownResponse()..mergeFromBuffer(data, registry);
  factory ShutdownResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ShutdownResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ShutdownResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: ShutdownResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShutdownResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShutdownResponse copyWith(void Function(ShutdownResponse) updates) =>
      super.copyWith((message) => updates(message as ShutdownResponse))
          as ShutdownResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ShutdownResponse() / ShutdownResponse.new instead')
  static ShutdownResponse create() => ShutdownResponse._();
  static $pb.GeneratedMessage $_createMessage() => ShutdownResponse._();
  @$core.override
  ShutdownResponse createEmptyInstance() => ShutdownResponse._();
  @$core.pragma('dart2js:noInline')
  static ShutdownResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ShutdownResponse>(
          ShutdownResponse.$_createMessage);
  static ShutdownResponse? _defaultInstance;
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
