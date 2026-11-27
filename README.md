# is_conversation_vocabulary

An external chat conversation, such as a Slack thread or a Teams chat, in
both directions: what a person said in it and what became of that message,
and a reply posted back into it. A reply is not an HTTP response, and not
a model's output until it is sent there.

It holds types and does nothing. It depends on `checked_json`,
`is_web_address_vocabulary` and, for `ActorId` alone, `is_shapes`. A shape
file may import it: everything it imports is on import admission's pure
list.

Its decoders read JSON that is already decoded. Decode wire text with
`checked_json`'s `decodeJsonRefusingDuplicateKeysAndUnsafeIntegers`, not
`jsonDecode`: `jsonDecode` keeps the last of two same-named keys, so a
duplicate is gone before any decoder here could refuse it.

It replaces two packages, and declares its own types, so a package moves
its dependency and every import to this name in one change:
- `is_conversation_shapes`, discontinued at 0.8.4. `UserSaid`, `Quote` and
  `WhatChanged` moved here with their JSON unchanged. Its `ReplyText`
  node, `ReplyChunk`, `UserSaidChanged` and `AgentName` did not move:
  nothing built them.
- `is_conversation_reply_vocabulary`, discontinued at 0.1.0, and before it
  `is_reply_vocabulary`. Everything in it moved here unchanged.

## What a person said

- `UserSaid`: who said it (an `ActorId`), the message's `SourceMessageId`,
  its text, and the `Quote` it carries, if any. The text may be empty, as
  in a reply that is only a quote and an @-mention.
- `Quote`: the quoted message's `SourceMessageId`, its author, and a
  shortened copy of its text if the source showed one. The author is a
  `QuotedAuthor`, sealed: `KnownAuthor` (an `ActorId`) or `UnknownAuthor`
  (whatever display name the source showed, never an identity).
- `WhatChanged`: what an earlier message became at its source, sealed:
  `Edited` (the new text and quote, wholesale), `Deleted` or `Restored`.
- `SourceMessageId`: a message's id in its source's own terms, made only
  by `parse` (non-empty, no whitespace).

These travel in a node's map form, `{"shape": "<class name>", ...fields}`,
through `fromJson` and `toJson`. `fromJson` throws a `FormatException` for
an unknown shape or a field that is missing, extra, of the wrong type or a
malformed id. `UserSaid.shapeName` and `WhatChanged.shapeNames` name the
top-level shapes, for a check that no two packages' shapes collide.

    {"shape":"UserSaid","author":"teams:f6a2","source":"1234567890.654321","text":"","quotes":{"source":"1234567890.123456","author":{"shape":"KnownAuthor","actor":"agent:7f3a9c21"}}}
    {"shape":"Edited","text":"actually, tomorrow"}

## A reply

- `ReplyEndpoint`: where replies to an event go, sealed, one case for each
  way an external system takes replies.
  - `RepliesUnderWebAddress`: an `AddressPrefix` that names the
    conversation, as Teams' Bot Connector takes replies.
  - `RepliesInSlackConversation`: Slack's `Origin`, a `SlackChannelId` and
    the thread's `SlackMessageTimestamp`, null only for a direct message.
  - `admitsAddress(to, path)` says whether a request goes to an address
    the endpoint's replies are sent to: under the prefix for a web
    address, exactly `/api/chat.postMessage` on its origin for Slack. It
    checks the address, never the conversation.
    `redirectsStayUnder` bounds where a redirect of an admitted request
    may go.
- `ReplyContent`: a reply's `ReplyText` and an optional footer, such as
  a turn's usage. Its JSON is `{"text": …, "footer": …?}`.
- `PostedMessage`: the message a reply posted, sealed, with one case for
  each `ReplyEndpoint` case. Each case is made only by `answering`, which
  takes the endpoint it answers and its conversation from it, or by
  `decodePostedMessage`.
  - `PostedUnderWebAddress`: the conversation's `AddressPrefix` and the
    `ServerAssignedMessageId` its server gave the message.
  - `PostedInSlackConversation`: the `SlackChannelId` and the posted
    message's `SlackMessageTimestamp`, which a later reply can thread
    under.
- `ReplyText`: what a reply says, never only whitespace or Unicode format
  characters (such as U+200B), kept exactly as given. It has no length
  limit; a driver splits a long text. Its JSON is a plain string.
- `SlackChannelId` (`C…`, `D…` or `G…`), `SlackMessageTimestamp`
  (`1700000000.000100`) and `ServerAssignedMessageId` (non-empty, no
  whitespace) are made only by `parse`, which returns null for anything
  else.

`package:is_conversation_vocabulary/reply_endpoint.dart` exports
`ReplyEndpoint` and its JSON alone, for code that must not load a decoder
of what strangers sent: it reaches none of `UserSaid`, `Quote` or
`WhatChanged`.

Each sealed reply type has an `encodeX` / `decodeX` pair. A decode throws
a `FormatException` naming the field for an unknown case or a field that
is missing, extra or malformed. Both name their cases the same way:

    {"case":"in-slack-conversation","origin":"https://slack.com","channel":"C0123ABC","thread":"1700000000.000100"}
    {"case":"in-slack-conversation","channel":"C0123ABC","timestamp":"1700000000.000200"}
