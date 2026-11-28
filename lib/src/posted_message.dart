/// The id of a message a reply posted, so the logbook records exactly what
/// was posted, and its form there. One case for each case of
/// `ReplyEndpoint`: a reply to an endpoint of one kind posts a message
/// named the matching way.
library;

import 'package:checked_json/checked_json.dart' show JsonObject;
import 'package:is_web_address_vocabulary/is_web_address_vocabulary.dart'
    show AddressPrefix, decodeAddressPrefix, encodeAddressPrefix;

import 'reply_endpoint.dart';
import 'reply_endpoint_case.dart';
import 'strict_object_reader.dart';

/// A message a reply posted: [PostedUnderWebAddress] or
/// [PostedWithPinnedBodyFields].
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

/// A message posted in the conversation [pinned] names, which the service
/// named [id], such as a Slack message's `ts` or a WhatsApp message's
/// `wamid.…`. The module that sent it reads [id] back into its own type.
/// Made only by [answering] or [decodePostedMessage], so its conversation
/// is the endpoint's.
final class PostedWithPinnedBodyFields extends PostedMessage {
  const PostedWithPinnedBodyFields._(this.pinned, this.id);

  /// The message a reply to [to] posted, which the service named [id].
  PostedWithPinnedBodyFields.answering(
    RepliesWithPinnedBodyFields to,
    ServerAssignedMessageId id,
  ) : this._(to.pinned, id);

  final PinnedBodyFields pinned;

  final ServerAssignedMessageId id;

  @override
  bool operator ==(Object other) =>
      other is PostedWithPinnedBodyFields &&
      other.pinned == pinned &&
      other.id == id;

  @override
  int get hashCode => Object.hash(pinned, id);

  @override
  String toString() => 'PostedWithPinnedBodyFields($pinned, $id)';
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
///     {"case": "with-pinned-body-fields", "pinned": {<name>: <string>},
///      "id": <id>}
///
/// Each case is named as the `ReplyEndpoint` case it answers is.
/// `<address prefix>` is as is_web_address_vocabulary's
/// `encodeAddressPrefix` writes it.
JsonObject encodePostedMessage(PostedMessage message) =>
    JsonObject.of(switch (message) {
      PostedUnderWebAddress(:final prefix, :final id) => {
        'case': ReplyEndpointCase.underWebAddress.wire,
        'addressPrefix': encodeAddressPrefix(prefix),
        'id': id.value,
      },
      PostedWithPinnedBodyFields(:final pinned, :final id) => {
        'case': ReplyEndpointCase.withPinnedBodyFields.wire,
        'pinned': encodePinnedBodyFields(pinned),
        'id': id.value,
      },
    });

/// [json] read back as the message [encodePostedMessage] wrote. A
/// [FormatException] naming [field] for anything it doesn't write: an
/// unknown case, a field missing, extra or malformed.
///
/// A logbook written before 0.2.0 holds Slack's posted messages as
/// `{"case": "in-slack-conversation", "channel", "timestamp"}`. Each reads
/// back as a [PostedWithPinnedBodyFields] pinning `channel`, whose id is
/// the timestamp.
PostedMessage decodePostedMessage(Object? json, String field) {
  final object = StrictObjectReader.of(json, field);
  switch (object.kind('a posted message')) {
    case ReplyEndpointCase.underWebAddress:
      object.allowOnly(const {'case', 'addressPrefix', 'id'});
      return PostedUnderWebAddress._(
        decodeAddressPrefix(
          object.raw('addressPrefix'),
          object.nested('addressPrefix'),
        ),
        object.parsed('id', ServerAssignedMessageId.parse, 'a message id'),
      );
    case ReplyEndpointCase.withPinnedBodyFields:
      object.allowOnly(const {'case', 'pinned', 'id'});
      return PostedWithPinnedBodyFields._(
        decodePinnedBodyFields(object.raw('pinned'), object.nested('pinned')),
        object.parsed('id', ServerAssignedMessageId.parse, 'a message id'),
      );
    case ReplyEndpointCase.slackConversationAsFirstWritten:
      object.allowOnly(const {'case', 'channel', 'timestamp'});
      final channel = object.parsed(
        'channel',
        slackChannelIdAsFirstWritten,
        'a Slack channel id',
      );
      return PostedWithPinnedBodyFields._(
        PinnedBodyFields.of({'channel': channel})!,
        object.parsed(
          'timestamp',
          (s) => switch (slackTimestampAsFirstWritten(s)) {
            final ts? => ServerAssignedMessageId.parse(ts),
            null => null,
          },
          'a Slack message timestamp',
        ),
      );
  }
}
