import '../generated/dlss/v1/backup.pb.dart';
import '../generated/dlss/v1/backup.pbgrpc.dart';
import '../generated/dlss/v1/common.pb.dart';
import '../generated/dlss/v1/daemon.pb.dart';
import '../generated/dlss/v1/daemon.pbgrpc.dart';
import '../generated/dlss/v1/library.pb.dart';
import '../generated/dlss/v1/library.pbgrpc.dart';
import '../generated/dlss/v1/scan.pb.dart';
import '../generated/dlss/v1/scan.pbgrpc.dart';
import '../generated/dlss/v1/update.pb.dart';
import '../generated/dlss/v1/update.pbgrpc.dart';
import 'daemon_stream.dart';

export '../generated/dlss/v1/backup.pb.dart';
export '../generated/dlss/v1/common.pb.dart';
export '../generated/dlss/v1/daemon.pb.dart';
export '../generated/dlss/v1/library.pb.dart';
export '../generated/dlss/v1/scan.pb.dart';
export '../generated/dlss/v1/update.pb.dart';

/// The protocol seam of the frontend.
///
/// Each method maps one-to-one onto a generated `dlss.v1` client call, so a
/// widget test can substitute a fake without leaving the protocol: requests
/// and responses are always the generated messages. Repositories depend on
/// this interface; widgets depend on repositories.
abstract class DaemonApi {
  Future<Status> getStatus(GetStatusRequest request);

  Future<ShutdownResponse> shutdown(ShutdownRequest request);

  Future<ListGamesResponse> listGames(ListGamesRequest request);

  Future<Game> getGame(GetGameRequest request);

  DaemonStream<ScanEvent> startScan(StartScanRequest request);

  DaemonStream<UpdateEvent> startUpdate(StartUpdateRequest request);

  Future<ListBackupsResponse> listBackups(ListBackupsRequest request);

  Future<RestoreBackupResponse> restoreBackup(RestoreBackupRequest request);

  Future<DeleteBackupResponse> deleteBackup(DeleteBackupRequest request);

  /// Closes the underlying channel.
  Future<void> close();
}
