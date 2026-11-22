import 'package:dlss_updater/src/ui/common/daemon_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:grpc/protos.dart' show ErrorInfo;

void main() {
  GrpcError withReason(
    String reason, {
    int code = StatusCode.failedPrecondition,
  }) {
    return GrpcError.custom(code, 'server text', [
      ErrorInfo(domain: 'dlss.v1', reason: reason),
    ]);
  }

  test('isDaemonUnavailable covers the transient gRPC codes only', () {
    expect(isDaemonUnavailable(GrpcError.unavailable('down')), isTrue);
    expect(
      isDaemonUnavailable(GrpcError.custom(StatusCode.unknown, 'gone')),
      isTrue,
    );
    expect(isDaemonUnavailable(GrpcError.deadlineExceeded('slow')), isTrue);
    expect(
      isDaemonUnavailable(GrpcError.custom(StatusCode.notFound, 'x')),
      isFalse,
    );
    expect(isDaemonUnavailable(StateError('local')), isFalse);
  });

  test('errorInfoFrom extracts the first ErrorInfo only from gRPC errors', () {
    final info = errorInfoFrom(withReason('BACKUP_MISSING'));
    expect(info?.reason, 'BACKUP_MISSING');
    expect(info?.domain, 'dlss.v1');

    expect(errorInfoFrom(GrpcError.unavailable('down')), isNull);
    expect(errorInfoFrom(StateError('local')), isNull);
  });

  test('failureReasonFrom exposes the stable reason token', () {
    expect(failureReasonFrom(withReason('METADATA_STALE')), 'METADATA_STALE');
    expect(failureReasonFrom(GrpcError.unavailable('down')), isNull);
  });

  test('cleanFailureDetail trims blank status messages away', () {
    expect(cleanFailureDetail(null), isNull);
    expect(cleanFailureDetail('   '), isNull);
    expect(cleanFailureDetail('  detail  '), 'detail');
  });
}
