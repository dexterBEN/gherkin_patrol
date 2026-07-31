import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Reads a `.feature` file from the appropriate source depending on platform.
class FeatureFile {
  const FeatureFile(this.path);

  final String path;

  /// Loads the feature file contents.
  ///
  /// On Android/iOS, `.feature` files must be declared as Flutter assets and
  /// are read from the application bundle using [rootBundle].
  ///
  /// On desktop-style platforms, the file is read directly from disk.
  Future<String> read() async {
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
        case TargetPlatform.iOS:
          return await rootBundle.loadString(path);
        default:
          return await File(path).readAsString();
      }
    } catch (error) {
      throw Exception(
        'Could not load feature file: $path. '
        'On Android/iOS, declare the file under `flutter: assets:` in '
        'pubspec.yaml. On desktop platforms, ensure the file exists on disk. '
        'Error: $error',
      );
    }
  }
}
