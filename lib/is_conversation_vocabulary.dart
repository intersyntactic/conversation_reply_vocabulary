/// An external chat conversation, such as a Slack thread or a Teams chat,
/// both ways.
///
/// Into the trajectory: what a person said, a `UserSaid`, which may carry
/// a `Quote`; and what became of that message at its source, a
/// `WhatChanged`. Each travels in a node's map form,
/// `{"shape": "<class name>", ...its fields}`.
///
/// Back out: a reply, a message posted back into the conversation an
/// event came from. Where it goes, a `ReplyEndpoint`; what it says, a
/// `ReplyContent` of `ReplyText`; and the message it posted, a
/// `PostedMessage`. A reply is never an HTTP response, and never a model's
/// output until it is sent there.
library;

export 'src/posted_message.dart';
export 'src/quote.dart';
export 'src/reply_content.dart';
export 'src/reply_endpoint.dart';
export 'src/reply_text.dart';
export 'src/source_message_id.dart';
export 'src/user_said.dart';
export 'src/what_changed.dart';
