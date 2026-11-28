// What a reply posted is read back exactly as written, and strictly: the
// logbook records it as what was posted, so nothing about it may be
// guessed. A logbook from before 0.2.0 still reads.
import 'dart:convert';

import 'package:is_conversation_vocabulary/is_conversation_vocabulary.dart';
import 'package:is_web_address_vocabulary/is_web_address_vocabulary.dart'
    show AddressPrefix, Origin, PathPrefix, WebPath;
import 'package:test/test.dart';

final _teamsEndpoint = RepliesUnderWebAddress(
  AddressPrefix.of(
    Origin.parse('https://smba.trafficmanager.net')!,
    PathPrefix.parse('/amer/v3/conversations/19:x/activities/')!,
  ),
);

final _slackEndpoint = RepliesWithPinnedBodyFields.at(
  origin: Origin.parse('https://slack.com')!,
  path: WebPath.parse('/api/chat.postMessage')!,
  pinned: PinnedBodyFields.of({'channel': 'C0123ABC'})!,
)!;

final _teams = PostedUnderWebAddress.answering(
  _teamsEndpoint,
  ServerAssignedMessageId.parse('1:1aBcD2eFgH')!,
);

final _slack = PostedWithPinnedBodyFields.answering(
  _slackEndpoint,
  ServerAssignedMessageId.parse('1700000000.000200')!,
);

void main() {
  test(
    'a posted message is in the conversation of the endpoint it answers',
    () {
      expect(_teams.prefix, _teamsEndpoint.prefix);
      expect(_slack.pinned, _slackEndpoint.pinned);
    },
  );

  test('each case reads back from its JSON text as itself', () {
    for (final message in <PostedMessage>[_teams, _slack]) {
      final text = jsonEncode(encodePostedMessage(message));
      expect(decodePostedMessage(jsonDecode(text), 'posted'), message);
    }
  });

  test('each case is written as its fields, named as its endpoint is', () {
    expect(
      jsonEncode(encodePostedMessage(_slack)),
      '{"case":"with-pinned-body-fields",'
      '"pinned":{"mustEqual":{"channel":"C0123ABC"}},'
      '"id":"1700000000.000200"}',
    );
    expect(
      jsonEncode(encodePostedMessage(_teams)),
      '{"case":"under-web-address","addressPrefix":'
      '{"origin":"https://smba.trafficmanager.net",'
      '"pathPrefix":"/amer/v3/conversations/19:x/activities/"},'
      '"id":"1:1aBcD2eFgH"}',
    );
  });

  test('a Slack message as a logbook before 0.2.0 wrote it reads as the '
      'pinned message it meant', () {
    expect(
      decodePostedMessage(
        jsonDecode(
          '{"case":"in-slack-conversation","channel":"C0123ABC",'
          '"timestamp":"1700000000.000200"}',
        ),
        'posted',
      ),
      _slack,
    );
  });

  test('anything else is refused, naming the field', () {
    final slack = encodePostedMessage(_slack);
    final teams = encodePostedMessage(_teams);
    final oldSlack = {
      'case': 'in-slack-conversation',
      'channel': 'C0123ABC',
      'timestamp': '1700000000.000200',
    };
    for (final json in <Object?>[
      null,
      'C0123ABC',
      [slack],
      slack.withFields({'case': 'somewhere-else'}),
      slack.withFields({'case': null}),
      slack.without({'case'}),
      slack.without({'pinned'}),
      slack.without({'id'}),
      slack.withFields({'id': ''}),
      slack.withFields({'id': 'has space'}),
      slack.withFields({'pinned': <String, Object?>{}}),
      slack.withFields({'origin': 'https://slack.com'}),
      {...oldSlack, 'channel': 'general'},
      {...oldSlack, 'timestamp': 'yesterday'},
      {...oldSlack, 'thread': '1700000000.000100'},
      {...oldSlack}..remove('timestamp'),
      teams.without({'id'}),
      teams.without({'addressPrefix'}),
      teams.withFields({'id': ''}),
      teams.withFields({'id': 42}),
      teams.withFields({'addressPrefix': 'https://x.example/'}),
      teams.withFields({'pinned': 'C0123ABC'}),
      slack.withFields({'case': 'under-web-address'}),
    ]) {
      expect(
        () => decodePostedMessage(json, 'posted'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            startsWith('posted'),
          ),
        ),
        reason: '$json',
      );
    }
  });

  test('a server-assigned id is any non-empty string with no whitespace', () {
    for (final s in ['1', '1:1aBcD2eFgH', 'f:abc-123_x/y=', 'wamid.HBg=']) {
      expect(ServerAssignedMessageId.parse(s)?.value, s, reason: s);
    }
    for (final s in ['', ' ', 'a b', 'ab\n', '\tab', 'a\u{a0}b']) {
      expect(ServerAssignedMessageId.parse(s), isNull, reason: s);
    }
  });
}
