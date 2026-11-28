/// What kind of conversation a message came from, in terms no one chat
/// service owns, so code that decides where an agent may answer needn't
/// know Slack, Teams or WhatsApp.
library;

/// What kind of conversation a message came from. A module maps its own
/// service's types onto these, and says [notKnown] rather than guess, so
/// whoever decides where an agent may answer has to decide that case too.
enum ConversationKind {
  /// Between one person and the agent, such as a Slack direct message.
  oneToOne('one-to-one'),

  /// A chat among a fixed set of people that isn't a channel, such as a
  /// Slack group direct message or a WhatsApp group.
  groupChat('group-chat'),

  /// A named channel that anyone where it lives may find and read, such as
  /// a Slack public channel.
  publicChannel('public-channel'),

  /// A named channel only its members may read, such as a Slack private
  /// channel.
  privateChannel('private-channel'),

  /// The module can't tell which of the others it is.
  notKnown('not-known');

  const ConversationKind(this.wire);

  /// The kind as its JSON writes it.
  final String wire;

  /// The kind whose [wire] is [s]; null unless one is.
  static ConversationKind? parse(String s) {
    for (final kind in values) {
      if (kind.wire == s) return kind;
    }
    return null;
  }
}
