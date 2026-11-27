// What a message became at its source travels in the same node map form as
// the message itself, read as strictly.
import 'dart:convert';

import 'package:checked_json/checked_json.dart';
import 'package:is_conversation_vocabulary/is_conversation_vocabulary.dart';
import 'package:is_shapes/is_shapes.dart' show ActorId;
import 'package:test/test.dart';

void main() {
  test('writes exactly the JSON other packages already send', () {
    expect(
      jsonEncode(
        Edited(
          text: 'actually, tomorrow',
          quotes: Quote(
            source: SourceMessageId.parse('1234567890.123456')!,
            author: const UnknownAuthor('Sam'),
          ),
        ).toJson(),
      ),
      '{"shape":"Edited","text":"actually, tomorrow",'
      '"quotes":{"source":"1234567890.123456",'
      '"author":{"shape":"UnknownAuthor","displayName":"Sam"}}}',
    );
    expect(
      jsonEncode(const Edited(text: '').toJson()),
      '{"shape":"Edited","text":""}',
    );
    expect(jsonEncode(const Deleted().toJson()), '{"shape":"Deleted"}');
    expect(jsonEncode(const Restored().toJson()), '{"shape":"Restored"}');
  });

  test('round-trips Edited with a new quote', () {
    final changed = Edited(
      text: 'actually, tomorrow',
      quotes: Quote(
        source: SourceMessageId.parse('1234567890.123456')!,
        author: KnownAuthor(ActorId.parse('agent:7f3a9c21')!),
      ),
    );
    final back = WhatChanged.fromJson(JsonObject.parse(changed.toJson())!);
    expect(
      back,
      isA<Edited>()
          .having((e) => e.text, 'text', 'actually, tomorrow')
          .having((e) => e.quotes, 'quotes', isNotNull),
    );
  });

  test('round-trips Edited with no quote', () {
    final back = WhatChanged.fromJson(
      JsonObject.parse(const Edited(text: 'fixed a typo').toJson())!,
    );
    expect(back, isA<Edited>().having((e) => e.quotes, 'quotes', isNull));
  });

  test('round-trips Deleted and Restored', () {
    expect(
      WhatChanged.fromJson(JsonObject.parse(const Deleted().toJson())!),
      isA<Deleted>(),
    );
    expect(
      WhatChanged.fromJson(JsonObject.parse(const Restored().toJson())!),
      isA<Restored>(),
    );
  });

  test('refuses an unknown shape', () {
    expect(
      () => WhatChanged.fromJson(const JsonObject.of({'shape': 'Archived'})),
      throwsFormatException,
    );
  });

  test('refuses an extra field on Deleted', () {
    expect(
      () => WhatChanged.fromJson(
        const JsonObject.of({'shape': 'Deleted', 'text': 'should not be here'}),
      ),
      throwsFormatException,
    );
  });

  test('refuses a missing field on Edited', () {
    expect(
      () => WhatChanged.fromJson(const JsonObject.of({'shape': 'Edited'})),
      throwsA(isA<JsonFieldException>()),
    );
  });
}
