import 'package:grpc/grpc.dart';

import '../generated/dlss/v1/backup.pbgrpc.dart';
import '../generated/dlss/v1/daemon.pbgrpc.dart';
import '../generated/dlss/v1/library.pbgrpc.dart';
import '../generated/dlss/v1/scan.pbgrpc.dart';
import '../generated/dlss/v1/update.pbgrpc.dart';
import 'daemon_api.dart';
import 'daemon_stream.dart';

/// [DaemonApi] backed by the real generated clients over one channel.
class GrpcDaemonApi implements DaemonApi {
  GrpcDaemonApi(ClientChannel channel)
    : _channel = channel,
      _daemon = DaemonClient(channel),
      _library = LibraryClient(channel),
      _scan = ScanClient(channel),
      _update = UpdateClient(channel),
      _backup = BackupClient(channel);

  final ClientChannel _channel;
  final DaemonClient _daemon;
  final LibraryClient _library;
  final ScanClient _scan;
  final UpdateClient _update;
  final BackupClient _backup;

  @override
  Future<Status> getStatus(GetStatusRequest request) =>
      _daemon.getStatus(request);

  @override
  Future<ShutdownResponse> shutdown(ShutdownRequest request) =>
      _daemon.shutdown(request);

  @override
  Future<ListGamesResponse> listGames(ListGamesRequest request) =>
      _library.listGames(request);

  @override
  Future<Game> getGame(GetGameRequest request) => _library.getGame(request);

  @override
  DaemonStream<ScanEvent> startScan(StartScanRequest request) =>
      _GrpcDaemonStream(_scan.startScan(request));

  @override
  DaemonStream<UpdateEvent> startUpdate(StartUpdateRequest request) =>
      _GrpcDaemonStream(_update.startUpdate(request));

  @override
  Future<ListBackupsResponse> listBackups(ListBackupsRequest request) =>
      _backup.listBackups(request);

  @override
  Future<RestoreBackupResponse> restoreBackup(RestoreBackupRequest request) =>
      _backup.restoreBackup(request);

  @override
  Future<DeleteBackupResponse> deleteBackup(DeleteBackupRequest request) =>
      _backup.deleteBackup(request);

  @override
  Future<void> close() => _channel.shutdown();
}

class _GrpcDaemonStream<T> implements DaemonStream<T> {
  _GrpcDaemonStream(this._response);

  final ResponseStream<T> _response;

  @override
  Stream<T> get events => _response;

  @override
  Future<void> cancel() => _response.cancel();
}
