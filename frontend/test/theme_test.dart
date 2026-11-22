import 'package:dlss_updater/src/app.dart';
import 'package:dlss_updater/src/app_info.dart';
import 'package:dlss_updater/src/ui/app_shell.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/fake_app_environment.dart';

void main() {
  testWidgets('follows the system theme in light mode', (tester) async {
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.light;
    addTearDown(
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
    );

    await tester.pumpWidget(DlssUpdaterApp(environment: fakeAppEnvironment()));
    await tester.pumpAndSettle();

    final theme = Theme.of(tester.element(find.byType(AppShell)));
    expect(theme.brightness, Brightness.light);
    expect(theme.useMaterial3, isTrue);
  });

  testWidgets('follows the system theme in dark mode', (tester) async {
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    addTearDown(
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
    );

    await tester.pumpWidget(DlssUpdaterApp(environment: fakeAppEnvironment()));
    await tester.pumpAndSettle();

    final theme = Theme.of(tester.element(find.byType(AppShell)));
    expect(theme.brightness, Brightness.dark);
    expect(theme.useMaterial3, isTrue);
  });

  testWidgets('Settings shows the injected app version', (tester) async {
    await tester.pumpWidget(DlssUpdaterApp(environment: fakeAppEnvironment()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text(appVersion), findsOneWidget);
  });
}
