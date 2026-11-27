/// Where replies to an event go, a `ReplyEndpoint`, and its JSON, alone.
///
/// For code that must not load a decoder of what strangers sent: this
/// library reaches none of `UserSaid`, `Quote` or `WhatChanged`, which the
/// whole package's library exports.
library;

export 'src/reply_endpoint.dart';
