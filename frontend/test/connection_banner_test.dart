import 'package:dlss_updater/src/data/daemon_connection.dart';
import 'package:dlss_updater/src/ui/connection_banner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'support/fake_app_environment.dart';

Widget host(DaemonConnection connection) {
  return ChangeNotifierProvider<DaemonConnection>.value(
    value: connection,
    child: const MaterialApp(home: Scaffold(body: ConnectionBanner())),
  );
}

void main() {
  testWidgets('shows the starting state', (tester) async {
    final connection = FakeDaemonConnection(
      initialStatus: DaemonConnectionStatus.starting,
    );
    await tester.pumpWidget(host(connection));

    expect(find.text(ConnectionBanner.startingLabel), findsOneWidget);
    expect(find.byKey(const Key('daemon-retry')), findsNothing);
  });

  testWidgets('shows the connected state', (tester) async {
    final connection = FakeDaemonConnection();
    await tester.pumpWidget(host(connection));

    expect(find.text(ConnectionBanner.connectedLabel), findsOneWidget);
  });

  testWidgets('shows the reconnecting state', (tester) async {
    final connection = FakeDaemonConnection(
      initialStatus: DaemonConnectionStatus.reconnecting,
    );
    await tester.pumpWidget(host(connection));

    expect(find.text(ConnectionBanner.reconnectingLabel), findsOneWidget);
    expect(find.byKey(const Key('daemon-retry')), findsNothing);
  });

  testWidgets('unavailable keeps the last error and offers retry', (
    tester,
  ) async {
    final connection = FakeDaemonConnection(
      initialStatus: DaemonConnectionStatus.unavailable,
      initialError: 'The daemon exited unexpectedly (exit code 1).',
    );
    await tester.pumpWidget(host(connection));

    expect(find.text(ConnectionBanner.unavailableLabel), findsOneWidget);
    expect(
      find.text('The daemon exited unexpectedly (exit code 1).'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('daemon-retry')));
    expect(connection.retryCalls, 1);
  });

  testWidgets('reacts to state changes from the controller', (tester) async {
    final connection = FakeDaemonConnection(
      initialStatus: DaemonConnectionStatus.starting,
    );
    await tester.pumpWidget(host(connection));

    connection.setStatus(DaemonConnectionStatus.connected);
    await tester.pump();

    expect(find.text(ConnectionBanner.connectedLabel), findsOneWidget);
  });
}
