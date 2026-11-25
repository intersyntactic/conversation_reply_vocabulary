// Which addresses a reply's request may go to is decided by its endpoint:
// Teams' under the conversation's prefix, Slack's only at chat.postMessage.
import 'package:is_conversation_reply_vocabulary/is_conversation_reply_vocabulary.dart';
import 'package:is_web_address_vocabulary/is_web_address_vocabulary.dart'
    show AddressPrefix, Origin, PathPrefix, WebPath;
import 'package:test/test.dart';

final _slackOrigin = Origin.parse('https://slack.com')!;
final _teamsOrigin = Origin.parse('https://smba.trafficmanager.net')!;

final _slack = RepliesInSlackConversation(
  origin: _slackOrigin,
  channel: SlackChannelId.parse('C0123ABC')!,
  thread: SlackMessageTimestamp.parse('1700000000.000100'),
);

final _teams = RepliesUnderWebAddress(
  AddressPrefix.of(
    _teamsOrigin,
    PathPrefix.parse('/amer/v3/conversations/19:x/activities/')!,
  ),
);

WebPath _path(String s) => WebPath.parse(s)!;

void main() {
  test('a Slack endpoint admits only chat.postMessage on its origin', () {
    expect(
      _slack.admitsAddress(_slackOrigin, _path('/api/chat.postMessage')),
      isTrue,
    );
    for (final path in [
      '/api/chat.delete',
      '/api/chat.update',
      '/api/files.upload',
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
      reason: 'another origin than the endpoint vouched for',
    );
  });

  test('a Slack endpoint on another origin admits that origin only', () {
    final gov = Origin.parse('https://slack-gov.com')!;
    final endpoint = RepliesInSlackConversation(
      origin: gov,
      channel: SlackChannelId.parse('C0123ABC')!,
    );
    expect(endpoint.admitsAddress(gov, _path('/api/chat.postMessage')), isTrue);
    expect(
      endpoint.admitsAddress(_slackOrigin, _path('/api/chat.postMessage')),
      isFalse,
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

  test('redirects stay under /api/ for Slack and the prefix for Teams', () {
    expect(_slack.redirectsStayUnder, PathPrefix.parse('/api/'));
    expect(
      _slack.redirectsStayUnder.covers(
        RepliesInSlackConversation.postMessagePath,
      ),
      isTrue,
    );
    expect(_teams.redirectsStayUnder, _teams.prefix.pathPrefix);
  });
}
