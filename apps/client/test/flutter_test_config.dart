import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

// Skia text rasterization differs slightly between Windows development hosts
// and Linux CI. Keep the allowance below a visible layout-level change while
// tolerating the measured cross-platform glyph edge variance.
const _goldenPixelTolerance = 0.02;

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  goldenFileComparator = _TolerantGoldenComparator(
    Directory.current.uri.resolve('test/goldens/flutter_test_config.dart'),
    tolerance: _goldenPixelTolerance,
  );
  await testMain();
}

class _TolerantGoldenComparator extends LocalFileComparator {
  _TolerantGoldenComparator(super.testFile, {required this.tolerance});

  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= tolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
