import 'package:patrol_finders/patrol_finders.dart';

/// Named-only match object for step arguments.
///
/// - [named] contains {paramName -> value} extracted by the runner.
/// - Use [StepMatch.empty] for steps without parameters.
class StepMatch {
  const StepMatch(this.named);

  /// NEW: built un match "named" clean
  const StepMatch.named(Map<String, String> args) : named = args;

  final Map<String, String> named;

  /// Reusable empty match (no parameters).
  static const StepMatch empty = StepMatch(<String, String>{});

  /// Convenient access: match['email'].
  ///
  /// Throws a clear error if the argument is missing (better than silently returning '').
  String operator [](String name) =>
      named[name] ??
      (throw StateError(
        'Missing step argument "$name". Available: ${named.keys.toList()}',
      ));

  /// Nullable access if you want to handle missing keys manually.
  String? get(String name) => named[name];
}

/// Step signature: receives the tester + a named match.
typedef StepFn = Future<void> Function(PatrolTester $, StepMatch match);

/// A generated step = pattern + function + parameter names (in capture order).
class GeneratedStep {
  const GeneratedStep(this.pattern, this.fn, this.paramNames);

  final RegExp pattern;
  final StepFn fn;
  final List<String> paramNames;
}

/// Utils to concatenate multiple lists of steps.
List<GeneratedStep> combineSteps(Iterable<List<GeneratedStep>> all) =>
    [for (final l in all) ...l];
