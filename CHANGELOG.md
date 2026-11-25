# Changelog

## 0.2.0

- Breaking: `encodeReplyEndpoint` and `encodePostedMessage` return a
  `checked_json` `JsonObject` instead of a `Map<String, Object?>`. The
  JSON they write is unchanged, byte for byte; `jsonEncode` writes a
  `JsonObject` as it is. A caller that put the result inside another map
  or list needs no change. One that read it by key, spread it or added to
  it reads it through a reader, `raw`, `withFields` or `without` instead.

## 0.1.2

- `decodeReplyEndpoint` and `decodePostedMessage` read their object
  through `checked_json`'s `JsonObject` instead of a map read by key.
  They take, accept, refuse and say the same things as before.

## 0.1.1

- New: `ReplyText`, a reply's text, made only by `parse`, which returns
  null for text of only whitespace or Unicode format characters (Cf, such
  as U+200B) and otherwise keeps it exactly, untrimmed. It has no length limit. With `encodeReplyText` /
  `decodeReplyText`, a plain JSON string.

## 0.1.0

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
