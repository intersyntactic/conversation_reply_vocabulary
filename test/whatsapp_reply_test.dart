// A WhatsApp reply's endpoint: which addresses it admits, and its JSON and
// its posted message's, read back exactly and strictly.
import 'dart:convert';

import 'package:is_conversation_vocabulary/is_conversation_vocabulary.dart';
import 'package:is_web_address_vocabulary/is_web_address_vocabulary.dart'
    show Origin, PathPrefix, WebPath;
import 'package:test/test.dart';

final _graph = Origin.parse('https://graph.facebook.com')!;

final _person = WhatsAppIndividualChat(
  WhatsAppUserPhoneNumber.parse('61400000000')!,
);

final _group = WhatsAppGroupChat(
  WhatsAppGroupId.parse(
    'HBgLMTY1MDM4Nzk0MzkVAgASGBQzQTRBNjU5OUFFRTAzODEwMTQ0RgA',
  )!,
);

RepliesInWhatsAppChat _endpoint(WhatsAppChat chat) => RepliesInWhatsAppChat(
  origin: _graph,
  graphApiVersion: GraphApiVersion.parse('v27.0')!,
  phoneNumberId: WhatsAppBusinessPhoneNumberId.parse('106540352242922')!,
  chat: chat,
);

WebPath _path(String s) => WebPath.parse(s)!;

void main() {
  test('admits only its version and number\'s messages path on origin', () {
    final endpoint = _endpoint(_person);
    expect(
      endpoint.admitsAddress(_graph, _path('/v27.0/106540352242922/messages')),
      isTrue,
    );
    for (final path in [
      '/v26.0/106540352242922/messages',
      '/v27.0/999999999999999/messages',
      '/v27.0/106540352242922/messages?to=61400000001',
      '/v27.0/106540352242922/messages/x',
      '/v27.0/106540352242922/',
      '/v27.0/106540352242922',
      '/v27.0/106540352242922/register',
      '/',
      '',
    ]) {
      expect(
        endpoint.admitsAddress(_graph, _path(path)),
        isFalse,
        reason: path,
      );
    }
    expect(
      endpoint.admitsAddress(
        Origin.parse('https://graph.example')!,
        _path('/v27.0/106540352242922/messages'),
      ),
      isFalse,
    );
  });

  test('redirects stay under the version and number', () {
    final endpoint = _endpoint(_group);
    expect(
      endpoint.redirectsStayUnder,
      PathPrefix.parse('/v27.0/106540352242922/'),
    );
    expect(endpoint.redirectsStayUnder.covers(endpoint.messagesPath), isTrue);
  });

  test('each chat reads back as itself, written as the wire says', () {
    for (final endpoint in [_endpoint(_person), _endpoint(_group)]) {
      final text = jsonEncode(encodeReplyEndpoint(endpoint));
      expect(decodeReplyEndpoint(jsonDecode(text), 'replyEndpoint'), endpoint);
    }
    expect(
      jsonEncode(encodeReplyEndpoint(_endpoint(_person))),
      '{"case":"in-whatsapp-chat","origin":"https://graph.facebook.com",'
      '"graphApiVersion":"v27.0","phoneNumberId":"106540352242922",'
      '"chat":{"kind":"individual","id":"61400000000"}}',
    );
  });

  test('anything else is refused, naming the field', () {
    final json = encodeReplyEndpoint(_endpoint(_person));
    final chat = {'kind': 'individual', 'id': '61400000000'};
    for (final bad in <Object?>[
      json.without({'graphApiVersion'}),
      json.without({'phoneNumberId'}),
      json.without({'chat'}),
      json.without({'origin'}),
      json.withFields({'graphApiVersion': '27.0'}),
      json.withFields({'graphApiVersion': 'v27'}),
      json.withFields({'graphApiVersion': 'v27.0/..'}),
      json.withFields({'phoneNumberId': '1234'}),
      json.withFields({'phoneNumberId': '10654035224292a'}),
      json.withFields({'channel': 'C0123ABC'}),
      json.withFields({'chat': '61400000000'}),
      json.withFields({
        'chat': {...chat, 'kind': 'broadcast'},
      }),
      json.withFields({
        'chat': {...chat, 'id': '+61400000000'},
      }),
      json.withFields({
        'chat': {...chat, 'extra': 1},
      }),
      json.withFields({
        'chat': {'kind': 'group', 'id': 'has space'},
      }),
      json.withFields({
        'chat': {'kind': 'individual'},
      }),
    ]) {
      expect(
        () => decodeReplyEndpoint(bad, 'replyEndpoint'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            startsWith('replyEndpoint'),
          ),
        ),
        reason: '$bad',
      );
    }
  });

  test('ids parse only in their documented form', () {
    for (final s in ['', '0400000000', '61400', '6140000000000000', '+614']) {
      expect(WhatsAppUserPhoneNumber.parse(s), isNull, reason: s);
    }
    for (final s in ['', 'a b', 'x' * 257, 'ab#c']) {
      expect(WhatsAppGroupId.parse(s), isNull, reason: s);
    }
    for (final s in ['', '1234', '1' * 31, '12345 ']) {
      expect(WhatsAppBusinessPhoneNumberId.parse(s), isNull, reason: s);
    }
    for (final s in ['', 'v27', '27.0', 'v027.0', 'V27.0', 'v27.0.1']) {
      expect(GraphApiVersion.parse(s), isNull, reason: s);
    }
  });

  test('a posted message is in its endpoint\'s chat and reads back', () {
    final endpoint = _endpoint(_group);
    final posted = PostedInWhatsAppChat.answering(
      endpoint,
      ServerAssignedMessageId.parse('wamid.HBgLMTY1MDM4Nzk0MzkVAgARGBI=')!,
    );
    expect(posted.chat, endpoint.chat);
    final text = jsonEncode(encodePostedMessage(posted));
    expect(decodePostedMessage(jsonDecode(text), 'posted'), posted);
    final json = encodePostedMessage(posted);
    for (final bad in [
      json.without({'id'}),
      json.without({'chat'}),
      json.withFields({'phoneNumberId': '106540352242922'}),
      json.withFields({'id': ''}),
    ]) {
      expect(
        () => decodePostedMessage(bad, 'posted'),
        throwsA(isA<FormatException>()),
        reason: '$bad',
      );
    }
  });
}
