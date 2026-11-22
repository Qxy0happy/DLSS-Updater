/// Shared decoding of the daemon's `google.rpc.Status` details.
///
/// Games, update and backups all branch on the stable `ErrorInfo.reason` and
/// all treat a temporarily missing sidecar the same way. Keeping the parsing
/// in one place stops the three features from drifting apart.
library;

import 'package:grpc/grpc.dart';
import 'package:grpc/protos.dart' show ErrorInfo;

export '../../data/daemon_client.dart' show isDaemonUnavailable;

/// Returns the first `google.rpc.ErrorInfo` attached to [error], or null when
/// the status carries none (or is not a gRPC status at all).
ErrorInfo? errorInfoFrom(Object error) {
  if (error is! GrpcError) return null;
  final details = error.details;
  if (details == null) return null;
  for (final detail in details) {
    if (detail is ErrorInfo) return detail;
  }
  return null;
}

/// The stable `ErrorInfo.reason` token of [error], or null.
String? failureReasonFrom(Object error) => errorInfoFrom(error)?.reason;

/// Trims a status message kept only as secondary detail; an empty message
/// becomes null so the UI renders no blank line.
String? cleanFailureDetail(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
