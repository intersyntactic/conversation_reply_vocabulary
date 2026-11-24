// A reply's text is never blank, and is kept exactly as given: what the
// airlock approves and the logbook records is what is sent.
import 'dart:convert';

import 'package:is_reply_vocabulary/is_reply_vocabulary.dart';
import 'package:test/test.dart';

void main() {
  test('blank text is not reply text', () {
    for (final s in ['', ' ', '   ', '\n', '\t', ' \n\t\r\n ', ' ']) {
      expect(ReplyText.parse(s), isNull, reason: jsonEncode(s));
    }
  });

  test('reply text is kept exactly as given, never trimmed', () {
    for (final s in [
      'hi',
      ' hi',
      'hi ',
      '\n hi \t\n',
      'Grüße, 你好 👋',
      'line one\nline two',
    ]) {
      expect(ReplyText.parse(s)?.value, s, reason: jsonEncode(s));
    }
  });

  test('a zero-width character is not whitespace to trim, so it is text', () {
    expect(ReplyText.parse('​')?.value, '​');
  });

  test('reply text reads back from its JSON as itself', () {
    final text = ReplyText.parse(' Grüße 👋\n')!;
    final json = jsonDecode(jsonEncode(encodeReplyText(text)));
    expect(decodeReplyText(json, 'text'), text);
  });

  test('anything else is refused, naming the field', () {
    for (final json in <Object?>[
      null,
      '',
      ' \n',
      42,
      ['hi'],
      {'text': 'hi'},
    ]) {
      expect(
        () => decodeReplyText(json, 'text'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            startsWith('text'),
          ),
        ),
        reason: '$json',
      );
    }
  });
}
