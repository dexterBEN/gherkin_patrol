import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

const _given = TypeChecker.typeNamedLiterally('Given', inPackage: 'gherkin_patrol');
const _when = TypeChecker.typeNamedLiterally('When', inPackage: 'gherkin_patrol');
const _then = TypeChecker.typeNamedLiterally('Then', inPackage: 'gherkin_patrol');
const _and = TypeChecker.typeNamedLiterally('And', inPackage: 'gherkin_patrol');
const _but = TypeChecker.typeNamedLiterally('But', inPackage: 'gherkin_patrol');
const _step = TypeChecker.typeNamedLiterally('Step', inPackage: 'gherkin_patrol');

class _CompiledPattern {
  _CompiledPattern(this.regexSource, this.paramNames);
  final String regexSource;
  final List<String> paramNames;
}

class StepGenerator extends Generator {
  @override
  FutureOr<String> generate(LibraryReader library, BuildStep buildStep) {
    final entries = <String>[];

    bool isStepAnnotated(Element e) =>
        _given.hasAnnotationOfExact(e) ||
        _when.hasAnnotationOfExact(e) ||
        _then.hasAnnotationOfExact(e) ||
        _and.hasAnnotationOfExact(e) ||
        _but.hasAnnotationOfExact(e) ||
        _step.hasAnnotationOfExact(e);

    String? patternFor(Element e) {
      for (final tc in [_given, _when, _then, _and, _but, _step]) {
        final ann = tc.firstAnnotationOfExact(e);
        if (ann != null) {
          final reader = ConstantReader(ann);
          return reader.peek('pattern')?.stringValue ??
              reader.read('pattern').stringValue;
        }
      }
      return null;
    }

    /// Using raw to avoid escaping character.
    String asRawLiteral(String pattern) {
      if (!pattern.contains("'")) return "r'$pattern'";
      if (!pattern.contains('"')) return 'r"$pattern"';
      // case where pattern contains ' and " => triple quotes
      return "r'''$pattern'''";
    }

    // Placeholders like {email}, {value}, {textFieldName} ...
    final placeholder = RegExp(r'\{([a-zA-Z_][a-zA-Z0-9_]*)\}');

    /// Compile a user-friendly pattern containing {param} into a regex + param names.
    ///
    /// Example:
    ///   I enter email "{email}"
    /// becomes:
    ///   ^I\ enter\ email\ "(.+?)"$
    ///
    /// If user wants to provide a raw regex, they can prefix with: ^REGEX:
    _CompiledPattern compileUserPattern(String pattern) {
      const rawPrefix = r'^REGEX:';
      if (pattern.startsWith(rawPrefix)) {
        // treat as raw regex; no param names
        return _CompiledPattern(pattern.substring(rawPrefix.length), const []);
      }

      final names = <String>[];
      final buffer = StringBuffer('^');
      var lastIndex = 0;

      for (final m in placeholder.allMatches(pattern)) {
        // literal text before the placeholder
        final literal = pattern.substring(lastIndex, m.start);
        buffer.write(RegExp.escape(literal));

        // capture group
        buffer.write('(.+?)');
        names.add(m.group(1)!);

        lastIndex = m.end;
      }

      // remaining literal text
      buffer.write(RegExp.escape(pattern.substring(lastIndex)));
      buffer.write(r'$');

      return _CompiledPattern(buffer.toString(), names);
    }

    for (final element in library.allElements.whereType<ExecutableElement>().where((e) => e.kind == ElementKind.FUNCTION)) {
      if (!isStepAnnotated(element)) continue;

      // Validate expected signature
      // Future<void> fn(PatrolTester $, StepMatch match)
      final function = element;
      final params = function.formalParameters;
      final returnsFuture = function.returnType.isDartAsyncFuture;
      final has2params = params.length == 2;
      final firstParam = has2params
          ? params[0].type.getDisplayString()
          : '';
      final secondParam = has2params
          ? params[1].type.getDisplayString()
          : '';

      final validSignature = returnsFuture &&
          has2params &&
          firstParam == 'PatrolTester' &&
          (secondParam == 'StepMatch' || secondParam.endsWith('.StepMatch'));

      if (!validSignature) {
        log.warning(
          'Invalid step signature for ${function.displayName} in '
          '${buildStep.inputId.uri}. Expected: '
          'Future<void> Function(PatrolTester, StepMatch)',
        );
        continue;
      }

      final pattern = patternFor(function);
      if (pattern == null) continue;

      final compiled = compileUserPattern(pattern);

      // Use raw string literal for regexSource
      final rawRegex = asRawLiteral(compiled.regexSource);

      // Generate a const list of param names
      final paramNamesLiteral = compiled.paramNames.isEmpty
          ? 'const <String>[]'
          : 'const <String>[${compiled.paramNames.map((n) => asRawLiteral(n)).join(', ')}]';

      entries.add(
        'GeneratedStep(RegExp($rawRegex, caseSensitive: false), ${function.displayName}, $paramNamesLiteral)',
      );
    }

    // ⚠️ No imports here - this file would be a "part of" auto-added by PartBuilder.
    return '''
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

final List<GeneratedStep> generatedSteps = <GeneratedStep>[
  ${entries.join(',\n  ')}
];
''';
  }
}
