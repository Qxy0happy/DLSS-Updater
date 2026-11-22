// This is a generated file - do not edit.
//
// Generated from dlss/v1/library.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'common.pb.dart' as $1;
import 'library.pb.dart' as $0;

export 'library.pb.dart';

@$pb.GrpcServiceName('dlss.v1.Library')
class LibraryClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  LibraryClient(super.channel, {super.options, super.interceptors});

  /// ListGames returns every scanned game with its DLLs.
  $grpc.ResponseFuture<$0.ListGamesResponse> listGames(
    $0.ListGamesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listGames, request, options: options);
  }

  /// GetGame returns one game with its DLLs, including source versions
  /// resolved from the configured DLL source directory.
  $grpc.ResponseFuture<$1.Game> getGame(
    $0.GetGameRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getGame, request, options: options);
  }

  // method descriptors

  static final _$listGames =
      $grpc.ClientMethod<$0.ListGamesRequest, $0.ListGamesResponse>(
          '/dlss.v1.Library/ListGames',
          ($0.ListGamesRequest value) => value.writeToBuffer(),
          $0.ListGamesResponse.fromBuffer);
  static final _$getGame = $grpc.ClientMethod<$0.GetGameRequest, $1.Game>(
      '/dlss.v1.Library/GetGame',
      ($0.GetGameRequest value) => value.writeToBuffer(),
      $1.Game.fromBuffer);
}

@$pb.GrpcServiceName('dlss.v1.Library')
abstract class LibraryServiceBase extends $grpc.Service {
  $core.String get $name => 'dlss.v1.Library';

  LibraryServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.ListGamesRequest, $0.ListGamesResponse>(
        'ListGames',
        listGames_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ListGamesRequest.fromBuffer(value),
        ($0.ListGamesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetGameRequest, $1.Game>(
        'GetGame',
        getGame_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetGameRequest.fromBuffer(value),
        ($1.Game value) => value.writeToBuffer()));
  }

  $async.Future<$0.ListGamesResponse> listGames_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ListGamesRequest> $request) async {
    return listGames($call, await $request);
  }

  $async.Future<$0.ListGamesResponse> listGames(
      $grpc.ServiceCall call, $0.ListGamesRequest request);

  $async.Future<$1.Game> getGame_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetGameRequest> $request) async {
    return getGame($call, await $request);
  }

  $async.Future<$1.Game> getGame(
      $grpc.ServiceCall call, $0.GetGameRequest request);
}
