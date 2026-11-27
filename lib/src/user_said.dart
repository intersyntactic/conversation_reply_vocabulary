/// What a person said, as a module received it from its source.
library;

import 'package:checked_json/checked_json.dart';
import 'package:is_shapes/is_shapes.dart' show ActorId;

import 'quote.dart';
import 'source_message_id.dart';

/// What a person said, as a module received it from its source.
///
/// A module describes it once and hands it on; whatever appends it to the
/// trajectory delivers back the turn it was given, and everything after it
/// points at that turn. So a module never compares text to tell its own
/// message from an echo of it.
///
/// Who may write one is checked once, outside every module, by whatever
/// appends on a person's behalf, so one module can never put words in
/// another's mouth.
///
/// It travels as JSON in a node's map form,
/// `{"shape": "UserSaid", ...its fields}`, so it crosses a boundary
/// already typed and nothing downstream parses a stranger's bytes.
final class UserSaid {
  const UserSaid({
    required this.author,
    required this.source,
    required this.text,
    this.quotes,
  });

  /// Who said it.
  final ActorId author;

  /// The message's id in its source's own terms.
  final SourceMessageId source;

  /// What they said. May be empty when [quotes] is set: a reply that is
  /// only a quote and an @-mention carries nothing of its own to say.
  final String text;

  /// The message this one quotes or replies to, if its source carries one.
  final Quote? quotes;

  /// The `shape` this decodes and encodes as, for a check that no two
  /// packages' top-level node shapes collide. [QuotedAuthor]'s shapes nest
  /// inside a [Quote] and are never dispatched at that level.
  static const String shapeName = 'UserSaid';

  /// [json] as a [UserSaid], read strictly: an unknown shape, a field
  /// missing, extra or of the wrong type, or a malformed id, is a
  /// [FormatException].
  factory UserSaid.fromJson(JsonObject json) {
    if (json.string('shape') != shapeName) {
      throw FormatException('`shape` is not $shapeName: ${json.raw('shape')}');
    }
    const fields = {'shape', 'author', 'source', 'text', 'quotes'};
    for (final key in json.keys) {
      if (!fields.contains(key)) {
        throw FormatException('`$key` is not a field of $shapeName');
      }
    }
    return UserSaid(
      author:
          ActorId.parse(json.string('author')) ??
          (throw JsonFieldException('author', 'an actor id')),
      source:
          SourceMessageId.parse(json.string('source')) ??
          (throw JsonFieldException('source', 'a source message id')),
      text: json.string('text'),
      quotes: json.has('quotes') ? Quote.fromJson(json.object('quotes')) : null,
    );
  }

  /// This [UserSaid] in a node's map form, for `jsonEncode`.
  JsonObject toJson() => JsonObject.of({
    'shape': shapeName,
    'author': author.value,
    'source': source.value,
    'text': text,
    'quotes': ?quotes?.toJson(),
  });
}
