// This is a generated file - do not edit.
//
// Generated from dlss/v1/backup.proto.

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

import 'backup.pb.dart' as $0;

export 'backup.pb.dart';

@$pb.GrpcServiceName('dlss.v1.Backup')
class BackupClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  BackupClient(super.channel, {super.options, super.interceptors});

  /// ListBackups returns backup records, newest first. Active records are the
  /// default; include_inactive adds restored and superseded ones.
  $grpc.ResponseFuture<$0.ListBackupsResponse> listBackups(
    $0.ListBackupsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listBackups, request, options: options);
  }

  /// RestoreBackup atomically puts the backup back in place of the target and
  /// marks the backup as restored.
  $grpc.ResponseFuture<$0.RestoreBackupResponse> restoreBackup(
    $0.RestoreBackupRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$restoreBackup, request, options: options);
  }

  /// DeleteBackup removes the backup file and marks the record inactive.
  $grpc.ResponseFuture<$0.DeleteBackupResponse> deleteBackup(
    $0.DeleteBackupRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deleteBackup, request, options: options);
  }

  // method descriptors

  static final _$listBackups =
      $grpc.ClientMethod<$0.ListBackupsRequest, $0.ListBackupsResponse>(
          '/dlss.v1.Backup/ListBackups',
          ($0.ListBackupsRequest value) => value.writeToBuffer(),
          $0.ListBackupsResponse.fromBuffer);
  static final _$restoreBackup =
      $grpc.ClientMethod<$0.RestoreBackupRequest, $0.RestoreBackupResponse>(
          '/dlss.v1.Backup/RestoreBackup',
          ($0.RestoreBackupRequest value) => value.writeToBuffer(),
          $0.RestoreBackupResponse.fromBuffer);
  static final _$deleteBackup =
      $grpc.ClientMethod<$0.DeleteBackupRequest, $0.DeleteBackupResponse>(
          '/dlss.v1.Backup/DeleteBackup',
          ($0.DeleteBackupRequest value) => value.writeToBuffer(),
          $0.DeleteBackupResponse.fromBuffer);
}

@$pb.GrpcServiceName('dlss.v1.Backup')
abstract class BackupServiceBase extends $grpc.Service {
  $core.String get $name => 'dlss.v1.Backup';

  BackupServiceBase() {
    $addMethod(
        $grpc.ServiceMethod<$0.ListBackupsRequest, $0.ListBackupsResponse>(
            'ListBackups',
            listBackups_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.ListBackupsRequest.fromBuffer(value),
            ($0.ListBackupsResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.RestoreBackupRequest, $0.RestoreBackupResponse>(
            'RestoreBackup',
            restoreBackup_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.RestoreBackupRequest.fromBuffer(value),
            ($0.RestoreBackupResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.DeleteBackupRequest, $0.DeleteBackupResponse>(
            'DeleteBackup',
            deleteBackup_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.DeleteBackupRequest.fromBuffer(value),
            ($0.DeleteBackupResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.ListBackupsResponse> listBackups_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ListBackupsRequest> $request) async {
    return listBackups($call, await $request);
  }

  $async.Future<$0.ListBackupsResponse> listBackups(
      $grpc.ServiceCall call, $0.ListBackupsRequest request);

  $async.Future<$0.RestoreBackupResponse> restoreBackup_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.RestoreBackupRequest> $request) async {
    return restoreBackup($call, await $request);
  }

  $async.Future<$0.RestoreBackupResponse> restoreBackup(
      $grpc.ServiceCall call, $0.RestoreBackupRequest request);

  $async.Future<$0.DeleteBackupResponse> deleteBackup_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.DeleteBackupRequest> $request) async {
    return deleteBackup($call, await $request);
  }

  $async.Future<$0.DeleteBackupResponse> deleteBackup(
      $grpc.ServiceCall call, $0.DeleteBackupRequest request);
}
