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

/// Replies go to exactly [path] on [origin], as a JSON body that holds the
/// fields [pinned] says and lacks the ones it refuses, as services that
/// take every reply at one address and name the conversation in the body
/// do: Slack's `chat.postMessage` pins `channel` and `thread_ts`, WhatsApp's
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
  /// carries with exactly these values, and those it must not carry.
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
  /// field of [pinned]'s `mustEqual` as exactly its string and none named in
  /// its `mustBeAbsent`. Any other field may be there, since the reply
  /// itself is in the body too. A form-encoded body is refused: a service
  /// may read the conversation from it in ways this check can't see.
  bool admitsBody({required String contentType, required String body}) {
    if (!_isJson(contentType)) return false;
    final JsonObject object;
    try {
      object = JsonObject.decode(body);
    } on FormatException {
      return false;
    }
    for (final MapEntry(:key, :value) in pinned.mustEqual.entries) {
      if (object.raw(key) != value) return false;
    }
    return !pinned.mustBeAbsent.any(object.has);
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

/// What a reply's body must hold to stay in its conversation: one or more
/// names in [mustEqual], each with the exact string it must hold, such as
/// Slack's `{"channel": "C0123ABC", "thread_ts": "1700000000.000100"}`;
/// and any names in [mustBeAbsent], which the body must not carry at all,
/// such as `thread_ts` for a reply at a channel's top level, or a second
/// field a service would also read a recipient from. A field can't be in
/// both.
final class PinnedBodyFields {
  const PinnedBodyFields._(this.mustEqual, this.mustBeAbsent);

  /// The pinned fields; null when [mustEqual] is empty, a name is empty,
  /// or a name is in both, since a body need then carry nothing to pass
  /// or could pass no way at all.
  static PinnedBodyFields? of(
    Map<String, String> mustEqual, {
    Set<String> mustBeAbsent = const {},
  }) =>
      mustEqual.isEmpty ||
          mustEqual.keys.any((name) => name.isEmpty) ||
          mustBeAbsent.any((name) => name.isEmpty) ||
          mustBeAbsent.any(mustEqual.containsKey)
      ? null
      : PinnedBodyFields._(
          Map.unmodifiable(mustEqual),
          Set.unmodifiable(mustBeAbsent),
        );

  /// Each field's name and the string it must hold.
  final Map<String, String> mustEqual;

  /// The names of fields the body must not carry.
  final Set<String> mustBeAbsent;

  @override
  bool operator ==(Object other) =>
      other is PinnedBodyFields &&
      other.mustEqual.length == mustEqual.length &&
      mustEqual.entries.every((e) => other.mustEqual[e.key] == e.value) &&
      other.mustBeAbsent.length == mustBeAbsent.length &&
      other.mustBeAbsent.containsAll(mustBeAbsent);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(
      mustEqual.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAllUnordered(mustBeAbsent),
  );

  @override
  String toString() => 'PinnedBodyFields($mustEqual, absent: $mustBeAbsent)';
}

/// The one path a Slack reply was sent to before 0.2.0, which a logbook's
/// `in-slack-conversation` case means.
final _slackPostMessage = WebPath.parse('/api/chat.postMessage')!;

/// [endpoint] as JSON:
///
///     {"case": "under-web-address", "addressPrefix": <address prefix>}
///     {"case": "with-pinned-body-fields", "origin": <origin>,
///      "path": <path>, "pinned": <pinned body fields>}
///
/// `<pinned body fields>` is as [encodePinnedBodyFields] writes it.
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

/// [pinned] as JSON:
///
///     {"mustEqual": {<name>: <string>, ...},
///      "mustBeAbsent": [<name>, ...]}
///
/// with `mustBeAbsent` left out when there are none, and its names sorted.
JsonObject encodePinnedBodyFields(PinnedBodyFields pinned) => JsonObject.of({
  'mustEqual': JsonObject.of(pinned.mustEqual),
  if (pinned.mustBeAbsent.isNotEmpty)
    'mustBeAbsent': [...pinned.mustBeAbsent]..sort(),
});

/// [json] read back as the endpoint [encodeReplyEndpoint] wrote. A
/// [FormatException] naming [field] for anything it doesn't write: an
/// unknown case, a field missing, extra or malformed.
///
/// A logbook written before 0.2.0 holds Slack's endpoints as
/// `{"case": "in-slack-conversation", "origin", "channel", "thread"?}`.
/// Each reads back as the [RepliesWithPinnedBodyFields] it always meant:
/// `/api/chat.postMessage` on its origin, pinning `channel` and `thread_ts`
/// when it had a thread, and refusing `thread_ts` when it had none, as a
/// reply in an unthreaded direct message was sent.
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
        switch (thread) {
          final ts? => PinnedBodyFields._(
            Map.unmodifiable({'channel': channel, 'thread_ts': ts}),
            const {},
          ),
          null => PinnedBodyFields._(
            Map.unmodifiable({'channel': channel}),
            const {'thread_ts'},
          ),
        },
      );
  }
}

/// [json] read back as the fields [encodePinnedBodyFields] wrote. A
/// [FormatException] naming [field] for anything else, including an empty
/// `mustBeAbsent`, a name twice in it, or names out of order, since each
/// pinned set is written only one way.
PinnedBodyFields decodePinnedBodyFields(Object? json, String field) {
  final object = StrictObjectReader.of(json, field);
  object.allowOnly(const {'mustEqual', 'mustBeAbsent'});
  final equal = StrictObjectReader.of(
    object.raw('mustEqual'),
    object.nested('mustEqual'),
  );
  final mustEqual = <String, String>{
    for (final name in equal.keys)
      name: equal.parsed(name, (s) => s, 'a string'),
  };
  final absentAt = object.nested('mustBeAbsent');
  final mustBeAbsent = switch (object.raw('mustBeAbsent')) {
    null when !object.has('mustBeAbsent') => const <String>[],
    final List<Object?> names when names.isNotEmpty => [
      for (final name in names)
        switch (name) {
          final String s => s,
          _ => throw FormatException('$absentAt: not a list of names'),
        },
    ],
    _ => throw FormatException('$absentAt: not a non-empty list of names'),
  };
  final sorted = [...mustBeAbsent]..sort();
  for (var i = 0; i < sorted.length; i++) {
    if (sorted[i] != mustBeAbsent[i] || (i > 0 && sorted[i] == sorted[i - 1])) {
      throw FormatException('$absentAt: names repeated or not sorted');
    }
  }
  return PinnedBodyFields.of(mustEqual, mustBeAbsent: {...mustBeAbsent}) ??
      object.refuse(
        'no fields to equal, a field with no name, or one both equal and '
        'absent',
      );
}
