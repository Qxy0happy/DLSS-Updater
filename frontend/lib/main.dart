import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'src/app.dart';
import 'src/app_environment.dart';
import 'src/bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppEnvironment environment;
  try {
    environment = await bootstrap();
  } catch (error) {
    runApp(StartupErrorApp(error: error));
    return;
  }
  runApp(DlssUpdaterApp(environment: environment));
  unawaited(environment.connection.start());
}
