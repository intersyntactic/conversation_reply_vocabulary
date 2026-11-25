// What a reply posted is read back exactly as written, and strictly: the
// logbook records it as what was posted, so nothing about it may be
// guessed.
import 'dart:convert';

import 'package:is_conversation_reply_vocabulary/is_conversation_reply_vocabulary.dart';
import 'package:is_web_address_vocabulary/is_web_address_vocabulary.dart'
    show AddressPrefix, Origin, PathPrefix;
import 'package:test/test.dart';

final _teamsEndpoint = RepliesUnderWebAddress(
  AddressPrefix.of(
    Origin.parse('https://smba.trafficmanager.net')!,
    PathPrefix.parse('/amer/v3/conversations/19:x/activities/')!,
  ),
);

final _slackEndpoint = RepliesInSlackConversation(
  origin: Origin.parse('https://slack.com')!,
  channel: SlackChannelId.parse('C0123ABC')!,
  thread: SlackMessageTimestamp.parse('1700000000.000100'),
);

final _teams = PostedUnderWebAddress.answering(
  _teamsEndpoint,
  ServerAssignedMessageId.parse('1:1aBcD2eFgH')!,
);

final _slack = PostedInSlackConversation.answering(
  _slackEndpoint,
  SlackMessageTimestamp.parse('1700000000.000200')!,
);

void main() {
  test(
    'a posted message is in the conversation of the endpoint it answers',
    () {
      expect(_teams.prefix, _teamsEndpoint.prefix);
      expect(_slack.channel, _slackEndpoint.channel);
    },
  );

  test('each case reads back as itself', () {
    for (final message in <PostedMessage>[_teams, _slack]) {
      final json = encodePostedMessage(message);
      expect(decodePostedMessage(json, 'posted'), message);
    }
  });

  test('each case reads back from its JSON text as itself', () {
    for (final message in <PostedMessage>[_teams, _slack]) {
      final text = jsonEncode(encodePostedMessage(message));
      expect(decodePostedMessage(jsonDecode(text), 'posted'), message);
    }
  });

  test('each case is written as its fields, named as its endpoint is', () {
    expect(
      jsonEncode(encodePostedMessage(_slack)),
      '{"case":"in-slack-conversation","channel":"C0123ABC",'
      '"timestamp":"1700000000.000200"}',
    );
    expect(
      jsonEncode(encodePostedMessage(_teams)),
      '{"case":"under-web-address","addressPrefix":'
      '{"origin":"https://smba.trafficmanager.net",'
      '"pathPrefix":"/amer/v3/conversations/19:x/activities/"},'
      '"id":"1:1aBcD2eFgH"}',
    );
  });

  test('anything else is refused, naming the field', () {
    final slack = encodePostedMessage(_slack);
    final teams = encodePostedMessage(_teams);
    for (final json in <Object?>[
      null,
      'C0123ABC',
      [slack],
      slack.withFields({'case': 'somewhere-else'}),
      slack.withFields({'case': null}),
      slack.without({'case'}),
      slack.without({'channel'}),
      slack.without({'timestamp'}),
      slack.withFields({'channel': 'general'}),
      slack.withFields({'channel': 7}),
      slack.withFields({'timestamp': 'yesterday'}),
      slack.withFields({'timestamp': 1700000000.0002}),
      slack.withFields({'timestamp': null}),
      slack.withFields({'thread': '1700000000.000100'}),
      slack.withFields({'origin': 'https://slack.com'}),
      teams.without({'id'}),
      teams.without({'addressPrefix'}),
      teams.withFields({'id': ''}),
      teams.withFields({'id': 'has space'}),
      teams.withFields({'id': 42}),
      teams.withFields({'addressPrefix': 'https://x.example/'}),
      teams.withFields({'channel': 'C0123ABC'}),
      // A Slack message's fields under the web address case.
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
    for (final s in ['1', '1:1aBcD2eFgH', 'f:abc-123_x/y=']) {
      expect(ServerAssignedMessageId.parse(s)?.value, s, reason: s);
    }
    for (final s in ['', ' ', 'a b', 'ab\n', '\tab', 'a\u{a0}b']) {
      expect(ServerAssignedMessageId.parse(s), isNull, reason: s);
    }
  });
}
