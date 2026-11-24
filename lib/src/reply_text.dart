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

  /// [s] as reply text, exactly as given; null when it is blank. Blank
  /// means whitespace or Unicode format characters (category Cf, such as
  /// U+200B) only. That is not "nothing visible": U+3164 and U+2800 render
  /// as nothing but are letters and symbols, so they are text.
  static ReplyText? parse(String s) =>
      _blank.hasMatch(s) ? null : ReplyText._(s);

  static final _blank = RegExp(r'^[\s\p{Cf}]*$', unicode: true);

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
