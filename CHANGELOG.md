# Changelog

## 0.2.0

- Breaking: no case of `ReplyEndpoint` or `PostedMessage` names a chat
  service. There are two ways a reply is kept to its conversation, and one
  case for each:
  - `RepliesUnderWebAddress`, unchanged: by the web address it is sent to,
    as Teams takes replies.
  - `RepliesWithPinnedBodyFields`, replacing `RepliesInSlackConversation`:
    by fields its body must carry. It admits exactly one `path` on its
    `origin`, with no query, and `admitsBody` passes a request only when it
    is sent as `application/json` (at most `charset=utf-8`) and its body,
    read refusing a repeated key, holds every field of its
    `PinnedBodyFields.mustEqual` as exactly that string, and other fields
    only as its `OtherBodyFields` allow: `AnyOtherFieldsExcept` names
    fields that must be absent (`PinnedBodyFields.of(…, mustBeAbsent:)`),
    such as `thread_ts` for a reply at a channel's top level or a second
    field a service would also read a recipient from;
    `OnlyTheseOtherFields` allows no field it doesn't name
    (`PinnedBodyFields.allowingOnly(…, otherFields:)`), so one a service
    adds later, or one such as Slack's `reply_broadcast` that reaches past
    the pin, can't get through. Slack pins `channel` and
    `thread_ts` at `/api/chat.postMessage`; WhatsApp pins
    `messaging_product`, `recipient_type` and `to` at
    `/<version>/<number id>/messages`. A form-encoded body or a query is
    refused, since a service may read the conversation from either.
  - `PostedWithPinnedBodyFields { pinned, id }`, replacing
    `PostedInSlackConversation`. `id` is a `ServerAssignedMessageId`,
    which the sending module reads back into its own type.
- `SlackChannelId` and `SlackMessageTimestamp` are gone: a module keeps
  its service's ids on its own side.
- A logbook written before 0.2.0 still reads: each
  `"case": "in-slack-conversation"` endpoint or posted message decodes as
  the pinned case it meant (`/api/chat.postMessage`, pinning `channel`, and
  `thread_ts` when there was one or as absent when there wasn't). Only the new cases are written.
- `ReplyEndpoint.origin`: the site every case's replies are sent to, so
  code that needs only the site needn't switch over the cases.
- `ConversationKind`: what kind of conversation a message came from, in
  terms no one chat service owns: `oneToOne`, `groupChat`,
  `publicChannel`, `privateChannel`, or `notKnown` when the module can't
  tell. `notKnown` is a case, not a null, so whoever decides where an
  agent may answer has to decide it. Its JSON is `wire`, read back with
  `parse`.
- Breaking: depends on `checked_json` ^0.4.0, whose `JsonObject` is a
  class that can't be changed, not an extension type. A package that
  hands this one a `JsonObject` must be on ^0.4.0 too. Every `toJson`
  still returns a `JsonObject`, now never a `const` one, and the JSON is
  byte for byte the same.
- `package:is_conversation_vocabulary/reply_endpoint.dart` reaches
  `src/reply_endpoint_case.dart` where it reached
  `src/conversation_kind.dart`: the same internal enum of JSON cases,
  renamed `ReplyEndpointCase`. A guard that pins that library's imports by
  file needs the new name. No new package is reached.

## 0.1.1

- New library `package:is_conversation_vocabulary/reply_endpoint.dart`:
  `ReplyEndpoint` and its JSON alone, for code that must not load a
  decoder of what strangers sent. It reaches none of `UserSaid`, `Quote`
  or `WhatChanged`; a test pins exactly which files and packages it
  reaches.

## 0.1.0

- `is_conversation_shapes` and `is_conversation_reply_vocabulary` as one
  package, `is_conversation_vocabulary`. Both held one conversation's
  types, and each declared a `ReplyText`.
- From `is_conversation_shapes` 0.8.3: `UserSaid`, `SourceMessageId`,
  `Quote`, `QuotedAuthor` (`KnownAuthor`, `UnknownAuthor`) and
  `WhatChanged` (`Edited`, `Deleted`, `Restored`), with the same
  constructors, `fromJson`, `toJson`, `shapeName` and `shapeNames`, and
  byte-identical JSON.
- Not moved, since nothing built them: shapes' `ReplyText` node,
  `ReplyChunk`, `UserSaidChanged` and `AgentName`. The one `ReplyText` is
  the reply's checked text.
- From `is_conversation_reply_vocabulary` 0.1.0: everything, unchanged.
- Depends on `is_shapes` ^0.6.0, imported for `ActorId` alone; a test
  refuses any wider import or a re-export.
- Depends on `checked_json` ^0.3.0. Decode wire text with its
  `decodeJsonRefusingDuplicateKeysAndUnsafeIntegers` before any decoder
  here.

The entries below are `is_conversation_reply_vocabulary`'s.

## is_conversation_reply_vocabulary 0.1.0

- `is_reply_vocabulary` 0.2.1 under the name
  `is_conversation_reply_vocabulary`, unchanged: the same types,
  functions and JSON. "Reply" alone could be read as an HTTP
  response or a model's output; this package is about a message posted
  back into an external chat conversation. `is_reply_vocabulary` is
  discontinued at 0.2.1 and nothing re-exports it, so its types and these
  are different types: a package moves its dependency and every import in
  one change.

The entries below are `is_reply_vocabulary`'s.

## is_reply_vocabulary 0.2.1

- New: `ReplyEndpoint.admitsAddress(to, path)`, whether a request goes
  to an address the endpoint's replies are sent to, as one rule for
  every case. `RepliesUnderWebAddress` admits what its prefix covers.
  `RepliesInSlackConversation` admits exactly
  `RepliesInSlackConversation.postMessagePath` (`/api/chat.postMessage`)
  on its own origin, so no other Slack method, such as `chat.delete`, is
  reachable. It checks the address only: a Slack address is the same for
  every conversation.
- New: `ReplyEndpoint.redirectsStayUnder`, the path prefix a redirect of
  an admitted request must stay under: the prefix for a web address,
  `/api/` for Slack. It bounds redirects only, never what a reply may
  reach.
- New: `ReplyContent`, a reply's `ReplyText` and an optional footer, with
  `encodeReplyContent` / `decodeReplyContent`.
- No JSON changes.

## is_reply_vocabulary 0.2.0

- Breaking: `encodeReplyEndpoint` and `encodePostedMessage` return a
  `checked_json` `JsonObject` instead of a `Map<String, Object?>`. The
  JSON they write is unchanged, byte for byte; `jsonEncode` writes a
  `JsonObject` as it is. A caller that put the result inside another map
  or list needs no change. One that read it by key, spread it or added to
  it reads it through a reader, `raw`, `withFields` or `without` instead.

## is_reply_vocabulary 0.1.2

- `decodeReplyEndpoint` and `decodePostedMessage` read their object
  through `checked_json`'s `JsonObject` instead of a map read by key.
  They take, accept, refuse and say the same things as before.

## is_reply_vocabulary 0.1.1

- New: `ReplyText`, a reply's text, made only by `parse`, which returns
  null for text of only whitespace or Unicode format characters (Cf, such
  as U+200B) and otherwise keeps it exactly, untrimmed. It has no length limit. With `encodeReplyText` /
  `decodeReplyText`, a plain JSON string.

## is_reply_vocabulary 0.1.0

- `ReplyEndpoint`, `RepliesUnderWebAddress`, `RepliesInSlackConversation`,
  `SlackChannelId`, `encodeReplyEndpoint` and `decodeReplyEndpoint` moved
  from `is_docking_station_api` 0.5.0, so a package that needs where a
  reply goes, such as `is_effects`, doesn't depend on the docking station.
  The JSON they write is unchanged, byte for byte.
- `SlackThreadTimestamp` is now `SlackMessageTimestamp`: a Slack `ts`
  names any message, and a thread is named by its root message's. The
  field on `RepliesInSlackConversation` is still `thread`, and its JSON
  key is still `"thread"`.
- New: `PostedMessage`, the message a reply posted, with
  `PostedUnderWebAddress` (an `AddressPrefix` and a
  `ServerAssignedMessageId`) and `PostedInSlackConversation` (a
  `SlackChannelId` and a `SlackMessageTimestamp`), each made by
  `answering(endpoint, id)` so its conversation is the endpoint's, and
  `encodePostedMessage` / `decodePostedMessage`, as strict as the
  endpoint pair.
