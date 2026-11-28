/// The id of a message a reply posted, so the logbook records exactly what
/// was posted, and its form there. One case for each case of
/// `ReplyEndpoint`: a reply to an endpoint of one kind posts a message
/// named the matching way.
library;

import 'package:checked_json/checked_json.dart' show JsonObject;
import 'package:is_web_address_vocabulary/is_web_address_vocabulary.dart'
    show AddressPrefix, decodeAddressPrefix, encodeAddressPrefix;

import 'conversation_kind.dart';
import 'reply_endpoint.dart';
import 'strict_object_reader.dart';
import 'whatsapp_chat.dart';

/// A message a reply posted: [PostedUnderWebAddress],
/// [PostedInSlackConversation] or [PostedInWhatsAppChat].
sealed class PostedMessage {
  const PostedMessage();
}

/// A message posted under [prefix], the conversation's web address, which
/// that web address's server named [id]. Made only by [answering] or
/// [decodePostedMessage], so its conversation is the endpoint's.
final class PostedUnderWebAddress extends PostedMessage {
  const PostedUnderWebAddress._(this.prefix, this.id);

  /// The message a reply to [to] posted, which the server named [id].
  PostedUnderWebAddress.answering(
    RepliesUnderWebAddress to,
    ServerAssignedMessageId id,
  ) : this._(to.prefix, id);

  final AddressPrefix prefix;

  final ServerAssignedMessageId id;

  @override
  bool operator ==(Object other) =>
      other is PostedUnderWebAddress &&
      other.prefix == prefix &&
      other.id == id;

  @override
  int get hashCode => Object.hash(prefix, id);

  @override
  String toString() => 'PostedUnderWebAddress($prefix, $id)';
}

/// A message posted in Slack's [channel] that Slack named [timestamp]; a
/// later reply can go in the thread it names. Made only by [answering] or
/// [decodePostedMessage], so its channel is the endpoint's.
final class PostedInSlackConversation extends PostedMessage {
  const PostedInSlackConversation._(this.channel, this.timestamp);

  /// The message a reply to [to] posted, which Slack named [timestamp].
  PostedInSlackConversation.answering(
    RepliesInSlackConversation to,
    SlackMessageTimestamp timestamp,
  ) : this._(to.channel, timestamp);

  final SlackChannelId channel;

  final SlackMessageTimestamp timestamp;

  @override
  bool operator ==(Object other) =>
      other is PostedInSlackConversation &&
      other.channel == channel &&
      other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(channel, timestamp);

  @override
  String toString() => 'PostedInSlackConversation($channel, $timestamp)';
}

/// A message posted in WhatsApp's [chat] that WhatsApp named [id], the
/// `messages[0].id` (`wamid.…`) of its response. Made only by [answering]
/// or [decodePostedMessage], so its chat is the endpoint's.
final class PostedInWhatsAppChat extends PostedMessage {
  const PostedInWhatsAppChat._(this.chat, this.id);

  /// The message a reply to [to] posted, which WhatsApp named [id].
  PostedInWhatsAppChat.answering(
    RepliesInWhatsAppChat to,
    ServerAssignedMessageId id,
  ) : this._(to.chat, id);

  final WhatsAppChat chat;

  final ServerAssignedMessageId id;

  @override
  bool operator ==(Object other) =>
      other is PostedInWhatsAppChat && other.chat == chat && other.id == id;

  @override
  int get hashCode => Object.hash(chat, id);

  @override
  String toString() => 'PostedInWhatsAppChat($chat, $id)';
}

/// The id a server gave a message posted to it, such as the `id` in Teams'
/// Bot Connector's `{"id": "..."}` response. Its form is not documented as
/// a fixed pattern, so any non-empty string without whitespace is one.
final class ServerAssignedMessageId {
  const ServerAssignedMessageId._(this.value);

  /// The id, as the server wrote it.
  final String value;

  /// [s] as a message id; null unless it is non-empty with no whitespace.
  static ServerAssignedMessageId? parse(String s) =>
      _id.hasMatch(s) ? ServerAssignedMessageId._(s) : null;

  static final _id = RegExp(r'^\S+$');

  @override
  bool operator ==(Object other) =>
      other is ServerAssignedMessageId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// [message] as JSON:
///
///     {"case": "under-web-address", "addressPrefix": <address prefix>,
///      "id": <id>}
///     {"case": "in-slack-conversation", "channel": <id>,
///      "timestamp": <ts>}
///     {"case": "in-whatsapp-chat", "chat": <chat>, "id": <id>}
///
/// Each case is named as the `ReplyEndpoint` case it answers is.
/// `<address prefix>` is as is_web_address_vocabulary's
/// `encodeAddressPrefix` writes it.
JsonObject encodePostedMessage(PostedMessage message) =>
    JsonObject.of(switch (message) {
      PostedUnderWebAddress(:final prefix, :final id) => {
        'case': ConversationKind.underWebAddress.wire,
        'addressPrefix': encodeAddressPrefix(prefix),
        'id': id.value,
      },
      PostedInSlackConversation(:final channel, :final timestamp) => {
        'case': ConversationKind.inSlackConversation.wire,
        'channel': channel.value,
        'timestamp': timestamp.value,
      },
      PostedInWhatsAppChat(:final chat, :final id) => {
        'case': ConversationKind.inWhatsAppChat.wire,
        'chat': encodeWhatsAppChat(chat),
        'id': id.value,
      },
    });

/// [json] read back as the message [encodePostedMessage] wrote. A
/// [FormatException] naming [field] for anything it doesn't write: an
/// unknown case, a field missing, extra or malformed.
PostedMessage decodePostedMessage(Object? json, String field) {
  final object = StrictObjectReader.of(json, field);
  switch (object.kind('a posted message')) {
    case ConversationKind.underWebAddress:
      object.allowOnly(const {'case', 'addressPrefix', 'id'});
      return PostedUnderWebAddress._(
        decodeAddressPrefix(
          object.raw('addressPrefix'),
          object.nested('addressPrefix'),
        ),
        object.parsed('id', ServerAssignedMessageId.parse, 'a message id'),
      );
    case ConversationKind.inSlackConversation:
      object.allowOnly(const {'case', 'channel', 'timestamp'});
      return PostedInSlackConversation._(
        object.parsed('channel', SlackChannelId.parse, 'a Slack channel id'),
        object.parsed(
          'timestamp',
          SlackMessageTimestamp.parse,
          'a Slack message timestamp',
        ),
      );
    case ConversationKind.inWhatsAppChat:
      object.allowOnly(const {'case', 'chat', 'id'});
      return PostedInWhatsAppChat._(
        decodeWhatsAppChat(object.raw('chat'), object.nested('chat')),
        object.parsed('id', ServerAssignedMessageId.parse, 'a message id'),
      );
  }
}
