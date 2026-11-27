import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:test/test.dart';

/// Every URI a source's directives name, in every branch, as written.
///
/// Read from the parse tree, which knows comments, strings and metadata, so
/// none of them can hide a directive or cut one short. The tree keeps every
/// branch of a conditional import (the element model keeps only the one it
/// picked), and `import 'stub.dart' if (dart.library.io) 'dart:io';` names
/// both.
Iterable<StringLiteral> directiveUris(String source) sync* {
  final unit = parseString(content: source, throwIfDiagnostics: false).unit;
  // Over every directive, unfiltered and exhaustive, so a new kind of
  // directive stops this compiling.
  for (final directive in unit.directives) {
    yield* switch (directive) {
      NamespaceDirective(:final uri, :final configurations) => [
        uri,
        for (final branch in configurations) branch.uri,
      ],
      PartDirective(:final uri) => [uri],
      LibraryDirective() || PartOfDirective() => const <StringLiteral>[],
    };
  }
}

/// A vocabulary may depend only on other vocabularies and `checked_json`,
/// and here on `is_shapes` for [_fromShapes] alone: an actor's id is a
/// word no one program owns, and `is_shapes` depends only on
/// `is_content_id`.
bool _allowedPackage(String name) =>
    name.endsWith('_vocabulary') ||
    name == 'checked_json' ||
    name == _shapesPackage;

const _shapesPackage = 'is_shapes';

/// The only names this package takes from [_shapesPackage].
const _fromShapes = {'ActorId'};

/// Every directive in [source] naming [_shapesPackage] that takes more than
/// [_fromShapes], or isn't narrowed by a `show` at all.
Iterable<String> _wideShapesImports(String source) sync* {
  final unit = parseString(content: source, throwIfDiagnostics: false).unit;
  for (final directive in unit.directives.whereType<NamespaceDirective>()) {
    final target = directive.uri.stringValue;
    if (target == null) continue;
    final uri = Uri.parse(target);
    if (uri.scheme != 'package' || uri.pathSegments.first != _shapesPackage) {
      continue;
    }
    final shown = {
      for (final combinator in directive.combinators)
        if (combinator is ShowCombinator)
          for (final name in combinator.shownNames) name.name,
    };
    final narrowed =
        directive is ImportDirective &&
        directive.combinators.every((c) => c is ShowCombinator) &&
        shown.isNotEmpty &&
        _fromShapes.containsAll(shown);
    if (!narrowed) yield directive.toSource();
  }
}

bool _allowed(String target) {
  final uri = Uri.parse(target);
  return switch (uri.scheme) {
    'dart' => target == 'dart:core',
    'package' => _allowedPackage(uri.pathSegments.first),
    '' => !uri.isAbsolute && !uri.pathSegments.contains('..'),
    _ => false,
  };
}

void main() {
  test('the vocabulary imports only dart:core and other vocabularies', () {
    final violations = <String>[];
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      for (final literal in directiveUris(file.readAsStringSync())) {
        // Null when the URI is not one plain string, so cannot be checked.
        final target = literal.stringValue;
        if (target == null || !_allowed(target)) {
          violations.add('${file.path}: ${target ?? literal.toSource()}');
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason: 'a vocabulary holds types and does nothing',
    );
  });

  test('is_shapes is imported for ActorId alone, and never re-exported', () {
    final violations = [
      for (final file in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>())
        if (file.path.endsWith('.dart'))
          for (final wide in _wideShapesImports(file.readAsStringSync()))
            '${file.path}: $wide',
    ];
    expect(violations, isEmpty);
  });

  test('a wide or re-exported is_shapes directive is caught', () {
    expect(
      _wideShapesImports("import 'package:is_shapes/is_shapes.dart';"),
      hasLength(1),
    );
    expect(
      _wideShapesImports(
        "import 'package:is_shapes/is_shapes.dart' show ActorId, TurnId;",
      ),
      hasLength(1),
    );
    expect(
      _wideShapesImports(
        "import 'package:is_shapes/is_shapes.dart' hide TurnId;",
      ),
      hasLength(1),
    );
    expect(
      _wideShapesImports(
        "export 'package:is_shapes/is_shapes.dart' show ActorId;",
      ),
      hasLength(1),
    );
    expect(
      _wideShapesImports(
        "import 'package:is_shapes/is_shapes.dart' show ActorId;",
      ),
      isEmpty,
    );
  });
}
