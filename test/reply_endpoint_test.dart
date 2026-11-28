// Where replies go is read back exactly as written, and strictly: the
// airlock grants a trajectory's replies to it, so nothing about it may be
// guessed. A logbook from before 0.2.0 still reads.
import 'dart:convert';

import 'package:checked_json/checked_json.dart';
import 'package:is_conversation_vocabulary/is_conversation_vocabulary.dart';
import 'package:is_web_address_vocabulary/is_web_address_vocabulary.dart'
    show AddressPrefix, Origin, PathPrefix, WebPath;
import 'package:test/test.dart';

final _slack = Origin.parse('https://slack.com')!;

final _teams = RepliesUnderWebAddress(
  AddressPrefix.of(
    Origin.parse('https://smba.trafficmanager.net')!,
    PathPrefix.parse('/amer/v3/conversations/19:x/activities/')!,
  ),
);

RepliesWithPinnedBodyFields _slackThread(
  Map<String, String> pinned, {
  Set<String> absent = const {},
}) => RepliesWithPinnedBodyFields.at(
  origin: _slack,
  path: WebPath.parse('/api/chat.postMessage')!,
  pinned: PinnedBodyFields.of(pinned, mustBeAbsent: absent)!,
)!;

final _thread = _slackThread({
  'channel': 'C0123ABC',
  'thread_ts': '1700000000.000100',
});

void main() {
  test('each case reads back from its JSON text as itself', () {
    for (final endpoint in <ReplyEndpoint>[
      _teams,
      _thread,
      _slackThread({'channel': 'D0456DEF'}, absent: {'thread_ts'}),
      _slackThread(
        {'channel': 'C0123ABC'},
        absent: {'thread_ts', 'icon_url', 'username'},
      ),
    ]) {
      final text = jsonEncode(encodeReplyEndpoint(endpoint));
      expect(decodeReplyEndpoint(jsonDecode(text), 'replyEndpoint'), endpoint);
    }
  });

  test('each case is written as its fields', () {
    expect(
      jsonEncode(encodeReplyEndpoint(_thread)),
      '{"case":"with-pinned-body-fields","origin":"https://slack.com",'
      '"path":"/api/chat.postMessage",'
      '"pinned":{"mustEqual":{"channel":"C0123ABC",'
      '"thread_ts":"1700000000.000100"}}}',
    );
    expect(
      jsonEncode(
        encodeReplyEndpoint(
          _slackThread({'channel': 'C1'}, absent: {'username', 'thread_ts'}),
        ),
      ),
      contains(
        '"pinned":{"mustEqual":{"channel":"C1"},'
        '"mustBeAbsent":["thread_ts","username"]}',
      ),
    );
    expect(
      jsonEncode(encodeReplyEndpoint(_teams)),
      '{"case":"under-web-address","addressPrefix":'
      '{"origin":"https://smba.trafficmanager.net",'
      '"pathPrefix":"/amer/v3/conversations/19:x/activities/"}}',
    );
  });

  test('a Slack endpoint as a logbook before 0.2.0 wrote it reads as the '
      'pinned endpoint it meant', () {
    expect(
      decodeReplyEndpoint(
        jsonDecode(
          '{"case":"in-slack-conversation","origin":"https://slack.com",'
          '"channel":"C0123ABC","thread":"1700000000.000100"}',
        ),
        'replyEndpoint',
      ),
      _thread,
    );
    expect(
      decodeReplyEndpoint(
        jsonDecode(
          '{"case":"in-slack-conversation","origin":"https://slack.com",'
          '"channel":"D0456DEF"}',
        ),
        'replyEndpoint',
      ),
      _slackThread({'channel': 'D0456DEF'}, absent: {'thread_ts'}),
    );
  });

  test('anything else is refused, naming the field', () {
    final pinned = encodeReplyEndpoint(_thread);
    final oldSlack = JsonObject.of({
      'case': 'in-slack-conversation',
      'origin': 'https://slack.com',
      'channel': 'C0123ABC',
    });
    for (final json in <Object?>[
      'https://slack.com',
      pinned.withFields({'case': 'in-whatsapp-chat'}),
      pinned.without({'case'}),
      pinned.without({'origin'}),
      pinned.without({'path'}),
      pinned.without({'pinned'}),
      pinned.withFields({'path': '/api/chat.postMessage?channel=C9'}),
      pinned.withFields({'path': ''}),
      pinned.withFields({'path': 'api/chat.postMessage'}),
      pinned.withFields({'pinned': <String, Object?>{}}),
      for (final bad in <Object?>[
        {'mustEqual': <String, Object?>{}},
        {
          'mustEqual': {'channel': 7},
        },
        {
          'mustEqual': {'': 'x'},
        },
        {'channel': 'C0123ABC'},
        {
          'mustEqual': {'channel': 'C1'},
          'mustBeAbsent': <Object?>[],
        },
        {
          'mustEqual': {'channel': 'C1'},
          'mustBeAbsent': ['username', 'thread_ts'],
        },
        {
          'mustEqual': {'channel': 'C1'},
          'mustBeAbsent': ['a', 'a'],
        },
        {
          'mustEqual': {'channel': 'C1'},
          'mustBeAbsent': ['channel'],
        },
        {
          'mustEqual': {'channel': 'C1'},
          'mustBeAbsent': [7],
        },
        {
          'mustEqual': {'channel': 'C1'},
          'mustBeAbsent': null,
        },
        {
          'mustEqual': {'channel': 'C1'},
          'extra': 1,
        },
      ])
        pinned.withFields({'pinned': bad}),
      pinned.withFields({'pinned': 'C0123ABC'}),
      pinned.withFields({'extra': 1}),
      oldSlack.without({'channel'}),
      oldSlack.withFields({'channel': 'general'}),
      oldSlack.withFields({'thread': 'yesterday'}),
      oldSlack.withFields({'thread': null}),
      oldSlack.withFields({'extra': 1}),
      {'case': 'under-web-address'},
      {
        'case': 'under-web-address',
        'addressPrefix': {'origin': 'https://x.example', 'pathPrefix': '/'},
        'channel': 'C0123ABC',
      },
    ]) {
      expect(
        () => decodeReplyEndpoint(json, 'replyEndpoint'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            startsWith('replyEndpoint'),
          ),
        ),
        reason: '$json',
      );
    }
  });
}
