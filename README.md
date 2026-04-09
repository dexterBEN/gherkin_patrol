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
      url: git@github.com:your-org/gherkin_patrol.git
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
flutter pub run build_runner build -d
```

Each step file must include a matching `part 'file_name.bdd.g.dart';`.

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

## StepMatch

`StepMatch` gives you named access to extracted parameters:

```dart
match['email']
match.get('email')
match.named
```

`operator []` throws if the key is missing, which helps catch mismatches early.

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
