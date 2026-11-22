import 'package:dlss_updater/src/app.dart';
import 'package:dlss_updater/src/ui/backups/backups_view.dart';
import 'package:dlss_updater/src/ui/games/games_view.dart';
import 'package:dlss_updater/src/ui/settings/settings_view.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app_environment.dart';

void main() {
  testWidgets('starts on Games and shows its empty state', (tester) async {
    await tester.pumpWidget(DlssUpdaterApp(environment: fakeAppEnvironment()));
    await tester.pumpAndSettle();

    expect(find.byType(GamesView), findsOneWidget);
    expect(find.text(GamesView.emptyTitle), findsOneWidget);
    expect(find.text(GamesView.emptyMessage), findsOneWidget);
  });

  testWidgets('navigates across all three destinations', (tester) async {
    await tester.pumpWidget(DlssUpdaterApp(environment: fakeAppEnvironment()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Backups'));
    await tester.pumpAndSettle();
    expect(find.byType(BackupsView), findsOneWidget);
    expect(find.text(BackupsView.emptyTitle), findsOneWidget);
    expect(find.text(BackupsView.emptyMessage), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsView), findsOneWidget);
    expect(find.text('App version'), findsOneWidget);

    await tester.tap(find.text('Games'));
    await tester.pumpAndSettle();
    expect(find.byType(GamesView), findsOneWidget);
  });
}
