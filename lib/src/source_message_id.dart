/// A message's id in its source's own terms.
library;

/// A message's id in its source's own terms: a Teams activity id, a Slack
/// `ts`. Opaque here: this package can't say what either source's ids look
/// like, only that a message carries one rather than a bare [String].
///
/// A module that must tell Teams' ids from Slack's wraps this on its own
/// side.
final class SourceMessageId {
  const SourceMessageId._(this.value);

  /// The id, as its source wrote it.
  final String value;

  /// [s] as a source message id, read back from text; null for an empty
  /// string or one with leading, trailing or inner whitespace, since no
  /// known source's ids have any.
  static SourceMessageId? parse(String s) =>
      s.isNotEmpty && !s.contains(RegExp(r'\s')) ? SourceMessageId._(s) : null;

  @override
  bool operator ==(Object other) =>
      other is SourceMessageId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
