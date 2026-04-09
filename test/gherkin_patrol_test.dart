import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';
import 'package:gherkin_patrol/gherkin_patrol.dart';

void main() {
  patrolWidgetTest(
    'runFeatureContent: matches regex and passes empty StepMatch when no paramNames',
    ($) async {
      var executed = false;

      final steps = <GeneratedStep>[
        GeneratedStep(
          RegExp(r'^hello (\w+)$', caseSensitive: false),
          (p, m) async {
            // Since paramNames is empty, named must be empty too
            expect(m.named, isEmpty);
            executed = true;
          },
          const <String>[], // no param names
        ),
      ];

      const feature = '''
        Feature: Hello
        Scenario: Say hi
        Given hello Bob
      ''';

      await runFeatureContent(feature, $, steps);
      expect(executed, isTrue);
    },
  );

  patrolWidgetTest(
    'runFeatureContent: maps capture groups to named args using paramNames',
    ($) async {
      var executed = false;

      final steps = <GeneratedStep>[
        GeneratedStep(
          RegExp(r'^hello (\w+)$', caseSensitive: false),
          (p, m) async {
            expect(m.named, {'name': 'Bob'});
            expect(m['name'], 'Bob');
            executed = true;
          },
          const <String>['name'],
        ),
      ];

      const feature = '''
        Feature: Hello
        Scenario: Say hi
        Given hello Bob
      ''';

      await runFeatureContent(feature, $, steps);
      expect(executed, isTrue);
    },
  );

  patrolWidgetTest(
    'runFeatureContent: supports multiple named params mapping',
    ($) async {
      var executed = false;

      // Simulates what the generator would produce for:
      // @When('I enter email "{email}" and password "{password}"')
      final steps = <GeneratedStep>[
        GeneratedStep(
          RegExp(r'^I enter email "(.+?)" and password "(.+?)"$',
              caseSensitive: false),
          (p, m) async {
            expect(m.named['email'], 'bob@example.com');
            expect(m.named['password'], 's3cr3t');

            // convenient accessor
            expect(m['email'], 'bob@example.com');
            expect(m['password'], 's3cr3t');

            executed = true;
          },
          const <String>['email', 'password'],
        ),
      ];

      const feature = '''
        Feature: Auth
        Scenario: Login
        When I enter email "bob@example.com" and password "s3cr3t"
      ''';

      await runFeatureContent(feature, $, steps);
      expect(executed, isTrue);
    },
  );

  test('combineSteps concatenates lists in order', () {
    final a = <GeneratedStep>[
      GeneratedStep(RegExp('a'), (PatrolTester _, StepMatch __) async {},
          const <String>[]),
    ];
    final b = <GeneratedStep>[
      GeneratedStep(RegExp('b'), (PatrolTester _, StepMatch __) async {},
          const <String>[]),
    ];

    final merged = combineSteps([a, b]);
    expect(merged.length, 2);
    expect(merged.first.pattern.pattern, 'a');
    expect(merged.last.pattern.pattern, 'b');
  });

  patrolWidgetTest('runFeatureContent: throws when no matching step', ($) async {
    const feature = '''
      Feature: Missing
      Scenario: No step
      Given this step does not exist
    ''';

    final steps = <GeneratedStep>[
      GeneratedStep(RegExp(r'^hello (\w+)$'), (p, m) async {},
          const <String>[]),
    ];

    expect(
      () => runFeatureContent(feature, $, steps),
      throwsA(isA<Exception>()),
    );
  });

  patrolWidgetTest(
    'StepMatch operator[] throws if required arg is missing',
    ($) async {
      // This test matches the "strict" StepMatch operator[] implementation.
      // If you decided to keep operator[] returning '' for missing keys,
      // remove this test or change expectation accordingly.
      final m = StepMatch.empty;

      expect(
        () => m['missing'],
        throwsA(isA<StateError>()),
      );
    },
  );
}
