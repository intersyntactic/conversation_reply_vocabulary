/// The text of a reply, which is never blank, and its form in JSON.
library;

/// A reply's text: anything but empty or whitespace only, kept exactly as
/// given, so what is approved and recorded is byte for byte what is sent.
///
/// It has no length limit; a driver splits a long text across messages.
final class ReplyText {
  const ReplyText._(this.value);

  /// The text, exactly as given.
  final String value;

  /// [s] as reply text, untrimmed; null when it is empty or only
  /// whitespace, as `String.trim` defines whitespace.
  static ReplyText? parse(String s) => s.trim().isEmpty ? null : ReplyText._(s);

  @override
  bool operator ==(Object other) => other is ReplyText && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// [text] as JSON: a string, exactly the text.
String encodeReplyText(ReplyText text) => text.value;

/// [json] read back as the text [encodeReplyText] wrote. A
/// [FormatException] naming [field] unless it is a string [ReplyText.parse]
/// accepts.
ReplyText decodeReplyText(Object? json, String field) {
  final text = switch (json) {
    final String s => ReplyText.parse(s),
    _ => null,
  };
  if (text == null) {
    throw FormatException('$field: not a reply text, which is never blank');
  }
  return text;
}
