/// Where something sits in an external system, and the mission it belongs to.
library;

/// An address in an external system: a Teams chat, channel or channel thread, a
/// Slack channel. Each one is kept under a trajectory, and one that others
/// sit inside, such as a channel, as a mission.
///
/// Written like an `ActorId`, a source, a colon and the rest, such as
/// `teams:19:abc@thread.v2`, so two modules never name two addresses
/// alike.
final class AddressInExternalSystem {
  const AddressInExternalSystem._(this.value);

  /// The id, as text.
  final String value;

  /// [s] as an address; null unless it is a source, a colon, and the
  /// rest, with the rest printable ASCII and no spaces.
  static AddressInExternalSystem? parse(String s) =>
      _id.hasMatch(s) ? AddressInExternalSystem._(s) : null;

  static final _id = RegExp(r'^[a-z][a-z0-9-]*:[\x21-\x7e]+$');

  @override
  bool operator ==(Object other) =>
      other is AddressInExternalSystem && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// The address of the mission [address] belongs to: [containingAddress],
/// the address it sits inside, such as a thread's channel; or [address]
/// itself when it sits inside none, as a chat with no threads does.
///
/// Every side that groups addresses into missions (the docking station,
/// the airlock, flight rules) reads it here, so they can't disagree. Both
/// parameters are named because they share a type, and swapped they
/// would still compile.
AddressInExternalSystem missionAddress({
  required AddressInExternalSystem address,
  required AddressInExternalSystem? containingAddress,
}) => containingAddress ?? address;
