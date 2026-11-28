/// A JSON object read strictly under a field's name: every refusal is a
/// [FormatException] whose message starts with that name.
library;

import 'package:checked_json/checked_json.dart';

import 'reply_endpoint_case.dart';

/// [_json], the object found at [_field], read so that anything the
/// encoder doesn't write is refused, naming [_field].
final class StrictObjectReader {
  StrictObjectReader._(this._json, this._field);

  /// [json] as an object to read, refused naming [field] unless it is one.
  factory StrictObjectReader.of(Object? json, String field) {
    final object = JsonObject.parse(json);
    if (object == null) throw FormatException('$field: not an object');
    return StrictObjectReader._(object, field);
  }

  final JsonObject _json;
  final String _field;

  /// The name of the nested field [key], for a decoder that reads it.
  String nested(String key) => '$_field.$key';

  /// The field [key] as it was decoded, for a decoder that reads it.
  Object? raw(String key) => _json.raw(key);

  /// Refuses the object, naming the field, because of [why].
  Never refuse(String why) => throw FormatException('$_field: $why');

  /// Refuses any key not in [keys].
  void allowOnly(Set<String> keys) {
    for (final key in _json.keys) {
      if (!keys.contains(key)) refuse('`$key` is not expected here');
    }
  }

  /// The `case` field as a [ReplyEndpointCase], refused as not [what].
  ReplyEndpointCase kind(String what) =>
      ReplyEndpointCase.parse(_json.raw('case')) ??
      refuse('`case` is not $what: ${_json.raw('case')}');

  /// The string field [key] read by [parse], refused as not [what] when it
  /// is absent, not a string, or one [parse] rejects.
  T parsed<T extends Object>(
    String key,
    T? Function(String) parse,
    String what,
  ) =>
      switch (_json.raw(key)) {
        final String s => parse(s),
        _ => null,
      } ??
      refuse('`$key` is not $what');

  /// As [parsed], but null when [key] is absent. A field present as null
  /// is refused, since the encoder leaves it out instead.
  T? parsedIfPresent<T extends Object>(
    String key,
    T? Function(String) parse,
    String what,
  ) => _json.has(key) ? parsed(key, parse, what) : null;
}
