// A conversation's kind is read back exactly as written, and only so.
import 'package:is_conversation_vocabulary/is_conversation_vocabulary.dart';
import 'package:test/test.dart';

void main() {
  test('each kind reads back from its wire form', () {
    for (final kind in ConversationKind.values) {
      expect(ConversationKind.parse(kind.wire), kind);
    }
  });

  test('the wire forms are fixed', () {
    expect(
      {for (final kind in ConversationKind.values) kind.wire},
      {
        'one-to-one',
        'group-chat',
        'public-channel',
        'private-channel',
        'not-known',
      },
    );
  });

  test('anything else is refused', () {
    for (final s in ['', 'channel', 'oneToOne', 'ONE-TO-ONE', ' not-known']) {
      expect(ConversationKind.parse(s), isNull, reason: s);
    }
  });
}
