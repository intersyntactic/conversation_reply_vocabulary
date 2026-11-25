/// What a reply sends: its text and an optional footer, and their JSON.
library;

import 'package:checked_json/checked_json.dart' show JsonObject;

import 'reply_text.dart';
import 'strict_object_reader.dart';

/// A reply's [text], and a [footer] shown beside it when there is one,
/// such as a turn's usage. Both leave the machine, so both are approved
/// and recorded together.
final class ReplyContent {
  const ReplyContent({required this.text, this.footer});

  final ReplyText text;

  final ReplyText? footer;

  @override
  bool operator ==(Object other) =>
      other is ReplyContent && other.text == text && other.footer == footer;

  @override
  int get hashCode => Object.hash(text, footer);

  @override
  String toString() => 'ReplyContent($text, $footer)';
}

/// [content] as JSON: `{"text": <text>, "footer": <text>?}`, with
/// `footer` left out when there is none.
JsonObject encodeReplyContent(ReplyContent content) => JsonObject.of({
  'text': encodeReplyText(content.text),
  'footer': ?content.footer?.value,
});

/// [json] read back as the content [encodeReplyContent] wrote. A
/// [FormatException] naming [field] for anything it doesn't write: a
/// field missing, extra, blank or not a string, or a `footer` of null.
ReplyContent decodeReplyContent(Object? json, String field) {
  final object = StrictObjectReader.of(json, field)
    ..allowOnly(const {'text', 'footer'});
  return ReplyContent(
    text: object.parsed('text', ReplyText.parse, 'a reply text'),
    footer: object.parsedIfPresent('footer', ReplyText.parse, 'a reply text'),
  );
}
