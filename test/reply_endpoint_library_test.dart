// lib/reply_endpoint.dart is imported by code that must never load a decoder
// of what strangers sent, so what it reaches is pinned exactly: a new import
// in any file it reaches fails here, in this package, before any consumer.
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:is_conversation_vocabulary/reply_endpoint.dart';
import 'package:test/test.dart';

/// Every file under lib/ that [entry] reaches through relative directives,
/// and every package URI it names, read from each file's parse tree.
({Set<String> files, Set<String> packages}) reach(String entry) {
  final files = <String>{};
  final packages = <String>{};
  final pending = [File(entry).absolute.uri];
  while (pending.isNotEmpty) {
    final uri = pending.removeLast();
    final path = File.fromUri(uri).path;
    if (!files.add(path)) continue;
    final unit = parseString(
      content: File(path).readAsStringSync(),
      throwIfDiagnostics: false,
    ).unit;
    for (final directive in unit.directives) {
      final targets = switch (directive) {
        NamespaceDirective(:final uri, :final configurations) => [
          uri,
          for (final branch in configurations) branch.uri,
        ],
        PartDirective(:final uri) => [uri],
        LibraryDirective() || PartOfDirective() => const <StringLiteral>[],
      };
      for (final literal in targets) {
        final target = literal.stringValue;
        if (target == null) {
          packages.add(literal.toSource());
        } else if (Uri.parse(target).hasScheme) {
          packages.add(target);
        } else {
          pending.add(uri.resolve(target));
        }
      }
    }
  }
  final lib = Directory('lib').absolute.path;
  return (
    files: {for (final f in files) f.substring(lib.length + 1)},
    packages: packages,
  );
}

void main() {
  test('reaches only the endpoint and what it is built from', () {
    final reached = reach('lib/reply_endpoint.dart');
    expect(reached.files, {
      'reply_endpoint.dart',
      'src/reply_endpoint.dart',
      'src/reply_endpoint_case.dart',
      'src/strict_object_reader.dart',
      'src/whatsapp_chat.dart',
    });
    expect(reached.packages, {
      'package:checked_json/checked_json.dart',
      'package:is_web_address_vocabulary/is_web_address_vocabulary.dart',
    });
  });

  test('the walk sees what the whole library reaches', () {
    final reached = reach('lib/is_conversation_vocabulary.dart');
    expect(reached.files, contains('src/user_said.dart'));
    expect(reached.files, contains('src/what_changed.dart'));
  });

  test('exports the endpoint and its JSON', () {
    expect(decodeReplyEndpoint, isA<Function>());
    expect(encodeReplyEndpoint, isA<Function>());
  });
}
