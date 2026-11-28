/// The kind of conversation a reply goes to, as the `case` field that both
/// a reply endpoint's and a posted message's JSON name it by.
library;

enum ConversationKind {
  /// A conversation named by a web address, as Teams' are.
  underWebAddress('under-web-address'),

  /// A Slack conversation, named by its channel and thread.
  inSlackConversation('in-slack-conversation'),

  /// A WhatsApp chat, named by the business's number and the chat.
  inWhatsAppChat('in-whatsapp-chat');

  const ConversationKind(this.wire);

  /// The kind as its JSON's `case` field writes it.
  final String wire;

  /// The kind whose [wire] is [json]; null unless one is.
  static ConversationKind? parse(Object? json) {
    for (final kind in values) {
      if (kind.wire == json) return kind;
    }
    return null;
  }
}
