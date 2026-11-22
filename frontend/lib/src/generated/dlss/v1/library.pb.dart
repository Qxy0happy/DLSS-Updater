// This is a generated file - do not edit.
//
// Generated from dlss/v1/library.proto.

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

class ListGamesRequest extends $pb.GeneratedMessage {
  factory ListGamesRequest() => ListGamesRequest._();

  ListGamesRequest._();

  factory ListGamesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListGamesRequest()..mergeFromBuffer(data, registry);
  factory ListGamesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListGamesRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListGamesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: ListGamesRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListGamesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListGamesRequest copyWith(void Function(ListGamesRequest) updates) =>
      super.copyWith((message) => updates(message as ListGamesRequest))
          as ListGamesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListGamesRequest() / ListGamesRequest.new instead')
  static ListGamesRequest create() => ListGamesRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListGamesRequest._();
  @$core.override
  ListGamesRequest createEmptyInstance() => ListGamesRequest._();
  @$core.pragma('dart2js:noInline')
  static ListGamesRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListGamesRequest>(
          ListGamesRequest.$_createMessage);
  static ListGamesRequest? _defaultInstance;
}

class ListGamesResponse extends $pb.GeneratedMessage {
  factory ListGamesResponse({
    $core.Iterable<$1.Game>? games,
  }) {
    final result = ListGamesResponse._();
    if (games != null) result.games.addAll(games);
    return result;
  }

  ListGamesResponse._();

  factory ListGamesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListGamesResponse()..mergeFromBuffer(data, registry);
  factory ListGamesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListGamesResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListGamesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: ListGamesResponse.$_createMessage)
    ..pPM<$1.Game>(1, _omitFieldNames ? '' : 'games',
        subBuilder: $1.Game.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListGamesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListGamesResponse copyWith(void Function(ListGamesResponse) updates) =>
      super.copyWith((message) => updates(message as ListGamesResponse))
          as ListGamesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListGamesResponse() / ListGamesResponse.new instead')
  static ListGamesResponse create() => ListGamesResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListGamesResponse._();
  @$core.override
  ListGamesResponse createEmptyInstance() => ListGamesResponse._();
  @$core.pragma('dart2js:noInline')
  static ListGamesResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListGamesResponse>(
          ListGamesResponse.$_createMessage);
  static ListGamesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$1.Game> get games => $_getList(0);
}

class GetGameRequest extends $pb.GeneratedMessage {
  factory GetGameRequest({
    $core.String? gameId,
  }) {
    final result = GetGameRequest._();
    if (gameId != null) result.gameId = gameId;
    return result;
  }

  GetGameRequest._();

  factory GetGameRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetGameRequest()..mergeFromBuffer(data, registry);
  factory GetGameRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetGameRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetGameRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dlss.v1'),
      createEmptyInstance: GetGameRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'gameId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetGameRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetGameRequest copyWith(void Function(GetGameRequest) updates) =>
      super.copyWith((message) => updates(message as GetGameRequest))
          as GetGameRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GetGameRequest() / GetGameRequest.new instead')
  static GetGameRequest create() => GetGameRequest._();
  static $pb.GeneratedMessage $_createMessage() => GetGameRequest._();
  @$core.override
  GetGameRequest createEmptyInstance() => GetGameRequest._();
  @$core.pragma('dart2js:noInline')
  static GetGameRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetGameRequest>(
          GetGameRequest.$_createMessage);
  static GetGameRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get gameId => $_getSZ(0);
  @$pb.TagNumber(1)
  set gameId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGameId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGameId() => $_clearField(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
