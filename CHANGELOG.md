# Changelog

## 0.2.0

- Breaking: `ReplyEndpoint` and `PostedMessage` each have a third case,
  so a switch over every case needs one more arm.
- `RepliesInWhatsAppChat`: replies through the WhatsApp Cloud API. It
  admits exactly `/<graphApiVersion>/<phoneNumberId>/messages` on its
  origin, with no query, and names its `WhatsAppChat` in the request's
  body: a `WhatsAppIndividualChat` by `WhatsAppUserPhoneNumber`, or a
  `WhatsAppGroupChat` by `WhatsAppGroupId`. The Graph API version is a
  field the module vouches for, not one this package pins.
- `ReplyEndpoint.origin`: the site every case's replies are sent to,
  so code that needs only the site needn't switch over the cases.
- `PostedInWhatsAppChat`: the message such a reply posted, by its chat and
  the `ServerAssignedMessageId` WhatsApp gave it.
- JSON case `in-whatsapp-chat` for both. Existing cases' JSON is
  unchanged.

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
