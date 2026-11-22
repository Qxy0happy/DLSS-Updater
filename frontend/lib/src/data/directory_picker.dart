import 'package:file_selector/file_selector.dart';

/// Directory chooser seam. Widget tests inject a fake; the app uses the Linux
/// native file selector.
abstract class DirectoryPicker {
  Future<String?> pickDirectory({String? initialDirectory});
}

/// Real picker backed by the platform file selector.
class NativeDirectoryPicker implements DirectoryPicker {
  const NativeDirectoryPicker();

  @override
  Future<String?> pickDirectory({String? initialDirectory}) {
    return getDirectoryPath(
      initialDirectory: initialDirectory,
      confirmButtonText: 'Choose',
    );
  }
}
