// This is a generated file - do not edit.
//
// Generated from dlss/v1/daemon.proto.

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

import 'daemon.pb.dart' as $0;

export 'daemon.pb.dart';

@$pb.GrpcServiceName('dlss.v1.Daemon')
class DaemonClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  DaemonClient(super.channel, {super.options, super.interceptors});

  /// GetStatus is the startup handshake. The frontend compares proto_version
  /// before enabling any operation.
  $grpc.ResponseFuture<$0.Status> getStatus(
    $0.GetStatusRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getStatus, request, options: options);
  }

  /// Shutdown makes the sidecar stop after the response is delivered. Open
  /// streams must not delay it.
  $grpc.ResponseFuture<$0.ShutdownResponse> shutdown(
    $0.ShutdownRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$shutdown, request, options: options);
  }

  // method descriptors

  static final _$getStatus = $grpc.ClientMethod<$0.GetStatusRequest, $0.Status>(
      '/dlss.v1.Daemon/GetStatus',
      ($0.GetStatusRequest value) => value.writeToBuffer(),
      $0.Status.fromBuffer);
  static final _$shutdown =
      $grpc.ClientMethod<$0.ShutdownRequest, $0.ShutdownResponse>(
          '/dlss.v1.Daemon/Shutdown',
          ($0.ShutdownRequest value) => value.writeToBuffer(),
          $0.ShutdownResponse.fromBuffer);
}

@$pb.GrpcServiceName('dlss.v1.Daemon')
abstract class DaemonServiceBase extends $grpc.Service {
  $core.String get $name => 'dlss.v1.Daemon';

  DaemonServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.GetStatusRequest, $0.Status>(
        'GetStatus',
        getStatus_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetStatusRequest.fromBuffer(value),
        ($0.Status value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ShutdownRequest, $0.ShutdownResponse>(
        'Shutdown',
        shutdown_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ShutdownRequest.fromBuffer(value),
        ($0.ShutdownResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.Status> getStatus_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetStatusRequest> $request) async {
    return getStatus($call, await $request);
  }

  $async.Future<$0.Status> getStatus(
      $grpc.ServiceCall call, $0.GetStatusRequest request);

  $async.Future<$0.ShutdownResponse> shutdown_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ShutdownRequest> $request) async {
    return shutdown($call, await $request);
  }

  $async.Future<$0.ShutdownResponse> shutdown(
      $grpc.ServiceCall call, $0.ShutdownRequest request);
}
