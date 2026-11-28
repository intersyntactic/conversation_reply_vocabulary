/// Where replies to an event go, as its module vouches for it, and its form
/// in the logbook. One case for each way an external system takes replies,
/// since a reply's target is a web address for some and a field of the
/// request's body for others.
library;

import 'package:checked_json/checked_json.dart' show JsonObject;
import 'package:is_web_address_vocabulary/is_web_address_vocabulary.dart'
    show
        AddressPrefix,
        Origin,
        PathPrefix,
        WebPath,
        decodeAddressPrefix,
        decodeOrigin,
        encodeAddressPrefix,
        encodeOrigin;

import 'conversation_kind.dart';
import 'strict_object_reader.dart';
import 'whatsapp_chat.dart';

export 'whatsapp_chat.dart'
    show
        GraphApiVersion,
        WhatsAppBusinessPhoneNumberId,
        WhatsAppChat,
        WhatsAppGroupChat,
        WhatsAppGroupId,
        WhatsAppIndividualChat,
        WhatsAppUserPhoneNumber;

/// Where replies to an event go: [RepliesUnderWebAddress],
/// [RepliesInSlackConversation] or [RepliesInWhatsAppChat].
sealed class ReplyEndpoint {
  const ReplyEndpoint();

  /// Whether a request to [path] on [to] is to an address this endpoint's
  /// replies are sent to. It checks the address only, never the
  /// conversation: for a Slack endpoint the address is the same for every
  /// conversation, so this never confines a reply to its conversation. The
  /// channel and thread come from the endpoint itself, in the request it
  /// draws.
  bool admitsAddress(Origin to, WebPath path);

  /// The path prefix a redirect of an admitted request must stay under.
  /// It bounds only where the server may redirect a request
  /// [admitsAddress] already let through, and is never itself what a reply
  /// may reach.
  PathPrefix get redirectsStayUnder;
}

/// Replies go under [prefix], a web address that names the conversation, as
/// Teams' Bot Connector takes them: a reply's request is confined to its
/// conversation by where it is sent.
final class RepliesUnderWebAddress extends ReplyEndpoint {
  const RepliesUnderWebAddress(this.prefix);

  final AddressPrefix prefix;

  @override
  bool operator ==(Object other) =>
      other is RepliesUnderWebAddress && other.prefix == prefix;

  @override
  int get hashCode => prefix.hashCode;

  /// A request under [prefix].
  @override
  bool admitsAddress(Origin to, WebPath path) => prefix.covers(to, path);

  @override
  PathPrefix get redirectsStayUnder => prefix.pathPrefix;

  @override
  String toString() => 'RepliesUnderWebAddress($prefix)';
}

/// Replies go to Slack's [channel], in [thread], through [origin]. Slack
/// takes every reply at one web address and names its conversation in the
/// request's body, so a reply is confined to its conversation by [channel]
/// and [thread], never by where it is sent; [origin] is what the
/// trajectory's rules say it may reply through at all.
final class RepliesInSlackConversation extends ReplyEndpoint {
  const RepliesInSlackConversation({
    required this.origin,
    required this.channel,
    this.thread,
  });

  /// The site the reply is sent to, the same for every Slack reply.
  final Origin origin;

  final SlackChannelId channel;

  /// The thread the reply goes in, by its root message. A post at a
  /// channel's or a group message's top level is a thread's root, so a
  /// reply to it names that post's own timestamp. Null only for a direct
  /// message between one person and the bot, which Slack doesn't thread.
  final SlackMessageTimestamp? thread;

  @override
  bool operator ==(Object other) =>
      other is RepliesInSlackConversation &&
      other.origin == origin &&
      other.channel == channel &&
      other.thread == thread;

  @override
  int get hashCode => Object.hash(origin, channel, thread);

  /// The one path a Slack reply is sent to: posting a message. Every other
  /// method under the bot's token, such as `chat.delete`, is refused.
  static final postMessagePath = WebPath.parse('/api/chat.postMessage')!;

  /// A request to exactly [postMessagePath] on [origin], with no query.
  @override
  bool admitsAddress(Origin to, WebPath path) =>
      to == origin && path == postMessagePath;

  /// `/api/`, the narrowest prefix covering [postMessagePath]. A redirect
  /// from Slack could in principle move a POST to another method under
  /// `/api/`; that is the server's choice, never the reply's.
  @override
  PathPrefix get redirectsStayUnder => _api;

  static final _api = PathPrefix.parse('/api/')!;

  @override
  String toString() => 'RepliesInSlackConversation($origin, $channel, $thread)';
}

/// Replies go to WhatsApp's [chat], sent from the business number that
/// [phoneNumberId] names, through [origin], as the WhatsApp Cloud API takes
/// them. Like Slack, it takes every reply from one number at one web
/// address and names the chat in the request's body, so a reply is
/// confined to its chat by [chat], never by where it is sent.
final class RepliesInWhatsAppChat extends ReplyEndpoint {
  const RepliesInWhatsAppChat({
    required this.origin,
    required this.graphApiVersion,
    required this.phoneNumberId,
    required this.chat,
  });

  /// The site the reply is sent to, such as `https://graph.facebook.com`.
  final Origin origin;

  /// The Graph API version the reply's path names, as the module vouches
  /// for it.
  final GraphApiVersion graphApiVersion;

  final WhatsAppBusinessPhoneNumberId phoneNumberId;

  final WhatsAppChat chat;

  @override
  bool operator ==(Object other) =>
      other is RepliesInWhatsAppChat &&
      other.origin == origin &&
      other.graphApiVersion == graphApiVersion &&
      other.phoneNumberId == phoneNumberId &&
      other.chat == chat;

  @override
  int get hashCode => Object.hash(origin, graphApiVersion, phoneNumberId, chat);

  /// The one path a reply is sent to, `/<version>/<phoneNumberId>/messages`.
  /// Its segments are a version and digits, so it always parses.
  WebPath get messagesPath =>
      WebPath.parse('/$graphApiVersion/$phoneNumberId/messages')!;

  /// A request to exactly [messagesPath] on [origin], with no query. The
  /// number's other paths, such as its settings, are refused.
  @override
  bool admitsAddress(Origin to, WebPath path) =>
      to == origin && path == messagesPath;

  /// `/<version>/<phoneNumberId>/`, the narrowest prefix covering
  /// [messagesPath].
  @override
  PathPrefix get redirectsStayUnder =>
      PathPrefix.parse('/$graphApiVersion/$phoneNumberId/')!;

  @override
  String toString() =>
      'RepliesInWhatsAppChat($origin, $graphApiVersion, $phoneNumberId, '
      '$chat)';
}

/// A Slack conversation's id: a public or private channel (`C…`), a direct
/// message (`D…`) or a group message (`G…`).
final class SlackChannelId {
  const SlackChannelId._(this.value);

  /// The id, as Slack writes it.
  final String value;

  /// [s] as a channel id; null unless it is one.
  static SlackChannelId? parse(String s) =>
      _id.hasMatch(s) ? SlackChannelId._(s) : null;

  static final _id = RegExp(r'^[CDG][A-Z0-9]+$');

  @override
  bool operator ==(Object other) =>
      other is SlackChannelId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// The timestamp (`ts`) Slack names a message by, such as
/// `1700000000.000100`. A thread is named by its root message's timestamp.
final class SlackMessageTimestamp {
  const SlackMessageTimestamp._(this.value);

  /// The timestamp, as Slack writes it.
  final String value;

  /// [s] as a message timestamp; null unless it is one.
  static SlackMessageTimestamp? parse(String s) =>
      _ts.hasMatch(s) ? SlackMessageTimestamp._(s) : null;

  static final _ts = RegExp(r'^\d+\.\d+$');

  @override
  bool operator ==(Object other) =>
      other is SlackMessageTimestamp && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// [endpoint] as JSON:
///
///     {"case": "under-web-address", "addressPrefix": <address prefix>}
///     {"case": "in-slack-conversation", "origin": <origin>,
///      "channel": <id>, "thread": <ts>?}
///     {"case": "in-whatsapp-chat", "origin": <origin>,
///      "graphApiVersion": <version>, "phoneNumberId": <id>,
///      "chat": {"kind": "individual" | "group", "id": <id>}}
///
/// `<address prefix>` and `<origin>` are as is_web_address_vocabulary's
/// `encodeAddressPrefix` and `encodeOrigin` write them.
JsonObject encodeReplyEndpoint(
  ReplyEndpoint endpoint,
) => JsonObject.of(switch (endpoint) {
  RepliesUnderWebAddress(:final prefix) => {
    'case': ConversationKind.underWebAddress.wire,
    'addressPrefix': encodeAddressPrefix(prefix),
  },
  RepliesInSlackConversation(:final origin, :final channel, :final thread) => {
    'case': ConversationKind.inSlackConversation.wire,
    'origin': encodeOrigin(origin),
    'channel': channel.value,
    'thread': ?thread?.value,
  },
  RepliesInWhatsAppChat(
    :final origin,
    :final graphApiVersion,
    :final phoneNumberId,
    :final chat,
  ) =>
    {
      'case': ConversationKind.inWhatsAppChat.wire,
      'origin': encodeOrigin(origin),
      'graphApiVersion': graphApiVersion.value,
      'phoneNumberId': phoneNumberId.value,
      'chat': encodeWhatsAppChat(chat),
    },
});

/// [json] read back as the endpoint [encodeReplyEndpoint] wrote. A
/// [FormatException] naming [field] for anything it doesn't write: an
/// unknown case, a field missing, extra or malformed.
ReplyEndpoint decodeReplyEndpoint(Object? json, String field) {
  final object = StrictObjectReader.of(json, field);
  switch (object.kind('a reply endpoint')) {
    case ConversationKind.underWebAddress:
      object.allowOnly(const {'case', 'addressPrefix'});
      return RepliesUnderWebAddress(
        decodeAddressPrefix(
          object.raw('addressPrefix'),
          object.nested('addressPrefix'),
        ),
      );
    case ConversationKind.inSlackConversation:
      object.allowOnly(const {'case', 'origin', 'channel', 'thread'});
      return RepliesInSlackConversation(
        origin: decodeOrigin(object.raw('origin'), object.nested('origin')),
        channel: object.parsed(
          'channel',
          SlackChannelId.parse,
          'a Slack channel id',
        ),
        thread: object.parsedIfPresent(
          'thread',
          SlackMessageTimestamp.parse,
          'a Slack thread timestamp',
        ),
      );
    case ConversationKind.inWhatsAppChat:
      object.allowOnly(const {
        'case',
        'origin',
        'graphApiVersion',
        'phoneNumberId',
        'chat',
      });
      return RepliesInWhatsAppChat(
        origin: decodeOrigin(object.raw('origin'), object.nested('origin')),
        graphApiVersion: object.parsed(
          'graphApiVersion',
          GraphApiVersion.parse,
          'a Graph API version',
        ),
        phoneNumberId: object.parsed(
          'phoneNumberId',
          WhatsAppBusinessPhoneNumberId.parse,
          'a WhatsApp phone number id',
        ),
        chat: decodeWhatsAppChat(object.raw('chat'), object.nested('chat')),
      );
  }
}
