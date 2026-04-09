import 'dart:io';
import 'package:patrol_finders/patrol_finders.dart';
import 'types.dart';

final _stepPrefix =
    RegExp(r'^(?:Given|When|Then|And|But)\s+', caseSensitive: false);

/// Execute a .feature file with all provided steps.
Future<void> runFeatureFile(
  String path,
  PatrolTester $,
  List<GeneratedStep> steps,
) async {
  final content = await File(path).readAsString();
  await runFeatureContent(content, $, steps);
}

/// Same thing as above but with a string.
Future<void> runFeatureContent(
  String content,
  PatrolTester $,
  List<GeneratedStep> steps,
) async {
  final lines = content
      .split('\n')
      .map((l) => l.trim())
      .where(_stepPrefix.hasMatch) // keep only steps (raw sentences)
      .toList();

  for (final raw in lines) {
    final line = raw.replaceFirst(_stepPrefix, ''); // remove Given/When/Then…
    var matched = false;

    for (final step in steps) {
      final m = step.pattern.firstMatch(line);
      if (m == null) continue;

      final named = <String, String>{};

      // Map capture groups (1..n) to param names (0..n-1)
      // If there are more captures than names, extras are ignored.
      // If there are more names than captures, missing values are omitted.
      final max = step.paramNames.length < m.groupCount
          ? step.paramNames.length
          : m.groupCount;

      for (var i = 0; i < max; i++) {
        final groupValue = m.group(i + 1);
        if (groupValue != null) {
          named[step.paramNames[i]] = groupValue;
        }
      }

      await step.fn($, named.isEmpty ? StepMatch.empty : StepMatch(named));
      matched = true;
      break;
    }

    if (!matched) {
      throw Exception('No matching step: $raw');
    }
  }
}
