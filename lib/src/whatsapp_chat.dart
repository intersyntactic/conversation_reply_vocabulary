/// A WhatsApp chat a reply goes to through the WhatsApp Cloud API, and the
/// ids that name it there, with its JSON.
library;

import 'package:checked_json/checked_json.dart' show JsonObject;

import 'strict_object_reader.dart';

/// The chat a WhatsApp reply goes to, named in the request's body:
/// [WhatsAppIndividualChat] or [WhatsAppGroupChat].
sealed class WhatsAppChat {
  const WhatsAppChat();
}

/// A one-to-one chat with the person whose number is [phoneNumber]; a reply
/// is sent with `recipient_type` `individual` and [phoneNumber] as `to`.
final class WhatsAppIndividualChat extends WhatsAppChat {
  const WhatsAppIndividualChat(this.phoneNumber);

  final WhatsAppUserPhoneNumber phoneNumber;

  @override
  bool operator ==(Object other) =>
      other is WhatsAppIndividualChat && other.phoneNumber == phoneNumber;

  @override
  int get hashCode => phoneNumber.hashCode;

  @override
  String toString() => 'WhatsAppIndividualChat($phoneNumber)';
}

/// A group chat; a reply is sent with `recipient_type` `group` and [id] as
/// `to`.
final class WhatsAppGroupChat extends WhatsAppChat {
  const WhatsAppGroupChat(this.id);

  final WhatsAppGroupId id;

  @override
  bool operator ==(Object other) =>
      other is WhatsAppGroupChat && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'WhatsAppGroupChat($id)';
}

/// A person's phone number as WhatsApp's `wa_id` writes it: country code
/// and number, digits only, with no `+`, such as `61400000000`.
final class WhatsAppUserPhoneNumber {
  const WhatsAppUserPhoneNumber._(this.value);

  /// The number, as WhatsApp writes it.
  final String value;

  /// [s] as a phone number; null unless it is E.164's digits without `+`.
  static WhatsAppUserPhoneNumber? parse(String s) =>
      _number.hasMatch(s) ? WhatsAppUserPhoneNumber._(s) : null;

  static final _number = RegExp(r'^[1-9][0-9]{5,14}$');

  @override
  bool operator ==(Object other) =>
      other is WhatsAppUserPhoneNumber && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// A WhatsApp group's id, as the Groups API writes it, such as
/// `HBgLMTY1MDM4Nzk0MzkVAgASGBQzQTRBNjU5OUFFRTAzODEwMTQ0RgA`.
final class WhatsAppGroupId {
  const WhatsAppGroupId._(this.value);

  /// The id, as WhatsApp writes it.
  final String value;

  /// [s] as a group id; null unless it is 1 to 256 base64 characters,
  /// standard or URL-safe.
  static WhatsAppGroupId? parse(String s) =>
      _id.hasMatch(s) ? WhatsAppGroupId._(s) : null;

  static final _id = RegExp(r'^[A-Za-z0-9+/=_-]{1,256}$');

  @override
  bool operator ==(Object other) =>
      other is WhatsAppGroupId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// The id Meta gave a business's WhatsApp phone number, which names the
/// sender in a reply's address. It is not the phone number itself.
final class WhatsAppBusinessPhoneNumberId {
  const WhatsAppBusinessPhoneNumberId._(this.value);

  /// The id, as Meta writes it.
  final String value;

  /// [s] as a phone number id; null unless it is 5 to 30 digits.
  static WhatsAppBusinessPhoneNumberId? parse(String s) =>
      _id.hasMatch(s) ? WhatsAppBusinessPhoneNumberId._(s) : null;

  static final _id = RegExp(r'^[0-9]{5,30}$');

  @override
  bool operator ==(Object other) =>
      other is WhatsAppBusinessPhoneNumberId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// A version of Meta's Graph API, the first segment of a reply's path, such
/// as `v27.0`.
final class GraphApiVersion {
  const GraphApiVersion._(this.value);

  /// The version, as its path segment writes it.
  final String value;

  /// [s] as a version; null unless it is `v`, a major and a minor number.
  static GraphApiVersion? parse(String s) =>
      _version.hasMatch(s) ? GraphApiVersion._(s) : null;

  static final _version = RegExp(r'^v[1-9][0-9]*\.[0-9]+$');

  @override
  bool operator ==(Object other) =>
      other is GraphApiVersion && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Which case of [WhatsAppChat] its JSON's `kind` field names.
enum _WhatsAppChatKind {
  individual('individual'),
  group('group');

  const _WhatsAppChatKind(this.wire);

  final String wire;

  static _WhatsAppChatKind? parse(String s) {
    for (final kind in values) {
      if (kind.wire == s) return kind;
    }
    return null;
  }
}

/// [chat] as JSON: `{"kind": "individual", "id": <phone number>}` or
/// `{"kind": "group", "id": <group id>}`.
JsonObject encodeWhatsAppChat(WhatsAppChat chat) =>
    JsonObject.of(switch (chat) {
      WhatsAppIndividualChat(:final phoneNumber) => {
        'kind': _WhatsAppChatKind.individual.wire,
        'id': phoneNumber.value,
      },
      WhatsAppGroupChat(:final id) => {
        'kind': _WhatsAppChatKind.group.wire,
        'id': id.value,
      },
    });

/// [json] read back as the chat [encodeWhatsAppChat] wrote. A
/// [FormatException] naming [field] for anything it doesn't write.
WhatsAppChat decodeWhatsAppChat(Object? json, String field) {
  final object = StrictObjectReader.of(json, field);
  object.allowOnly(const {'kind', 'id'});
  return switch (object.parsed(
    'kind',
    _WhatsAppChatKind.parse,
    'a WhatsApp chat kind',
  )) {
    _WhatsAppChatKind.individual => WhatsAppIndividualChat(
      object.parsed(
        'id',
        WhatsAppUserPhoneNumber.parse,
        'a WhatsApp phone number',
      ),
    ),
    _WhatsAppChatKind.group => WhatsAppGroupChat(
      object.parsed('id', WhatsAppGroupId.parse, 'a WhatsApp group id'),
    ),
  };
}
