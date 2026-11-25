/// A reply into a conversation: a message posted back into the external
/// chat conversation an event came from, such as a Slack thread or a
/// Teams chat. Never an HTTP response, and never a model's output until it
/// is sent there.
///
/// Where it goes, a `ReplyEndpoint`; what it says, a `ReplyContent` of
/// `ReplyText`; and the message it posted, a `PostedMessage`; with their
/// JSON.
library;

export 'src/posted_message.dart';
export 'src/reply_content.dart';
export 'src/reply_endpoint.dart';
export 'src/reply_text.dart';
