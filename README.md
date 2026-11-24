# is_reply_vocabulary

Where a reply goes and the message it posted, as values that name exactly
one conversation, with their JSON. It holds types and does nothing, and
depends on nothing but `dart:core` and `is_web_address_vocabulary`.

- `ReplyEndpoint`: where replies to an event go, sealed, one case for each
  way an external system takes replies.
  - `RepliesUnderWebAddress`: an `AddressPrefix` that names the
    conversation, as Teams' Bot Connector takes replies.
  - `RepliesInSlackConversation`: Slack's `Origin`, a `SlackChannelId` and
    the thread's `SlackMessageTimestamp`, null only for a direct message.
- `PostedMessage`: the message a reply posted, sealed, with one case for
  each `ReplyEndpoint` case. Each case is made only by `answering`, which
  takes the endpoint it answers and its conversation from it, or by
  `decodePostedMessage`.
  - `PostedUnderWebAddress`: the conversation's `AddressPrefix` and the
    `ServerAssignedMessageId` its server gave the message.
  - `PostedInSlackConversation`: the `SlackChannelId` and the posted
    message's `SlackMessageTimestamp`, which a later reply can thread
    under.
- `ReplyText`: what a reply says, never empty or whitespace only, kept
  exactly as given. It has no length limit; a driver splits a long text.
  Its JSON is a plain string.
- `SlackChannelId` (`C…`, `D…` or `G…`), `SlackMessageTimestamp`
  (`1700000000.000100`) and `ServerAssignedMessageId` (non-empty, no
  whitespace) are made only by `parse`, which returns null for anything
  else.

Each sealed type has an `encodeX` / `decodeX` pair. A decode throws a
`FormatException` naming the field for an unknown case or a field that is
missing, extra or malformed. Both name their cases the same way:

    {"case":"in-slack-conversation","origin":"https://slack.com","channel":"C0123ABC","thread":"1700000000.000100"}
    {"case":"in-slack-conversation","channel":"C0123ABC","timestamp":"1700000000.000200"}

`is_docking_station_api` re-exports all of this from 0.6.0, so its
`ReplyEndpoint` and this one are the same type. A package that uses both
must require `is_docking_station_api: ^0.6.0`; 0.5.0 declares its own.
