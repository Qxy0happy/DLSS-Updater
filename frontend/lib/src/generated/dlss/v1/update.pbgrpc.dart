// This is a generated file - do not edit.
//
// Generated from dlss/v1/update.proto.

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

import 'update.pb.dart' as $0;

export 'update.pb.dart';

@$pb.GrpcServiceName('dlss.v1.Update')
class UpdateClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  UpdateClient(super.channel, {super.options, super.interceptors});

  /// StartUpdate updates the given GameDLL ids from the configured DLL source
  /// directory. Only one update run may be active at a time; a concurrent
  /// start fails with UPDATE_IN_PROGRESS.
  $grpc.ResponseStream<$0.UpdateEvent> startUpdate(
    $0.StartUpdateRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$startUpdate, $async.Stream.fromIterable([request]),
        options: options);
  }

  // method descriptors

  static final _$startUpdate =
      $grpc.ClientMethod<$0.StartUpdateRequest, $0.UpdateEvent>(
          '/dlss.v1.Update/StartUpdate',
          ($0.StartUpdateRequest value) => value.writeToBuffer(),
          $0.UpdateEvent.fromBuffer);
}

@$pb.GrpcServiceName('dlss.v1.Update')
abstract class UpdateServiceBase extends $grpc.Service {
  $core.String get $name => 'dlss.v1.Update';

  UpdateServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.StartUpdateRequest, $0.UpdateEvent>(
        'StartUpdate',
        startUpdate_Pre,
        false,
        true,
        ($core.List<$core.int> value) =>
            $0.StartUpdateRequest.fromBuffer(value),
        ($0.UpdateEvent value) => value.writeToBuffer()));
  }

  $async.Stream<$0.UpdateEvent> startUpdate_Pre($grpc.ServiceCall $call,
      $async.Future<$0.StartUpdateRequest> $request) async* {
    yield* startUpdate($call, await $request);
  }

  $async.Stream<$0.UpdateEvent> startUpdate(
      $grpc.ServiceCall call, $0.StartUpdateRequest request);
}
