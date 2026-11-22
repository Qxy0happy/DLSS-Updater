import 'dart:ui' show AppExitResponse;

import 'data/daemon_connection.dart';

/// Handles the desktop exit request by shutting the sidecar down before the
/// window closes. Kept outside the widget tree so it is directly testable.
class AppExitHandler {
  AppExitHandler(this.connection);

  final DaemonConnection connection;

  Future<AppExitResponse> onExitRequested() async {
    await connection.shutdown();
    return AppExitResponse.exit;
  }
}
