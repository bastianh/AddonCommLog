# Addon Comm Log

A debugging addon for **WoW Forever** (interface 16001) that logs addon communication –
everything sent and received over the addon message channel – with a searchable log
window, statistics and an optional Titan Panel plugin.

UI language: German.

## What it captures

- **Outgoing:** hooks `C_ChatInfo.SendAddonMessage`, `C_ChatInfo.SendAddonMessageLogged`
  and `BNSendGameData`. The sending addon is detected from the call stack; messages
  routed through ChatThrottleLib / AceComm are marked as "via Lib" when the real sender
  can't be determined.
- **Incoming:** `CHAT_MSG_ADDON`, `CHAT_MSG_ADDON_LOGGED` and `BN_CHAT_MSG_ADDON`.
  The owning addon of a prefix is remembered when it calls `RegisterAddonMessagePrefix`.
- Channels: PARTY, RAID, INSTANCE_CHAT, GUILD, OFFICER, WHISPER, CHANNEL, SAY, YELL, BN.
- Values the client marks as secret are never touched and are shown as `<geschützt>`.

Only prefixes registered in your client can be received. Use `/acl watch <prefix>` to
register a foreign prefix and listen in on its traffic.

## Features

- Ring buffer (default 2000 entries) with search and filters (direction, channel, own echoes)
- Click a prefix for details and a copyable full message, right-click to filter by it
- Export the filtered log as plain text
- Statistics per prefix, channel and sender, plus message rate over the last 60 seconds
- Optionally keep the last 500 entries across `/reload` and logout
- Titan Panel plugin showing the current in/out rate, with top prefixes in the tooltip

## Slash commands

| Command | Action |
|---|---|
| `/acl` or `/commlog` | Toggle the log window |
| `/acl pause` | Pause / resume logging |
| `/acl clear` | Clear log and statistics |
| `/acl stats` | Show statistics |
| `/acl prefixes` | List registered prefixes |
| `/acl watch <prefix>` | Listen to a foreign prefix (saved) |
| `/acl unwatch <prefix>` | Stop listening (takes effect after `/reload`) |
| `/acl echo` | Show / hide your own echoed messages |
| `/acl keep` | Keep the log across `/reload` on / off |

## Installation

Copy the folder to `World of Warcraft\_forever_\Interface\AddOns\AddonCommLog`.

## Privacy note

With "keep log" enabled, the saved variables file contains message contents and
character names of other players. Don't share it without looking at it first.

## License

MIT – see [LICENSE](LICENSE).
