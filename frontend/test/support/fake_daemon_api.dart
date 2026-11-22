// Fake `DaemonApi` for widget tests.
//
// Later UI tickets inject this at the same seam the real app uses: the
// generated `dlss.v1` clients. Requests and responses are always the generated
// protocol messages, never hand-written stand-ins.
import 'dart:async';

import 'package:dlss_updater/src/data/daemon_api.dart';
import 'package:dlss_updater/src/data/daemon_stream.dart';
import 'package:grpc/grpc.dart';
import 'package:grpc/protos.dart' show ErrorInfo;

/// Builds the `GrpcError` the sidecar would return for a stable reason, so
/// widget tests exercise the real error shape.
GrpcError grpcErrorForReason(
  String reason, {
  String message = 'Something went wrong.',
  int code = StatusCode.failedPrecondition,
  String? path,
  bool retryable = false,
}) {
  final metadata = <String, String>{'retryable': retryable ? 'true' : 'false'};
  if (path != null) {
    metadata['path'] = path;
  }
  return GrpcError.custom(code, message, [
    ErrorInfo(domain: 'dlss.v1', reason: reason, metadata: metadata.entries),
  ]);
}

/// Records calls and returns configurable protocol responses.
class FakeDaemonApi implements DaemonApi {
  // Unary responses. Set the one a test needs; unset methods return an empty
  // response of the right type.
  Status? status;
  ListGamesResponse? listGamesResponse;
  Game? game;
  ListBackupsResponse? listBackupsResponse;
  RestoreBackupResponse? restoreBackupResponse;

  // Errors. Set to throw a `GrpcError` (see [grpcErrorForReason]).
  Object? getStatusError;
  Object? shutdownError;
  Object? listGamesError;
  Object? getGameError;
  Object? startScanError;
  Object? startUpdateError;
  Object? listBackupsError;
  Object? restoreBackupError;
  Object? deleteBackupError;

  // Scan/update event sources. Provide either a finite list or a controller
  // when the test needs to interleave events with UI updates.
  List<ScanEvent> scanEvents = const [];
  StreamController<ScanEvent>? scanController;
  List<UpdateEvent> updateEvents = const [];
  StreamController<UpdateEvent>? updateController;

  bool closed = false;
  bool scanCancelled = false;
  bool updateCancelled = false;

  final List<GetStatusRequest> getStatusRequests = [];
  final List<ShutdownRequest> shutdownRequests = [];
  final List<ListGamesRequest> listGamesRequests = [];
  final List<GetGameRequest> getGameRequests = [];
  final List<StartScanRequest> startScanRequests = [];
  final List<StartUpdateRequest> startUpdateRequests = [];
  final List<ListBackupsRequest> listBackupsRequests = [];
  final List<RestoreBackupRequest> restoreBackupRequests = [];
  final List<DeleteBackupRequest> deleteBackupRequests = [];

  @override
  Future<Status> getStatus(GetStatusRequest request) async {
    getStatusRequests.add(request);
    final error = getStatusError;
    if (error != null) throw error;
    return status ?? Status();
  }

  @override
  Future<ShutdownResponse> shutdown(ShutdownRequest request) async {
    shutdownRequests.add(request);
    final error = shutdownError;
    if (error != null) throw error;
    return ShutdownResponse();
  }

  @override
  Future<ListGamesResponse> listGames(ListGamesRequest request) async {
    listGamesRequests.add(request);
    final error = listGamesError;
    if (error != null) throw error;
    return listGamesResponse ?? ListGamesResponse();
  }

  @override
  Future<Game> getGame(GetGameRequest request) async {
    getGameRequests.add(request);
    final error = getGameError;
    if (error != null) throw error;
    return game ?? Game();
  }

  @override
  DaemonStream<ScanEvent> startScan(StartScanRequest request) {
    startScanRequests.add(request);
    final error = startScanError;
    if (error != null) {
      return _FakeDaemonStream(
        Stream<ScanEvent>.error(error),
        onCancel: () async {
          scanCancelled = true;
        },
      );
    }
    final controller = scanController;
    if (controller != null) {
      return _FakeDaemonStream(
        controller.stream,
        onCancel: () async {
          scanCancelled = true;
          await controller.close();
        },
      );
    }
    return _FakeDaemonStream(
      Stream<ScanEvent>.fromIterable(scanEvents),
      onCancel: () async {
        scanCancelled = true;
      },
    );
  }

  @override
  DaemonStream<UpdateEvent> startUpdate(StartUpdateRequest request) {
    startUpdateRequests.add(request);
    final error = startUpdateError;
    if (error != null) {
      return _FakeDaemonStream(
        Stream<UpdateEvent>.error(error),
        onCancel: () async {
          updateCancelled = true;
        },
      );
    }
    final controller = updateController;
    if (controller != null) {
      return _FakeDaemonStream(
        controller.stream,
        onCancel: () async {
          updateCancelled = true;
          await controller.close();
        },
      );
    }
    return _FakeDaemonStream(
      Stream<UpdateEvent>.fromIterable(updateEvents),
      onCancel: () async {
        updateCancelled = true;
      },
    );
  }

  @override
  Future<ListBackupsResponse> listBackups(ListBackupsRequest request) async {
    listBackupsRequests.add(request);
    final error = listBackupsError;
    if (error != null) throw error;
    return listBackupsResponse ?? ListBackupsResponse();
  }

  @override
  Future<RestoreBackupResponse> restoreBackup(
    RestoreBackupRequest request,
  ) async {
    restoreBackupRequests.add(request);
    final error = restoreBackupError;
    if (error != null) throw error;
    return restoreBackupResponse ?? RestoreBackupResponse();
  }

  @override
  Future<DeleteBackupResponse> deleteBackup(DeleteBackupRequest request) async {
    deleteBackupRequests.add(request);
    final error = deleteBackupError;
    if (error != null) throw error;
    return DeleteBackupResponse();
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

class _FakeDaemonStream<T> implements DaemonStream<T> {
  _FakeDaemonStream(this.events, {this.onCancel});

  @override
  final Stream<T> events;

  final Future<void> Function()? onCancel;

  @override
  Future<void> cancel() async {
    await onCancel?.call();
  }
}
