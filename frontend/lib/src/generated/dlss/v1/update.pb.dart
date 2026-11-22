// This is a generated file - do not edit.
//
// Generated from dlss/v1/update.proto.

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
    as $1;

import 'update.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'update.pbenum.dart';

class StartUpdateRequest extends $pb.GeneratedMessage {
  factory StartUpdateRequest({
    $core.Iterable<$core.String>? dllIds,
  }) {
    final result = StartUpdateRequest._();
    if (dllIds != null) result.dllIds.addAll(dllIds);
    return result;
  }

  StartUpdateRequest._();

  factory StartUpdateRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StartUpdateRequest()..mergeFromBuffer(data, registry);
  factory StartUpdateRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StartUpdateRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StartUpdateRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: StartUpdateRequest.$_createMessage)
    ..pPS(1, _omitFieldNames ? '' : 'dllIds')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StartUpdateRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StartUpdateRequest copyWith(void Function(StartUpdateRequest) updates) =>
      super.copyWith((message) => updates(message as StartUpdateRequest))
          as StartUpdateRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use StartUpdateRequest() / StartUpdateRequest.new instead')
  static StartUpdateRequest create() => StartUpdateRequest._();
  static $pb.GeneratedMessage $_createMessage() => StartUpdateRequest._();
  @$core.override
  StartUpdateRequest createEmptyInstance() => StartUpdateRequest._();
  @$core.pragma('dart2js:noInline')
  static StartUpdateRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StartUpdateRequest>(
          StartUpdateRequest.$_createMessage);
  static StartUpdateRequest? _defaultInstance;

  /// GameDLL ids to process, in the order the server should process them.
  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get dllIds => $_getList(0);
}

enum UpdateEvent_Event {
  started,
  itemStarted,
  itemFinished,
  finished,
  failed,
  notSet
}

class UpdateEvent extends $pb.GeneratedMessage {
  factory UpdateEvent({
    UpdateStarted? started,
    UpdateItemStarted? itemStarted,
    UpdateItemFinished? itemFinished,
    UpdateFinished? finished,
    UpdateFailed? failed,
  }) {
    final result = UpdateEvent._();
    if (started != null) result.started = started;
    if (itemStarted != null) result.itemStarted = itemStarted;
    if (itemFinished != null) result.itemFinished = itemFinished;
    if (finished != null) result.finished = finished;
    if (failed != null) result.failed = failed;
    return result;
  }

  UpdateEvent._();

  factory UpdateEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UpdateEvent()..mergeFromBuffer(data, registry);
  factory UpdateEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UpdateEvent()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, UpdateEvent_Event> _UpdateEvent_EventByTag =
      {
    1: UpdateEvent_Event.started,
    2: UpdateEvent_Event.itemStarted,
    3: UpdateEvent_Event.itemFinished,
    4: UpdateEvent_Event.finished,
    5: UpdateEvent_Event.failed,
    0: UpdateEvent_Event.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: UpdateEvent.$_createMessage)
    ..oo(0, [1, 2, 3, 4, 5])
    ..aOM<UpdateStarted>(1, _omitFieldNames ? '' : 'started',
        subBuilder: UpdateStarted.$_createMessage)
    ..aOM<UpdateItemStarted>(2, _omitFieldNames ? '' : 'itemStarted',
        subBuilder: UpdateItemStarted.$_createMessage)
    ..aOM<UpdateItemFinished>(3, _omitFieldNames ? '' : 'itemFinished',
        subBuilder: UpdateItemFinished.$_createMessage)
    ..aOM<UpdateFinished>(4, _omitFieldNames ? '' : 'finished',
        subBuilder: UpdateFinished.$_createMessage)
    ..aOM<UpdateFailed>(5, _omitFieldNames ? '' : 'failed',
        subBuilder: UpdateFailed.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateEvent copyWith(void Function(UpdateEvent) updates) =>
      super.copyWith((message) => updates(message as UpdateEvent))
          as UpdateEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UpdateEvent() / UpdateEvent.new instead')
  static UpdateEvent create() => UpdateEvent._();
  static $pb.GeneratedMessage $_createMessage() => UpdateEvent._();
  @$core.override
  UpdateEvent createEmptyInstance() => UpdateEvent._();
  @$core.pragma('dart2js:noInline')
  static UpdateEvent getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UpdateEvent>(
          UpdateEvent.$_createMessage);
  static UpdateEvent? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  UpdateEvent_Event whichEvent() => _UpdateEvent_EventByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  void clearEvent() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  UpdateStarted get started => $_getN(0);
  @$pb.TagNumber(1)
  set started(UpdateStarted value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasStarted() => $_has(0);
  @$pb.TagNumber(1)
  void clearStarted() => $_clearField(1);
  @$pb.TagNumber(1)
  UpdateStarted ensureStarted() => $_ensure(0);

  @$pb.TagNumber(2)
  UpdateItemStarted get itemStarted => $_getN(1);
  @$pb.TagNumber(2)
  set itemStarted(UpdateItemStarted value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasItemStarted() => $_has(1);
  @$pb.TagNumber(2)
  void clearItemStarted() => $_clearField(2);
  @$pb.TagNumber(2)
  UpdateItemStarted ensureItemStarted() => $_ensure(1);

  @$pb.TagNumber(3)
  UpdateItemFinished get itemFinished => $_getN(2);
  @$pb.TagNumber(3)
  set itemFinished(UpdateItemFinished value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasItemFinished() => $_has(2);
  @$pb.TagNumber(3)
  void clearItemFinished() => $_clearField(3);
  @$pb.TagNumber(3)
  UpdateItemFinished ensureItemFinished() => $_ensure(2);

  @$pb.TagNumber(4)
  UpdateFinished get finished => $_getN(3);
  @$pb.TagNumber(4)
  set finished(UpdateFinished value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasFinished() => $_has(3);
  @$pb.TagNumber(4)
  void clearFinished() => $_clearField(4);
  @$pb.TagNumber(4)
  UpdateFinished ensureFinished() => $_ensure(3);

  @$pb.TagNumber(5)
  UpdateFailed get failed => $_getN(4);
  @$pb.TagNumber(5)
  set failed(UpdateFailed value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasFailed() => $_has(4);
  @$pb.TagNumber(5)
  void clearFailed() => $_clearField(5);
  @$pb.TagNumber(5)
  UpdateFailed ensureFailed() => $_ensure(4);
}

class UpdateStarted extends $pb.GeneratedMessage {
  factory UpdateStarted({
    $core.int? itemCount,
    $1.Timestamp? startedAt,
  }) {
    final result = UpdateStarted._();
    if (itemCount != null) result.itemCount = itemCount;
    if (startedAt != null) result.startedAt = startedAt;
    return result;
  }

  UpdateStarted._();

  factory UpdateStarted.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UpdateStarted()..mergeFromBuffer(data, registry);
  factory UpdateStarted.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UpdateStarted()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateStarted',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: UpdateStarted.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'itemCount')
    ..aOM<$1.Timestamp>(2, _omitFieldNames ? '' : 'startedAt',
        subBuilder: $1.Timestamp.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateStarted clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateStarted copyWith(void Function(UpdateStarted) updates) =>
      super.copyWith((message) => updates(message as UpdateStarted))
          as UpdateStarted;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UpdateStarted() / UpdateStarted.new instead')
  static UpdateStarted create() => UpdateStarted._();
  static $pb.GeneratedMessage $_createMessage() => UpdateStarted._();
  @$core.override
  UpdateStarted createEmptyInstance() => UpdateStarted._();
  @$core.pragma('dart2js:noInline')
  static UpdateStarted getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UpdateStarted>(
          UpdateStarted.$_createMessage);
  static UpdateStarted? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get itemCount => $_getIZ(0);
  @$pb.TagNumber(1)
  set itemCount($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasItemCount() => $_has(0);
  @$pb.TagNumber(1)
  void clearItemCount() => $_clearField(1);

  @$pb.TagNumber(2)
  $1.Timestamp get startedAt => $_getN(1);
  @$pb.TagNumber(2)
  set startedAt($1.Timestamp value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStartedAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearStartedAt() => $_clearField(2);
  @$pb.TagNumber(2)
  $1.Timestamp ensureStartedAt() => $_ensure(1);
}

class UpdateItemStarted extends $pb.GeneratedMessage {
  factory UpdateItemStarted({
    $core.String? dllId,
    $core.String? filename,
    $core.int? index,
    $core.int? total,
  }) {
    final result = UpdateItemStarted._();
    if (dllId != null) result.dllId = dllId;
    if (filename != null) result.filename = filename;
    if (index != null) result.index = index;
    if (total != null) result.total = total;
    return result;
  }

  UpdateItemStarted._();

  factory UpdateItemStarted.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UpdateItemStarted()..mergeFromBuffer(data, registry);
  factory UpdateItemStarted.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UpdateItemStarted()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateItemStarted',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: UpdateItemStarted.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'dllId')
    ..aOS(2, _omitFieldNames ? '' : 'filename')
    ..aI(3, _omitFieldNames ? '' : 'index')
    ..aI(4, _omitFieldNames ? '' : 'total')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateItemStarted clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateItemStarted copyWith(void Function(UpdateItemStarted) updates) =>
      super.copyWith((message) => updates(message as UpdateItemStarted))
          as UpdateItemStarted;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UpdateItemStarted() / UpdateItemStarted.new instead')
  static UpdateItemStarted create() => UpdateItemStarted._();
  static $pb.GeneratedMessage $_createMessage() => UpdateItemStarted._();
  @$core.override
  UpdateItemStarted createEmptyInstance() => UpdateItemStarted._();
  @$core.pragma('dart2js:noInline')
  static UpdateItemStarted getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UpdateItemStarted>(
          UpdateItemStarted.$_createMessage);
  static UpdateItemStarted? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get dllId => $_getSZ(0);
  @$pb.TagNumber(1)
  set dllId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDllId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDllId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get filename => $_getSZ(1);
  @$pb.TagNumber(2)
  set filename($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFilename() => $_has(1);
  @$pb.TagNumber(2)
  void clearFilename() => $_clearField(2);

  /// 1-based index of this item.
  @$pb.TagNumber(3)
  $core.int get index => $_getIZ(2);
  @$pb.TagNumber(3)
  set index($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIndex() => $_has(2);
  @$pb.TagNumber(3)
  void clearIndex() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get total => $_getIZ(3);
  @$pb.TagNumber(4)
  set total($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTotal() => $_has(3);
  @$pb.TagNumber(4)
  void clearTotal() => $_clearField(4);
}

class UpdateItemFinished extends $pb.GeneratedMessage {
  factory UpdateItemFinished({
    $core.String? dllId,
    UpdateOutcome? outcome,
    $core.String? reason,
    $core.String? backupId,
    $core.String? resultingVersion,
    $fixnum.Int64? durationMs,
  }) {
    final result = UpdateItemFinished._();
    if (dllId != null) result.dllId = dllId;
    if (outcome != null) result.outcome = outcome;
    if (reason != null) result.reason = reason;
    if (backupId != null) result.backupId = backupId;
    if (resultingVersion != null) result.resultingVersion = resultingVersion;
    if (durationMs != null) result.durationMs = durationMs;
    return result;
  }

  UpdateItemFinished._();

  factory UpdateItemFinished.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UpdateItemFinished()..mergeFromBuffer(data, registry);
  factory UpdateItemFinished.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UpdateItemFinished()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateItemFinished',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: UpdateItemFinished.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'dllId')
    ..aE<UpdateOutcome>(2, _omitFieldNames ? '' : 'outcome',
        enumValues: UpdateOutcome.values)
    ..aOS(3, _omitFieldNames ? '' : 'reason')
    ..aOS(4, _omitFieldNames ? '' : 'backupId')
    ..aOS(5, _omitFieldNames ? '' : 'resultingVersion')
    ..aInt64(6, _omitFieldNames ? '' : 'durationMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateItemFinished clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateItemFinished copyWith(void Function(UpdateItemFinished) updates) =>
      super.copyWith((message) => updates(message as UpdateItemFinished))
          as UpdateItemFinished;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UpdateItemFinished() / UpdateItemFinished.new instead')
  static UpdateItemFinished create() => UpdateItemFinished._();
  static $pb.GeneratedMessage $_createMessage() => UpdateItemFinished._();
  @$core.override
  UpdateItemFinished createEmptyInstance() => UpdateItemFinished._();
  @$core.pragma('dart2js:noInline')
  static UpdateItemFinished getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateItemFinished>(
          UpdateItemFinished.$_createMessage);
  static UpdateItemFinished? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get dllId => $_getSZ(0);
  @$pb.TagNumber(1)
  set dllId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDllId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDllId() => $_clearField(1);

  @$pb.TagNumber(2)
  UpdateOutcome get outcome => $_getN(1);
  @$pb.TagNumber(2)
  set outcome(UpdateOutcome value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasOutcome() => $_has(1);
  @$pb.TagNumber(2)
  void clearOutcome() => $_clearField(2);

  /// Stable reason for a skip or a failure; empty on success.
  @$pb.TagNumber(3)
  $core.String get reason => $_getSZ(2);
  @$pb.TagNumber(3)
  set reason($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasReason() => $_has(2);
  @$pb.TagNumber(3)
  void clearReason() => $_clearField(3);

  /// Backup record created for this item; empty when no backup was made.
  @$pb.TagNumber(4)
  $core.String get backupId => $_getSZ(3);
  @$pb.TagNumber(4)
  set backupId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBackupId() => $_has(3);
  @$pb.TagNumber(4)
  void clearBackupId() => $_clearField(4);

  /// Version now present on disk after the item was processed.
  @$pb.TagNumber(5)
  $core.String get resultingVersion => $_getSZ(4);
  @$pb.TagNumber(5)
  set resultingVersion($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasResultingVersion() => $_has(4);
  @$pb.TagNumber(5)
  void clearResultingVersion() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get durationMs => $_getI64(5);
  @$pb.TagNumber(6)
  set durationMs($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDurationMs() => $_has(5);
  @$pb.TagNumber(6)
  void clearDurationMs() => $_clearField(6);
}

class UpdateFinished extends $pb.GeneratedMessage {
  factory UpdateFinished({
    $core.int? succeeded,
    $core.int? skipped,
    $core.int? failed,
    $core.bool? cancelled,
    $fixnum.Int64? durationMs,
  }) {
    final result = UpdateFinished._();
    if (succeeded != null) result.succeeded = succeeded;
    if (skipped != null) result.skipped = skipped;
    if (failed != null) result.failed = failed;
    if (cancelled != null) result.cancelled = cancelled;
    if (durationMs != null) result.durationMs = durationMs;
    return result;
  }

  UpdateFinished._();

  factory UpdateFinished.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UpdateFinished()..mergeFromBuffer(data, registry);
  factory UpdateFinished.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UpdateFinished()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateFinished',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: UpdateFinished.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'succeeded')
    ..aI(2, _omitFieldNames ? '' : 'skipped')
    ..aI(3, _omitFieldNames ? '' : 'failed')
    ..aOB(4, _omitFieldNames ? '' : 'cancelled')
    ..aInt64(5, _omitFieldNames ? '' : 'durationMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateFinished clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateFinished copyWith(void Function(UpdateFinished) updates) =>
      super.copyWith((message) => updates(message as UpdateFinished))
          as UpdateFinished;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UpdateFinished() / UpdateFinished.new instead')
  static UpdateFinished create() => UpdateFinished._();
  static $pb.GeneratedMessage $_createMessage() => UpdateFinished._();
  @$core.override
  UpdateFinished createEmptyInstance() => UpdateFinished._();
  @$core.pragma('dart2js:noInline')
  static UpdateFinished getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UpdateFinished>(
          UpdateFinished.$_createMessage);
  static UpdateFinished? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get succeeded => $_getIZ(0);
  @$pb.TagNumber(1)
  set succeeded($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSucceeded() => $_has(0);
  @$pb.TagNumber(1)
  void clearSucceeded() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get skipped => $_getIZ(1);
  @$pb.TagNumber(2)
  set skipped($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSkipped() => $_has(1);
  @$pb.TagNumber(2)
  void clearSkipped() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get failed => $_getIZ(2);
  @$pb.TagNumber(3)
  set failed($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFailed() => $_has(2);
  @$pb.TagNumber(3)
  void clearFailed() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get cancelled => $_getBF(3);
  @$pb.TagNumber(4)
  set cancelled($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCancelled() => $_has(3);
  @$pb.TagNumber(4)
  void clearCancelled() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get durationMs => $_getI64(4);
  @$pb.TagNumber(5)
  set durationMs($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDurationMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearDurationMs() => $_clearField(5);
}

class UpdateFailed extends $pb.GeneratedMessage {
  factory UpdateFailed({
    $core.String? reason,
    $core.String? message,
  }) {
    final result = UpdateFailed._();
    if (reason != null) result.reason = reason;
    if (message != null) result.message = message;
    return result;
  }

  UpdateFailed._();

  factory UpdateFailed.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UpdateFailed()..mergeFromBuffer(data, registry);
  factory UpdateFailed.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UpdateFailed()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateFailed',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: UpdateFailed.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'reason')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateFailed clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateFailed copyWith(void Function(UpdateFailed) updates) =>
      super.copyWith((message) => updates(message as UpdateFailed))
          as UpdateFailed;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UpdateFailed() / UpdateFailed.new instead')
  static UpdateFailed create() => UpdateFailed._();
  static $pb.GeneratedMessage $_createMessage() => UpdateFailed._();
  @$core.override
  UpdateFailed createEmptyInstance() => UpdateFailed._();
  @$core.pragma('dart2js:noInline')
  static UpdateFailed getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UpdateFailed>(
          UpdateFailed.$_createMessage);
  static UpdateFailed? _defaultInstance;

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
