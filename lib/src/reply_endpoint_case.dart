/// Which way a reply is kept to its conversation, as the `case` field that
/// both a reply endpoint's and a posted message's JSON name it by.
library;

enum ReplyEndpointCase {
  /// The conversation is in the web address a reply is sent to.
  underWebAddress('under-web-address'),

  /// The conversation is in fields the reply's body must carry.
  withPinnedBodyFields('with-pinned-body-fields'),

  /// A Slack conversation as logbooks before 0.2.0 wrote it: read, never
  /// written, as the [withPinnedBodyFields] it always meant.
  slackConversationAsFirstWritten('in-slack-conversation');

  const ReplyEndpointCase(this.wire);

  /// The case as its JSON's `case` field writes it.
  final String wire;

  /// The case whose [wire] is [json]; null unless one is.
  static ReplyEndpointCase? parse(Object? json) {
    for (final kind in values) {
      if (kind.wire == json) return kind;
    }
    return null;
  }
}

/// [s] when it is a Slack channel id as `in-slack-conversation` was written
/// with one (`C…`, `D…` or `G…`); null otherwise.
String? slackChannelIdAsFirstWritten(String s) =>
    RegExp(r'^[CDG][A-Z0-9]+$').hasMatch(s) ? s : null;

/// [s] when it is a Slack message timestamp as `in-slack-conversation` was
/// written with one, such as `1700000000.000100`; null otherwise.
String? slackTimestampAsFirstWritten(String s) =>
    RegExp(r'^\d+\.\d+$').hasMatch(s) ? s : null;
