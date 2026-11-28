/// Where replies to an event go, as its module vouches for it, and its form
/// in the logbook. One case for each way a reply can be kept to its
/// conversation: by the web address it is sent to, or by fields its body
/// must carry. No case names a chat service; a module turns its service's
/// ids into one of these.
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

import 'reply_endpoint_case.dart';
import 'strict_object_reader.dart';

/// Where replies to an event go: [RepliesUnderWebAddress] or
/// [RepliesWithPinnedBodyFields].
sealed class ReplyEndpoint {
  const ReplyEndpoint();

  /// The site this endpoint's replies are sent to.
  Origin get origin;

  /// Whether a request to [path] on [to] is to an address this endpoint's
  /// replies are sent to. For [RepliesWithPinnedBodyFields] the address is
  /// the same for every conversation, so the address alone never confines
  /// a reply to its conversation; its body must pass
  /// [RepliesWithPinnedBodyFields.admitsBody] too.
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

  /// [prefix]'s origin.
  @override
  Origin get origin => prefix.origin;

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

/// Replies go to exactly [path] on [origin], as a JSON body carrying every
/// field of [pinned] with exactly its value, as services that take every
/// reply at one address and name the conversation in the body do: Slack's
/// `chat.postMessage` pins `channel` and `thread_ts`, WhatsApp's
/// `/<version>/<number id>/messages` pins `recipient_type` and `to`. A
/// reply is confined to its conversation by [pinned], which an enforcer
/// checks with [admitsBody], never by where it is sent.
final class RepliesWithPinnedBodyFields extends ReplyEndpoint {
  const RepliesWithPinnedBodyFields._(this.origin, this.path, this.pinned);

  /// Replies to [path] on [origin] whose body carries [pinned]; null when
  /// [path] has a query or is the origin's bare address, since a service
  /// may read a conversation from a query that [admitsBody] never sees.
  static RepliesWithPinnedBodyFields? at({
    required Origin origin,
    required WebPath path,
    required PinnedBodyFields pinned,
  }) => path == WebPath.root || path.value.contains('?')
      ? null
      : RepliesWithPinnedBodyFields._(origin, path, pinned);

  @override
  final Origin origin;

  /// The one path a reply is sent to, with no query.
  final WebPath path;

  /// The fields that name the conversation, which every reply's body
  /// carries with exactly these values.
  final PinnedBodyFields pinned;

  @override
  bool operator ==(Object other) =>
      other is RepliesWithPinnedBodyFields &&
      other.origin == origin &&
      other.path == path &&
      other.pinned == pinned;

  @override
  int get hashCode => Object.hash(origin, path, pinned);

  /// A request to exactly [path] on [origin], with no query.
  @override
  bool admitsAddress(Origin to, WebPath path) =>
      to == origin && path == this.path;

  /// The prefix ending at [path]'s last `/`, such as `/api/` for
  /// `/api/chat.postMessage`.
  @override
  PathPrefix get redirectsStayUnder => PathPrefix.parse(
    path.value.substring(0, path.value.lastIndexOf('/') + 1),
  )!;

  /// Whether a request sent as [contentType] with [body] carries this
  /// endpoint's conversation and no other: [contentType] is
  /// `application/json`, with at most a `charset=utf-8` parameter, and
  /// [body] is one JSON object, read refusing a repeated key, holding every
  /// field of [pinned] as exactly its string. Any other field may be there,
  /// since the reply itself is in the body too. A form-encoded body is
  /// refused: a service may read the conversation from it in ways this
  /// check can't see.
  bool admitsBody({required String contentType, required String body}) {
    if (!_isJson(contentType)) return false;
    final JsonObject object;
    try {
      object = JsonObject.decode(body);
    } on FormatException {
      return false;
    }
    for (final MapEntry(:key, :value) in pinned.fields.entries) {
      if (object.raw(key) != value) return false;
    }
    return true;
  }

  static bool _isJson(String contentType) {
    final parts = [for (final p in contentType.split(';')) p.trim()];
    // wire-ok: a Content-Type header, read once here and never stored.
    if (parts.first.toLowerCase() != 'application/json') return false;
    return switch (parts.sublist(1)) {
      [] => true,
      // wire-ok: the one parameter a JSON Content-Type may carry.
      [final charset] => charset.toLowerCase() == 'charset=utf-8',
      _ => false,
    };
  }

  @override
  String toString() => 'RepliesWithPinnedBodyFields($origin, $path, $pinned)';
}

/// The fields a reply's body must carry to stay in its conversation: one or
/// more names, each with the exact string it must hold, such as Slack's
/// `{"channel": "C0123ABC", "thread_ts": "1700000000.000100"}`.
final class PinnedBodyFields {
  const PinnedBodyFields._(this.fields);

  /// [fields] as pinned fields; null when there are none or a name is
  /// empty, since a body need then carry nothing to pass.
  static PinnedBodyFields? of(Map<String, String> fields) =>
      fields.isEmpty || fields.keys.any((name) => name.isEmpty)
      ? null
      : PinnedBodyFields._(Map.unmodifiable(fields));

  /// Each pinned field's name and the string it must hold.
  final Map<String, String> fields;

  @override
  bool operator ==(Object other) =>
      other is PinnedBodyFields &&
      other.fields.length == fields.length &&
      fields.entries.every((e) => other.fields[e.key] == e.value);

  @override
  int get hashCode => Object.hashAllUnordered(
    fields.entries.map((e) => Object.hash(e.key, e.value)),
  );

  @override
  String toString() => '$fields';
}

/// The one path a Slack reply was sent to before 0.2.0, which a logbook's
/// `in-slack-conversation` case means.
final _slackPostMessage = WebPath.parse('/api/chat.postMessage')!;

/// [endpoint] as JSON:
///
///     {"case": "under-web-address", "addressPrefix": <address prefix>}
///     {"case": "with-pinned-body-fields", "origin": <origin>,
///      "path": <path>, "pinned": {<name>: <string>, ...}}
///
/// `<address prefix>` and `<origin>` are as is_web_address_vocabulary's
/// `encodeAddressPrefix` and `encodeOrigin` write them.
JsonObject encodeReplyEndpoint(ReplyEndpoint endpoint) => JsonObject.of(
  switch (endpoint) {
    RepliesUnderWebAddress(:final prefix) => {
      'case': ReplyEndpointCase.underWebAddress.wire,
      'addressPrefix': encodeAddressPrefix(prefix),
    },
    RepliesWithPinnedBodyFields(:final origin, :final path, :final pinned) => {
      'case': ReplyEndpointCase.withPinnedBodyFields.wire,
      'origin': encodeOrigin(origin),
      'path': path.value,
      'pinned': encodePinnedBodyFields(pinned),
    },
  },
);

/// [pinned] as a JSON object of its names and strings.
JsonObject encodePinnedBodyFields(PinnedBodyFields pinned) =>
    JsonObject.of(pinned.fields);

/// [json] read back as the endpoint [encodeReplyEndpoint] wrote. A
/// [FormatException] naming [field] for anything it doesn't write: an
/// unknown case, a field missing, extra or malformed.
///
/// A logbook written before 0.2.0 holds Slack's endpoints as
/// `{"case": "in-slack-conversation", "origin", "channel", "thread"?}`.
/// Each reads back as the [RepliesWithPinnedBodyFields] it always meant:
/// `/api/chat.postMessage` on its origin, pinning `channel` and, when it
/// has one, `thread_ts`.
ReplyEndpoint decodeReplyEndpoint(Object? json, String field) {
  final object = StrictObjectReader.of(json, field);
  switch (object.kind('a reply endpoint')) {
    case ReplyEndpointCase.underWebAddress:
      object.allowOnly(const {'case', 'addressPrefix'});
      return RepliesUnderWebAddress(
        decodeAddressPrefix(
          object.raw('addressPrefix'),
          object.nested('addressPrefix'),
        ),
      );
    case ReplyEndpointCase.withPinnedBodyFields:
      object.allowOnly(const {'case', 'origin', 'path', 'pinned'});
      return RepliesWithPinnedBodyFields.at(
            origin: decodeOrigin(object.raw('origin'), object.nested('origin')),
            path: object.parsed('path', WebPath.parse, 'a web path'),
            pinned: decodePinnedBodyFields(
              object.raw('pinned'),
              object.nested('pinned'),
            ),
          ) ??
          object.refuse('`path` has a query or is empty');
    case ReplyEndpointCase.slackConversationAsFirstWritten:
      object.allowOnly(const {'case', 'origin', 'channel', 'thread'});
      final channel = object.parsed(
        'channel',
        slackChannelIdAsFirstWritten,
        'a Slack channel id',
      );
      final thread = object.parsedIfPresent(
        'thread',
        slackTimestampAsFirstWritten,
        'a Slack thread timestamp',
      );
      return RepliesWithPinnedBodyFields._(
        decodeOrigin(object.raw('origin'), object.nested('origin')),
        _slackPostMessage,
        PinnedBodyFields._({'channel': channel, 'thread_ts': ?thread}),
      );
  }
}

/// [json] read back as the fields [encodePinnedBodyFields] wrote: an
/// object of one or more non-empty names, each holding a string.
PinnedBodyFields decodePinnedBodyFields(Object? json, String field) {
  final object = StrictObjectReader.of(json, field);
  final fields = <String, String>{
    for (final name in object.keys)
      name: object.parsed(name, (s) => s, 'a string'),
  };
  return PinnedBodyFields.of(fields) ??
      object.refuse('no fields, or a field with no name');
}
