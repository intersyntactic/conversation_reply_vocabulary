// Which requests a reply may be sent as is decided by its endpoint: under
// the conversation's prefix, or at one exact path with a JSON body carrying
// the pinned fields.
import 'package:is_conversation_vocabulary/is_conversation_vocabulary.dart';
import 'package:is_web_address_vocabulary/is_web_address_vocabulary.dart'
    show AddressPrefix, Origin, PathPrefix, WebPath;
import 'package:test/test.dart';

final _slackOrigin = Origin.parse('https://slack.com')!;
final _teamsOrigin = Origin.parse('https://smba.trafficmanager.net')!;

final _slack = RepliesWithPinnedBodyFields.at(
  origin: _slackOrigin,
  path: WebPath.parse('/api/chat.postMessage')!,
  pinned: PinnedBodyFields.of({
    'channel': 'C0123ABC',
    'thread_ts': '1700000000.000100',
  })!,
)!;

final _whatsApp = RepliesWithPinnedBodyFields.at(
  origin: Origin.parse('https://graph.facebook.com')!,
  path: WebPath.parse('/v27.0/106540352242922/messages')!,
  pinned: PinnedBodyFields.of({
    'messaging_product': 'whatsapp',
    'recipient_type': 'individual',
    'to': '61400000000',
  })!,
)!;

final _teams = RepliesUnderWebAddress(
  AddressPrefix.of(
    _teamsOrigin,
    PathPrefix.parse('/amer/v3/conversations/19:x/activities/')!,
  ),
);

WebPath _path(String s) => WebPath.parse(s)!;

const _json = 'application/json';

void main() {
  test('a pinned endpoint admits only its exact path on its origin', () {
    expect(
      _slack.admitsAddress(_slackOrigin, _path('/api/chat.postMessage')),
      isTrue,
    );
    for (final path in [
      '/api/chat.delete',
      '/api/chat.update',
      '/api/chat.postMessage/x',
      '/api/chat.postMessageX',
      '/api/chat.postMessage?channel=C9',
      '/api/',
      '',
    ]) {
      expect(
        _slack.admitsAddress(_slackOrigin, _path(path)),
        isFalse,
        reason: path,
      );
    }
    expect(
      _slack.admitsAddress(
        Origin.parse('https://slack-gov.com')!,
        _path('/api/chat.postMessage'),
      ),
      isFalse,
    );
  });

  test('a pinned endpoint is never at a path with a query, or at none', () {
    final pinned = PinnedBodyFields.of({'channel': 'C0123ABC'})!;
    for (final path in ['/api/chat.postMessage?channel=C9', '']) {
      expect(
        RepliesWithPinnedBodyFields.at(
          origin: _slackOrigin,
          path: _path(path),
          pinned: pinned,
        ),
        isNull,
        reason: path,
      );
    }
  });

  test('a body passes only as JSON carrying every pinned field exactly', () {
    const reply =
        '{"channel":"C0123ABC","thread_ts":"1700000000.000100","text":"hi"}';
    expect(_slack.admitsBody(contentType: _json, body: reply), isTrue);
    expect(
      _slack.admitsBody(
        contentType: 'application/json; charset=utf-8',
        body: reply,
      ),
      isTrue,
    );
    expect(
      _slack.admitsBody(contentType: 'Application/JSON', body: reply),
      isTrue,
    );
    for (final body in [
      '{"channel":"C0999XYZ","thread_ts":"1700000000.000100","text":"hi"}',
      '{"channel":"C0123ABC","text":"hi"}',
      '{"channel":"C0123ABC","thread_ts":"1700000000.000200"}',
      '{"channel":["C0123ABC"],"thread_ts":"1700000000.000100"}',
      '{"channel":"C0999XYZ","channel":"C0123ABC",'
          '"thread_ts":"1700000000.000100"}',
      '[{"channel":"C0123ABC","thread_ts":"1700000000.000100"}]',
      'channel=C0123ABC&thread_ts=1700000000.000100',
      '',
    ]) {
      expect(
        _slack.admitsBody(contentType: _json, body: body),
        isFalse,
        reason: body,
      );
    }
    for (final contentType in [
      'application/x-www-form-urlencoded',
      'text/plain',
      'application/json; charset=latin1',
      'application/json; charset=utf-8; boundary=x',
      '',
    ]) {
      expect(
        _slack.admitsBody(contentType: contentType, body: reply),
        isFalse,
        reason: contentType,
      );
    }
  });

  test('a WhatsApp reply is the same case with its own fields', () {
    expect(
      _whatsApp.admitsBody(
        contentType: _json,
        body:
            '{"messaging_product":"whatsapp","recipient_type":"individual",'
            '"to":"61400000000","type":"text","text":{"body":"hi"}}',
      ),
      isTrue,
    );
    expect(
      _whatsApp.admitsBody(
        contentType: _json,
        body:
            '{"messaging_product":"whatsapp","recipient_type":"individual",'
            '"to":"61400000001","type":"text","text":{"body":"hi"}}',
      ),
      isFalse,
    );
    expect(
      _whatsApp.redirectsStayUnder,
      PathPrefix.parse('/v27.0/106540352242922/'),
    );
  });

  test('a web address endpoint admits what its prefix covers', () {
    const under = '/amer/v3/conversations/19:x/activities/';
    expect(_teams.admitsAddress(_teamsOrigin, _path('${under}abc')), isTrue);
    for (final path in [
      '/amer/v3/conversations/19:x/activities',
      '/amer/v3/conversations/19:y/activities/abc',
      '/',
    ]) {
      expect(
        _teams.admitsAddress(_teamsOrigin, _path(path)),
        isFalse,
        reason: path,
      );
    }
    expect(_teams.admitsAddress(_slackOrigin, _path('${under}abc')), isFalse);
  });

  test('every endpoint names the site its replies are sent to', () {
    expect(<ReplyEndpoint>[_slack, _teams].map((e) => e.origin), [
      _slackOrigin,
      _teamsOrigin,
    ]);
  });

  test('redirects stay under the path\'s parent, or the prefix', () {
    expect(_slack.redirectsStayUnder, PathPrefix.parse('/api/'));
    expect(_slack.redirectsStayUnder.covers(_slack.path), isTrue);
    expect(_teams.redirectsStayUnder, _teams.prefix.pathPrefix);
  });

  test('a field pinned absent must not be in the body at all', () {
    final topLevel = RepliesWithPinnedBodyFields.at(
      origin: _slackOrigin,
      path: _path('/api/chat.postMessage'),
      pinned: PinnedBodyFields.of(
        {'channel': 'C0123ABC'},
        mustBeAbsent: {'thread_ts', 'username'},
      )!,
    )!;
    expect(
      topLevel.admitsBody(
        contentType: _json,
        body: '{"channel":"C0123ABC","text":"hi"}',
      ),
      isTrue,
    );
    for (final body in [
      '{"channel":"C0123ABC","thread_ts":"1700000000.000100","text":"hi"}',
      '{"channel":"C0123ABC","thread_ts":null,"text":"hi"}',
      '{"channel":"C0123ABC","username":"Nick","text":"hi"}',
    ]) {
      expect(
        topLevel.admitsBody(contentType: _json, body: body),
        isFalse,
        reason: body,
      );
    }
  });

  test('pinned fields need at least one named field, none both ways', () {
    expect(PinnedBodyFields.of({}), isNull);
    expect(PinnedBodyFields.of({'': 'x'}), isNull);
    expect(PinnedBodyFields.of({'a': '1'}, mustBeAbsent: {''}), isNull);
    expect(PinnedBodyFields.of({'a': '1'}, mustBeAbsent: {'a'}), isNull);
    expect(
      PinnedBodyFields.of({'a': '1', 'b': '2'}),
      PinnedBodyFields.of({'b': '2', 'a': '1'}),
    );
  });
}
