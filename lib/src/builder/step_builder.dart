import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'step_generator.dart';

Builder stepBuilder(BuilderOptions options) =>
    PartBuilder([StepGenerator()], '.bdd.g.dart', header: '// coverage:ignore-file');
