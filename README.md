# gherkin_patrol

Lightweight Gherkin-style BDD for Flutter integration tests with Patrol.

This package provides:

- Step annotations such as `@Given`, `@When`, `@Then`, `@And`, `@But`
- Placeholder-based step patterns like `I enter "{email}"`
- Optional raw regex mode for advanced matching
- A `source_gen` builder that generates `generatedSteps`
- A tiny runner that executes `.feature` files with `PatrolTester`

It is intentionally small and opinionated: not a full Gherkin runtime, but a focused package for readable integration scenarios in Flutter apps.

## How it works

### Architecture overview

```text
                                  (consumer app)
+----------------------------------------------------------------------------+
| .feature files (gherkin text)                                              |
| e.g. integration_test/features/*.feature                                   |
+-------------------------------+--------------------------------------------+
                                |
                                | runtime
                                v
                  gherkin_runner_test.dart (Patrol)
                  ---------------------------------
                  - imports: gherkin_patrol
                  - imports: bdd/steps_registry.dart
                  - calls: runFeatureFile(path, $, steps)
                                |
                                v
                        steps_registry.dart (app)
                        -------------------------
                        final steps = combineSteps([
                          file1.generatedSteps,
                          file2.generatedSteps,
                          ...
                        ]);
                                ^
                                |
                                | build-time (codegen)
+-------------------------------+--------------------------------------------+
| steps file(s) in app                                                       |
| e.g. bdd/overview_steps.dart                                               |
|                                                                            |
| part 'overview_steps.bdd.g.dart';                                          |
|                                                                            |
| @Given("I am on the overview page")                                        |
| @When('I enter "{email}"')                                                 |
| @Then('I see "{screen}"')                                                  |
| @When('^REGEX:^I tap (.+)$')   // optional raw regex                       |
+-------------------------------+--------------------------------------------+
                                |
                                v
                     generated part files (*.bdd.g.dart)
                     -----------------------------------
                     final List<GeneratedStep> generatedSteps = [
                       GeneratedStep(
                         RegExp(..., caseSensitive: false),
                         stepFunction,
                         ['email']
                       ),
                       ...
                     ]


                            (package: gherkin_patrol)
+----------------------------------------------------------------------------+
| lib/src/annotations.dart                                                   |
|   @Given/@When/@Then/@And/@But/@Step                                       |
|                                                                            |
| lib/src/builder/step_generator.dart                                        |
|   - scans annotated step functions                                         |
|   - validates signature: Future<void> Function(PatrolTester $, StepMatch)  |
|   - compiles placeholders: "{email}" -> "(.+?)"                            |
|   - supports raw regex via '^REGEX:' prefix                                |
|   - emits *.bdd.g.dart                                                     |
|                                                                            |
| lib/src/builder/step_builder.dart                                          |
|   - PartBuilder wiring (build.yaml)                                        |
|                                                                            |
| lib/src/types.dart                                                         |
|   StepFn typedef                                                           |
|   StepMatch                                                                |
|   GeneratedStep                                                            |
|   combineSteps([...]) -> List<GeneratedStep>                               |
|                                                                            |
| lib/src/runner.dart                                                        |
|   runFeatureFile(path, $, List<GeneratedStep>)                             |
|   runFeatureContent(content, $, List<GeneratedStep>)                       |
|   - reads feature lines                                                    |
|   - strips Given/When/Then/And/But prefix                                  |
|   - iterates over steps                                                    |
|   - first matching step wins                                               |
|   - maps capture groups -> named args                                      |
|   - calls step.fn($, StepMatch)                                            |
|                                                                            |
| build.yaml                                                                 |
|   auto_apply: dependents                                                   |
+----------------------------------------------------------------------------+
```

### Build-time

1. You annotate top-level step functions.
2. The generator scans your step files.
3. It emits a `part` file containing:

```dart
final List<GeneratedStep> generatedSteps = <GeneratedStep>[...];
```

### Run-time

1. The runner reads a `.feature` file.
2. It keeps only executable step lines starting with `Given`, `When`, `Then`, `And`, or `But`.
3. It matches each line against generated step patterns.
4. On a match, it calls:

```dart
Future<void> Function(PatrolTester $, StepMatch match)
```

If no step matches, an exception is thrown.

## Project structure

```text
lib/
  gherkin_patrol.dart
  src/
    annotations.dart
    runner.dart
    types.dart
    builder/
      step_builder.dart
      step_generator.dart
build.yaml
```

## Installation

Add the package to your app `pubspec.yaml`.

### Install from Git

If you host the package in a Git repository, you can depend on it directly from a commit, branch, or tag.

Using a pinned commit is recommended for reproducible builds:

```yaml
dependencies:
  gherkin_patrol:
    git:
      url: git@github.com:your-org/gherkin_patrol.git
      ref: <commit-or-tag>
  patrol_finders: ^3.0.0

dev_dependencies:
  build_runner: ^2.4.11
```

You can also use a branch or tag:

```yaml
dependencies:
  gherkin_patrol:
    git:
      url: https://github.com/dexterBEN/gherkin_patrol.git
      ref: main
```

or

```yaml
dependencies:
  gherkin_patrol:
    git:
      url: git@github.com:your-org/gherkin_patrol.git
      ref: v0.1.0
```

Don't forget to add:

```yaml

dev_dependencies:
  build_runner: ^2.4.11
```

The builder is auto-applied via `build.yaml`, so consumers only need to run `build_runner`.

## Declare steps

```dart
import 'package:gherkin_patrol/gherkin_patrol.dart';
import 'package:patrol_finders/patrol_finders.dart';

part 'login_steps.bdd.g.dart';

@When('I enter "{email}" and "{password}"')
Future<void> enterCredentials(PatrolTester $, StepMatch match) async {
  final email = match['email'];
  final password = match['password'];

  // interact with the app here
}
```

Expected signature:

```dart
Future<void> stepName(PatrolTester $, StepMatch match)
```

## Pattern syntax

### Placeholder mode

Recommended for most steps:

```dart
@Then('I see the message "{message}"')
```

This generates a regex internally and maps captures into `StepMatch`.

### Raw regex mode

Use raw regex when you need full control:

```dart
@Then('^REGEX:^I see the message "(.+)"$')
```

In raw regex mode, no parameter names are inferred automatically, so `StepMatch.named` will usually stay empty unless you extend the generator behavior.

## Generate code

From the consumer app root:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Each step file must include a matching `part 'file_name.bdd.g.dart';`.

### Recommended: generate only step files

Because the builder is `auto_apply: dependents`, it may try to run on non-step files as well and emit warnings such as:

- `gherkin_runner_test.bdd.g.dart must be included as a part directive`
- `steps_registry.bdd.g.dart must be included as a part directive`

To avoid this, keep annotations only in dedicated step files and consider restricting generation in the consumer app `build.yaml`:

```yaml
targets:
  $default:
    builders:
      gherkin_patrol|step_builder:
        generate_for:
          - integration_test/steps/**.dart
```

## Run features

Aggregate the generated steps:

```dart
import 'package:gherkin_patrol/gherkin_patrol.dart';

import 'login_steps.dart' as login;
import 'overview_steps.dart' as overview;

final steps = combineSteps([
  login.generatedSteps,
  overview.generatedSteps,
]);
```

Run a feature:

```dart
await runFeatureFile('integration_test/features/login.feature', $, steps);
```

Example runner test:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gherkin_patrol/gherkin_patrol.dart';
import 'package:my_demo_app/main.dart';
import 'package:patrol_finders/patrol_finders.dart';

import 'steps/steps_registry.dart' as steps_registry;

void main() {
  const feature = String.fromEnvironment('FEATURE');

  patrolWidgetTest(
    'Run $feature',
    ($) async {
      await $.pumpWidgetAndSettle(const MyApp());
      await runFeatureFile(feature, $, steps_registry.steps);
    },
    semanticsEnabled: true,
    config: const PatrolTesterConfig(printLogs: true),
  );
}
```

And run it with:

```bash
flutter test -r expanded integration_test/gherkin_runner_test.dart \
  --dart-define=FEATURE=integration_test/features/counter.feature
```

## StepMatch

`StepMatch` gives you named access to extracted parameters:

```dart
match['email']
match.get('email')
match.named
```

`operator []` throws if the key is missing, which helps catch mismatches early.

## Assertions and semantics

Patrol works well for waiting on and targeting widgets, while `flutter_test` expectations remain useful for precise assertions.

Example:

```dart
@Then('I expect counter value to be "{value}"')
Future<void> expectCounterValue(PatrolTester $, StepMatch match) async {
  final counterValue = $(find.bySemanticsLabel('CounterValue'));
  final counterText = find.descendant(
    of: counterValue.finder,
    matching: find.text(match['value']),
  );

  await counterValue.waitUntilExists();
  expect(counterValue.exists, isTrue);
  expect(counterText, findsOneWidget);
}
```

### Note about semantics merging

If you wrap a widget with:

```dart
Semantics(
  container: true,
  label: 'CounterValue',
  child: Text('5'),
)
```

Flutter may merge the child text into the semantic label. In practice, the semantic output can become something like:

```text
CounterValue
5
```

If you need a more stable semantic label for testing, `excludeSemantics: true` can help:

```dart
Semantics(
  container: true,
  excludeSemantics: true,
  label: 'CounterValue',
  child: Text('5'),
)
```

For debugging, Flutter also provides:

```dart
debugDumpSemanticsTree();
```

This is useful to inspect the actual semantic labels generated by the framework.

## Test isolation and stability

- Reset DI and local state between scenarios
- Prefer `await $.tester.pumpAndSettle()`
- Use stable widget keys for important interactions

## FAQ

### `*.bdd.g.dart` is not generated

- Run `flutter pub run build_runner build -d`
- Ensure the file contains `part 'your_file.bdd.g.dart';`
- Check for analyzer or dependency conflicts

### `No matching step`

- Compare the exact `.feature` line with the annotation pattern
- Make sure the file's `generatedSteps` is included in your combined registry

## Roadmap

- Scenario outlines
- Hooks
- Multi-line steps
- More runtime helpers for Patrol flows

## License

BSD-3
