// This is a generated file - do not edit.
//
// Generated from dlss/v1/scan.proto.

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

import 'scan.pb.dart' as $0;

export 'scan.pb.dart';

@$pb.GrpcServiceName('dlss.v1.Scan')
class ScanClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  ScanClient(super.channel, {super.options, super.interceptors});

  /// StartScan starts a scan of the given Steam root and streams its events.
  /// Only one scan may run at a time; a concurrent start fails with
  /// SCAN_IN_PROGRESS.
  $grpc.ResponseStream<$0.ScanEvent> startScan(
    $0.StartScanRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$startScan, $async.Stream.fromIterable([request]),
        options: options);
  }

  // method descriptors

  static final _$startScan =
      $grpc.ClientMethod<$0.StartScanRequest, $0.ScanEvent>(
          '/dlss.v1.Scan/StartScan',
          ($0.StartScanRequest value) => value.writeToBuffer(),
          $0.ScanEvent.fromBuffer);
}

@$pb.GrpcServiceName('dlss.v1.Scan')
abstract class ScanServiceBase extends $grpc.Service {
  $core.String get $name => 'dlss.v1.Scan';

  ScanServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.StartScanRequest, $0.ScanEvent>(
        'StartScan',
        startScan_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $0.StartScanRequest.fromBuffer(value),
        ($0.ScanEvent value) => value.writeToBuffer()));
  }

  $async.Stream<$0.ScanEvent> startScan_Pre($grpc.ServiceCall $call,
      $async.Future<$0.StartScanRequest> $request) async* {
    yield* startScan($call, await $request);
  }

  $async.Stream<$0.ScanEvent> startScan(
      $grpc.ServiceCall call, $0.StartScanRequest request);
}
