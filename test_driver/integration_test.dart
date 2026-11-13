import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Saves the screenshots the integration test takes into build/screenshots/.
Future<void> main() async {
  await integrationDriver(
    onScreenshot:
        (String name, List<int> image, [Map<String, Object?>? args]) async {
          final file = File('build/screenshots/$name.png');
          await file.create(recursive: true);
          await file.writeAsBytes(image);
          return true;
        },
  );
}
