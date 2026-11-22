import 'package:material_ui/material_ui.dart';

/// Widget keys for the update flow, shared by the destination and the detail
/// panel so widget tests do not depend on layout internals.
abstract final class UpdateKeys {
  static const Key selected = Key('games-update-selected');
  static const Key cancel = Key('games-update-cancel');
  static const Key progress = Key('games-update-progress');
  static const Key failure = Key('games-update-failure');
  static const Key retry = Key('games-update-retry');
  static const Key dismiss = Key('games-update-dismiss');
  static const Key summary = Key('games-update-summary');
  static const Key summaryDetails = Key('games-update-summary-details');
  static const Key dialog = Key('games-update-summary-dialog');
  static const Key dialogItems = Key('games-update-summary-items');
  static const Key dialogClose = Key('games-update-summary-close');
}
