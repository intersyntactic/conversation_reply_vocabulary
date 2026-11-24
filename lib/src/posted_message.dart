/// The id of a message a reply posted, so the logbook records exactly what
/// was posted, and its form there. One case for each case of
/// `ReplyEndpoint`: a reply to an endpoint of one kind posts a message
/// named the matching way.
library;

import 'package:is_web_address_vocabulary/is_web_address_vocabulary.dart'
    show AddressPrefix, decodeAddressPrefix, encodeAddressPrefix;

import 'conversation_kind.dart';
import 'reply_endpoint.dart';

/// A message a reply posted: [PostedUnderWebAddress] or
/// [PostedInSlackConversation].
sealed class PostedMessage {
  const PostedMessage();
}

/// A message posted under [prefix], the conversation's web address, which
/// that web address's server named [id]. The posted message of a reply to
/// a `RepliesUnderWebAddress`.
final class PostedUnderWebAddress extends PostedMessage {
  const PostedUnderWebAddress({required this.prefix, required this.id});

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

/// A message posted in Slack's [channel] that Slack named [timestamp]. The
/// posted message of a reply to a `RepliesInSlackConversation`; a later
/// reply can go in the thread it names.
final class PostedInSlackConversation extends PostedMessage {
  const PostedInSlackConversation({
    required this.channel,
    required this.timestamp,
  });

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
///
/// Each case is named as the `ReplyEndpoint` case it answers is.
/// `<address prefix>` is as is_web_address_vocabulary's
/// `encodeAddressPrefix` writes it.
Map<String, Object?> encodePostedMessage(PostedMessage message) =>
    switch (message) {
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
    };

/// [json] read back as the message [encodePostedMessage] wrote. A
/// [FormatException] naming [field] for anything it doesn't write: an
/// unknown case, a field missing, extra or malformed.
PostedMessage decodePostedMessage(Object? json, String field) {
  if (json is! Map<String, Object?>) {
    throw FormatException('$field: not an object');
  }
  Never bad(String why) => throw FormatException('$field: $why');
  void only(Set<String> keys) {
    for (final key in json.keys) {
      if (!keys.contains(key)) bad('`$key` is not expected here');
    }
  }

  final kind = ConversationKind.parse(json['case']);
  if (kind == null) bad('`case` is not a posted message: ${json['case']}');
  switch (kind) {
    case ConversationKind.underWebAddress:
      only(const {'case', 'addressPrefix', 'id'});
      final prefix = decodeAddressPrefix(
        json['addressPrefix'],
        '$field.addressPrefix',
      );
      final id = switch (json['id']) {
        final String s => ServerAssignedMessageId.parse(s),
        _ => null,
      };
      if (id == null) bad('`id` is not a message id');
      return PostedUnderWebAddress(prefix: prefix, id: id);
    case ConversationKind.inSlackConversation:
      only(const {'case', 'channel', 'timestamp'});
      final channel = switch (json['channel']) {
        final String s => SlackChannelId.parse(s),
        _ => null,
      };
      if (channel == null) bad('`channel` is not a Slack channel id');
      final timestamp = switch (json['timestamp']) {
        final String s => SlackMessageTimestamp.parse(s),
        _ => null,
      };
      if (timestamp == null) {
        bad('`timestamp` is not a Slack message timestamp');
      }
      return PostedInSlackConversation(channel: channel, timestamp: timestamp);
  }
}
