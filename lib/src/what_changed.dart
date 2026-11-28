/// What an earlier message became at its source.
library;

import 'package:checked_json/checked_json.dart';

import 'quote.dart';

/// What an earlier `UserSaid` became, in message terms: the source's own
/// account of the change, naming the message by its `SourceMessageId`,
/// before anything maps the message to a turn.
///
/// It travels as JSON in a node's map form, as `UserSaid` does
/// (`{"shape": "<class name>", ...its fields}`).
sealed class WhatChanged {
  const WhatChanged();

  /// Every `shape` a [WhatChanged] may decode from, for a check that no
  /// two packages' top-level node shapes collide.
  static const Set<String> shapeNames = {
    Edited.shapeName,
    Deleted.shapeName,
    Restored.shapeName,
  };

  /// [json] as a [WhatChanged], read strictly: an unknown shape, a field
  /// missing, extra or of the wrong type, or a malformed id, is a
  /// [FormatException].
  factory WhatChanged.fromJson(JsonObject json) {
    final (change, fields) = switch (json.string('shape')) {
      Edited.shapeName => (
        Edited(
          text: json.string('text'),
          quotes: json.has('quotes')
              ? Quote.fromJson(json.object('quotes'))
              : null,
        ),
        const {'shape', 'text', 'quotes'},
      ),
      Deleted.shapeName => (const Deleted(), const {'shape'}),
      Restored.shapeName => (const Restored(), const {'shape'}),
      final shape => throw FormatException('`shape` is not a change: $shape'),
    };
    for (final key in json.keys) {
      if (!fields.contains(key)) {
        throw FormatException(
          '`$key` is not a field of ${json.string('shape')}',
        );
      }
    }
    return change;
  }

  /// This [WhatChanged] in a node's map form, for `jsonEncode`.
  JsonObject toJson();
}

/// The message was edited: [text] and, if the source now shows one,
/// [quotes] replace what the original message said, wholesale, since a
/// source sends the full new content on an edit, never a diff.
final class Edited extends WhatChanged {
  const Edited({required this.text, this.quotes});

  /// What the message says now. May be empty, as a `UserSaid`'s may.
  final String text;

  /// What it quotes now, if anything.
  final Quote? quotes;

  /// The `shape` this decodes and encodes as.
  static const String shapeName = 'Edited';

  @override
  JsonObject toJson() => JsonObject.of({
    'shape': shapeName,
    'text': text,
    'quotes': ?quotes?.toJson(),
  });
}

/// The message was deleted.
final class Deleted extends WhatChanged {
  const Deleted();

  /// The `shape` this decodes and encodes as.
  static const String shapeName = 'Deleted';

  @override
  JsonObject toJson() => JsonObject.of({'shape': shapeName});
}

/// A deleted message was restored.
///
/// Not a new `UserSaid`: appending one would give what is the same message
/// a new turn, orphaning anything that points at the original's. A restore
/// targets that same turn.
final class Restored extends WhatChanged {
  const Restored();

  /// The `shape` this decodes and encodes as.
  static const String shapeName = 'Restored';

  @override
  JsonObject toJson() => JsonObject.of({'shape': shapeName});
}
