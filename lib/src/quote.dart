/// A message a person's message quotes, and who wrote it.
library;

import 'package:checked_json/checked_json.dart';
import 'package:is_shapes/is_shapes.dart' show ActorId;

import 'source_message_id.dart';

/// Who wrote the message a [Quote] quotes.
///
/// Not always resolvable: a quote can name someone who never wrote to the
/// trajectory the quoting module hears through, such as someone in a group
/// chat who never addressed the agent. A reader switches on both cases: a
/// display name is something a source showed alongside the quote, never an
/// identity, so nothing reads [UnknownAuthor] as one.
sealed class QuotedAuthor {
  const QuotedAuthor();

  /// [json] as a [QuotedAuthor], read strictly: an unknown shape, a field
  /// missing, extra or of the wrong type, or a malformed id, is a
  /// [FormatException].
  factory QuotedAuthor.fromJson(JsonObject json) {
    final (author, fields) = switch (json.string('shape')) {
      'KnownAuthor' => (
        KnownAuthor(
          ActorId.parse(json.string('actor')) ??
              (throw JsonFieldException('actor', 'an actor id')),
        ),
        const {'shape', 'actor'},
      ),
      'UnknownAuthor' => (
        UnknownAuthor(json.stringOrNull('displayName')),
        const {'shape', 'displayName'},
      ),
      final shape => throw FormatException(
        '`shape` is not a quoted author: $shape',
      ),
    };
    for (final key in json.keys) {
      if (!fields.contains(key)) {
        throw FormatException(
          '`$key` is not a field of ${json.string('shape')}',
        );
      }
    }
    return author;
  }

  /// This [QuotedAuthor] as JSON, for `jsonEncode` inside a [Quote].
  JsonObject toJson();
}

/// The quoted message's author, resolved to an actor id.
final class KnownAuthor extends QuotedAuthor {
  const KnownAuthor(this.actor);

  /// Who wrote the quoted message.
  final ActorId actor;

  @override
  JsonObject toJson() =>
      JsonObject.of({'shape': 'KnownAuthor', 'actor': actor.value});
}

/// The quoted message's author wasn't in the record, or a module's attempt
/// to resolve one failed or was refused.
final class UnknownAuthor extends QuotedAuthor {
  const UnknownAuthor(this.displayName);

  /// Whatever the source showed alongside the quote, if it showed anything.
  final String? displayName;

  @override
  JsonObject toJson() =>
      JsonObject.of({'shape': 'UnknownAuthor', 'displayName': ?displayName});
}

/// A message a `UserSaid` quotes, as its source carries it.
final class Quote {
  const Quote({required this.source, required this.author, this.preview});

  /// The quoted message's id, in its source's own terms. Always within the
  /// same conversation as the message that quotes it, since a quote never
  /// reaches across sources.
  final SourceMessageId source;

  /// Who wrote the quoted message.
  final QuotedAuthor author;

  /// A shortened copy of the quoted text, if the source showed one
  /// alongside the quote. Matters most when [source] never reached the
  /// trajectory: then this is the only trace of what was quoted.
  final String? preview;

  /// [json] as a [Quote], read strictly: a field missing, extra or of the
  /// wrong type, or a malformed id, is a [FormatException].
  factory Quote.fromJson(JsonObject json) {
    const fields = {'source', 'author', 'preview'};
    for (final key in json.keys) {
      if (!fields.contains(key)) {
        throw FormatException('`$key` is not a field of Quote');
      }
    }
    return Quote(
      source:
          SourceMessageId.parse(json.string('source')) ??
          (throw JsonFieldException('source', 'a source message id')),
      author: QuotedAuthor.fromJson(json.object('author')),
      preview: json.stringOrNull('preview'),
    );
  }

  /// This [Quote] as JSON, for `jsonEncode` inside a `UserSaid` or an
  /// `Edited`.
  JsonObject toJson() => JsonObject.of({
    'source': source.value,
    'author': author.toJson(),
    'preview': ?preview,
  });
}
