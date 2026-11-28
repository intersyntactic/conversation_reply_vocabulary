// What a person said travels as JSON in a node's map form
// ({"shape": "<class name>", ...fields}), read strictly: an unknown shape, a
// field missing, extra or of the wrong type, or a malformed id, is refused.
import 'dart:convert';

import 'package:checked_json/checked_json.dart';
import 'package:is_conversation_vocabulary/is_conversation_vocabulary.dart';
import 'package:is_shapes/is_shapes.dart' show ActorId;
import 'package:test/test.dart';

void main() {
  final peter = ActorId.parse('teams:f6a2.../b901...')!;
  final agent = ActorId.parse('agent:7f3a9c21')!;

  group('UserSaid', () {
    test('writes exactly the JSON other packages already send', () {
      final said = UserSaid(
        author: peter,
        source: SourceMessageId.parse('1234567890.654321')!,
        text: '',
        quotes: Quote(
          source: SourceMessageId.parse('1234567890.123456')!,
          author: KnownAuthor(agent),
          preview: 'nearly there',
        ),
      );
      expect(
        jsonEncode(said.toJson()),
        '{"shape":"UserSaid","author":"teams:f6a2.../b901...",'
        '"source":"1234567890.654321","text":"",'
        '"quotes":{"source":"1234567890.123456",'
        '"author":{"shape":"KnownAuthor","actor":"agent:7f3a9c21"},'
        '"preview":"nearly there"}}',
      );
      expect(
        jsonEncode(
          UserSaid(
            author: peter,
            source: SourceMessageId.parse('1')!,
            text: 'who?',
            quotes: Quote(
              source: SourceMessageId.parse('2')!,
              author: const UnknownAuthor(null),
            ),
          ).toJson(),
        ),
        '{"shape":"UserSaid","author":"teams:f6a2.../b901...",'
        '"source":"1","text":"who?",'
        '"quotes":{"source":"2","author":{"shape":"UnknownAuthor"}}}',
      );
    });

    test('round-trips without a quote', () {
      final said = UserSaid(
        author: peter,
        source: SourceMessageId.parse('1234567890.123456')!,
        text: 'how is the demo coming?',
      );
      final back = UserSaid.fromJson(JsonObject.parse(said.toJson())!);
      expect(back.author, said.author);
      expect(back.source, said.source);
      expect(back.text, said.text);
      expect(back.quotes, isNull);
    });

    test('round-trips with a quote of a known author and a preview', () {
      final said = UserSaid(
        author: peter,
        source: SourceMessageId.parse('1234567890.654321')!,
        text: '',
        quotes: Quote(
          source: SourceMessageId.parse('1234567890.123456')!,
          author: KnownAuthor(agent),
          preview: 'nearly there',
        ),
      );
      final back = UserSaid.fromJson(JsonObject.parse(said.toJson())!);
      expect(back.quotes!.source, said.quotes!.source);
      expect(
        back.quotes!.author,
        isA<KnownAuthor>().having((a) => a.actor, 'actor', agent),
      );
      expect(back.quotes!.preview, 'nearly there');
    });

    test('round-trips a quote of an unknown author with a display name', () {
      final said = UserSaid(
        author: peter,
        source: SourceMessageId.parse('1234567890.654321')!,
        text: 'who said that?',
        quotes: Quote(
          source: SourceMessageId.parse('1234567890.123456')!,
          author: const UnknownAuthor('Sam'),
        ),
      );
      final back = UserSaid.fromJson(
        JsonObject.parse(jsonDecode(jsonEncode(said.toJson())))!,
      );
      expect(
        back.quotes!.author,
        isA<UnknownAuthor>().having((a) => a.displayName, 'name', 'Sam'),
      );
      expect(back.quotes!.preview, isNull);
    });

    test('refuses an unknown shape', () {
      expect(
        () => UserSaid.fromJson(
          JsonObject.of({
            'shape': 'SomethingElse',
            'author': 'teams:a',
            'source': 's',
            'text': 't',
          }),
        ),
        throwsFormatException,
      );
    });

    test('refuses a missing field', () {
      expect(
        () => UserSaid.fromJson(
          JsonObject.of({
            'shape': 'UserSaid',
            'author': 'teams:a',
            'source': 's',
          }),
        ),
        throwsA(isA<JsonFieldException>()),
      );
    });

    test('refuses an extra field', () {
      expect(
        () => UserSaid.fromJson(
          JsonObject.of({
            'shape': 'UserSaid',
            'author': 'teams:a',
            'source': 's',
            'text': 't',
            'extra': 'nope',
          }),
        ),
        throwsFormatException,
      );
    });

    test('refuses an extra field inside a quote and its author', () {
      expect(
        () => UserSaid.fromJson(
          JsonObject.of({
            'shape': 'UserSaid',
            'author': 'teams:a',
            'source': 's',
            'text': 't',
            'quotes': {
              'source': 'q',
              'author': {'shape': 'UnknownAuthor'},
              'extra': 'nope',
            },
          }),
        ),
        throwsFormatException,
      );
      expect(
        () => UserSaid.fromJson(
          JsonObject.of({
            'shape': 'UserSaid',
            'author': 'teams:a',
            'source': 's',
            'text': 't',
            'quotes': {
              'source': 'q',
              'author': {'shape': 'KnownAuthor', 'actor': 'teams:b', 'x': 1},
            },
          }),
        ),
        throwsFormatException,
      );
    });

    test('refuses a malformed actor id', () {
      expect(
        () => UserSaid.fromJson(
          JsonObject.of({
            'shape': 'UserSaid',
            'author': 'not an id',
            'source': 's',
            'text': 't',
          }),
        ),
        throwsA(isA<JsonFieldException>()),
      );
    });

    test('refuses a malformed source message id', () {
      expect(
        () => UserSaid.fromJson(
          JsonObject.of({
            'shape': 'UserSaid',
            'author': 'teams:a',
            'source': 'has space',
            'text': 't',
          }),
        ),
        throwsA(isA<JsonFieldException>()),
      );
    });
  });

  group('SourceMessageId', () {
    test('is refused when empty or holding whitespace', () {
      expect(SourceMessageId.parse(''), isNull);
      expect(SourceMessageId.parse(' 1'), isNull);
      expect(SourceMessageId.parse('1\n'), isNull);
      expect(
        SourceMessageId.parse('1234567890.123456')?.value,
        '1234567890.123456',
      );
    });
  });

  test('shapeName and shapeNames name exactly the top-level node shapes', () {
    expect(UserSaid.shapeName, 'UserSaid');
    expect(WhatChanged.shapeNames, {'Edited', 'Deleted', 'Restored'});
  });
}
