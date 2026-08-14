# MiniMythicKeys - support reference

## What it is

MiniMythicKeys does three things around Mythic+ keystones:

1. Auto-replies with your keystone link when someone types "!key" or "!keys" in party, raid, or guild chat.
2. Provides a "Mythic Keys" window (/key or /keys) listing the keystones of your party and guild members.
3. Provides /allkeys to post every party member's keystone to group chat.

## Facts

| Item | Value |
|---|---|
| Addon version | 2.1.4 |
| Author | Verz |
| Interface versions (TOC) | 120100 (Retail only) |
| Saved variables | LibMythicKeystoneDB, MiniMythicKeysDB (both account-wide) |
| Slash commands | /key, /keys (toggle the keystone window); /allkeys (post party keys to chat); /minimythickeys, /minimk, /mmk (open the options panel) |
| Options location | Game Menu -> Options -> AddOns -> MiniMythicKeys (informational text only, no settings) |
| Bundled libraries | LibStub, ChatThrottleLib, LibMythicKeystone-1.0 (with AstralKeys and AngryKeystones plugins), LibKeystone, MiniFramework |
| CurseForge project | minimythickeys (ID 1418981) |

There are no configurable settings. The only saved preference is the keystone window's size.

## Feature 1: chat auto-reply

- Triggers when a chat message is exactly "!key" or "!keys" (case-insensitive, surrounding whitespace ignored). A message like "!key please" does NOT trigger.
- Listens in: party, party leader, raid, raid leader, and guild chat. It does NOT respond in instance chat, say, yell, or whispers.
- Replies to the same channel type (party / raid / guild) with the keystone item link found in your bags (keystone item ID 180653). If you have no keystone it replies "I don't have a key."
- Does not respond while you are in combat.
- Anyone's message triggers the reply, including your own.

## Feature 2: the Mythic Keys window (/key, /keys)

- A movable, resizable window titled "Mythic Keys" with two tabs: Party and Guild.
- Columns: Name (class-colored), Dungeon, Level (e.g. "+12", green), Weekly Best (gold). Rows sort by key level, highest first.
- Players with no key show "No Key" in gray. An empty tab shows "No data yet...".
- Weekly Best is only filled in for your own character (read from your own weekly rewards data); other players' weekly best is not available and stays blank.
- A "Refresh" button in the title bar re-requests keystones from party and guild and refreshes the lists about 2 seconds later.
- Default size 600x480, minimum 570x300, maximum the screen size. The size is remembered between sessions (in MiniMythicKeysDB).
- Lists refresh when the window opens and when you switch tabs.

### Where the data comes from

Keystone data arrives over hidden addon messages. You will see keys from players running any of:

- MiniMythicKeys itself (LibMythicKeystone protocol, addon message prefix "MythicKeystone", and the LibKeystone protocol, prefix "LibKS").
- Other addons using the LibKeystone protocol.
- AstralKeys (guild keys are read from its data when that addon is also installed/loaded).
- AngryKeystones (party keys are read from its broadcasts).

Behavior details:

- On login, your own key is scanned about 1 second in and rescanned every 60 seconds; party and guild key requests go out about 10 seconds after login.
- Party entries are merged by character name with the realm stripped, so the same player is not listed twice.
- Guild keys received over LibKeystone are cached in MiniMythicKeysDB with the current reset week; entries from previous weeks are purged at login. Week boundaries use US/EU/TW reset times.
- Players who have set their key as guild-hidden in a LibKeystone addon are ignored.

## Feature 3: /allkeys

- Posts one chat line per party member that has a key, in the form "Name: +level Dungeon", sorted by key level descending.
- Sends to instance chat when you are in an instance group, otherwise to party chat.
- If you are not in a group it prints "You are not in a group." to your own chat only.
- Members with no known key are skipped.

## Version-gated behavior

- Retail 12.1 only. The LibKeystone protocol component is also retail-only by design.
- The chat auto-reply is disabled while in combat.
- Messages flagged as protected "secret" values by the client are ignored rather than erroring.

## Troubleshooting

- "It doesn't reply to !key": the message must be exactly "!key" or "!keys" and be sent in party, raid, or guild chat. It never replies in instance chat, say, or whispers, and it will not reply while the addon user is in combat.
- "It replied 'I don't have a key.'": correct behavior when no keystone item is in your bags.
- "The window is empty / says 'No data yet...'": other players only appear if they run MiniMythicKeys or another supported addon (LibKeystone-based, AstralKeys, AngryKeystones). Press Refresh and give it a couple of seconds; data arrives over addon messages.
- "Weekly Best is blank for everyone else": expected; weekly best is only available for your own character.
- "A guildmate's key looks outdated": guild keys are cached for the current reset week and only update when new broadcasts arrive; press Refresh. Old-week entries clear at login after reset.
- "Someone shows twice": party entries are merged by name (realm stripped); if you still see duplicates that is a bug worth reporting.
- "/allkeys printed nothing to the group": you must be in a group, and only members with a known key (level above 0) are posted.
- "Where are the settings?": there are none. The options panel only shows usage text; the window remembers its own size automatically.
- "Does it work on Classic?": no, Retail only.
- "Conflicts with AstralKeys or AngryKeystones?": no conflict; MiniMythicKeys reads their data to fill its lists.
