// A reply's text and footer are read back exactly as written, and
// strictly, since both leave the machine.
import 'dart:convert';

import 'package:is_conversation_vocabulary/is_conversation_vocabulary.dart';
import 'package:test/test.dart';

final _text = ReplyText.parse('Done: the draft is in the folder.')!;
final _footer = ReplyText.parse('turn 3 \u{b7} context 152k of 200k (76%)')!;

void main() {
  test('content with and without a footer reads back as itself', () {
    for (final content in [
      ReplyContent(text: _text, footer: _footer),
      ReplyContent(text: _text),
    ]) {
      final json = jsonDecode(jsonEncode(encodeReplyContent(content)));
      expect(decodeReplyContent(json, 'content'), content);
    }
  });

  test('content is written as its text, and its footer when there is one', () {
    expect(
      jsonEncode(encodeReplyContent(ReplyContent(text: _text))),
      '{"text":"Done: the draft is in the folder."}',
    );
    expect(
      jsonEncode(
        encodeReplyContent(ReplyContent(text: _text, footer: _footer)),
      ),
      '{"text":"Done: the draft is in the folder.",'
      '"footer":"turn 3 \u{b7} context 152k of 200k (76%)"}',
    );
  });

  test('anything else is refused, naming the field', () {
    final good = encodeReplyContent(ReplyContent(text: _text, footer: _footer));
    for (final json in <Object?>[
      null,
      'Done',
      [good],
      good.without({'text'}),
      good.withFields({'text': ''}),
      good.withFields({'text': ' \n'}),
      good.withFields({'text': 7}),
      good.withFields({'footer': null}),
      good.withFields({'footer': '\u{200b}'}),
      good.withFields({'footer': 3}),
      good.withFields({'extra': 1}),
    ]) {
      expect(
        () => decodeReplyContent(json, 'content'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            startsWith('content'),
          ),
        ),
        reason: '$json',
      );
    }
  });
}
