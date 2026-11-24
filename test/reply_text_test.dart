// A reply's text is never blank, and is kept exactly as given: what the
// airlock approves and the logbook records is what is sent.
import 'dart:convert';

import 'package:is_reply_vocabulary/is_reply_vocabulary.dart';
import 'package:test/test.dart';

void main() {
  test('whitespace or format characters alone are not reply text', () {
    for (final s in [
      '',
      ' ',
      '\n',
      '\t',
      ' \n\t\r\n ',
      '\u{a0}',
      '\u{3000}',
      '\u{200b}',
      '\u{200c}',
      '\u{200d}',
      '\u{2060}',
      '\u{feff}',
      '\u{ad}',
      '\u{200e}',
      '\u{e0001}',
      '\u{a0}\u{200b}',
      '\u{200b} \u{2060}\u{feff}',
    ]) {
      expect(ReplyText.parse(s), isNull, reason: jsonEncode(s));
    }
  });

  test('reply text is kept exactly as given, never trimmed', () {
    for (final s in [
      'hi',
      ' hi',
      'hi ',
      '\n hi \t\n',
      '\u{200b}hi\u{200b}',
      '\u{e9}',
      '\u{1f44d}',
      '\u{1f1e6}\u{1f1fa}',
      // A tag-sequence flag: its tag characters are Cf, its first is not.
      '\u{1f3f4}\u{e0067}\u{e0062}\u{e0073}\u{e0063}\u{e0074}\u{e007f}',
      'Gr\u{fc}\u{df}e, \u{4f60}\u{597d} \u{1f44b}',
      'line one\nline two',
    ]) {
      expect(ReplyText.parse(s)?.value, s, reason: jsonEncode(s));
    }
  });

  test('a letter or symbol that renders as nothing is still text', () {
    for (final s in ['\u{3164}', '\u{2800}']) {
      expect(ReplyText.parse(s)?.value, s, reason: jsonEncode(s));
    }
  });

  test('reply text reads back from its JSON as itself', () {
    final text = ReplyText.parse(' Gr\u{fc}\u{df}e \u{1f44b}\n')!;
    final json = jsonDecode(jsonEncode(encodeReplyText(text)));
    expect(decodeReplyText(json, 'text'), text);
  });

  test('anything else is refused, naming the field', () {
    for (final json in <Object?>[
      null,
      '',
      ' \n',
      '\u{200b}',
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
