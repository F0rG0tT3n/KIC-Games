# Multiplayer browser and lobby redesign — 0.17.0

Multiplayer now has two distinct main-content views. The global sidebar and
header remain in place. In Game continues to use the existing game container.

## Browser

Installed multiplayer games come from `Games:GetGames("multiplayer")`. Chess and
Blindshot appear side by side at the normal window size, using the same premium
GameCard component as Singleplayer. An opt-in layout displays a larger artwork
header, registry title, registered player limits/category, description and Select
Game action. Singleplayer/Home restore their existing card presentation when
the shared card instances are reused. Future modules use registry metadata and
their icon when no dedicated art mapping exists.

Selection shows details and Host Game. Party Lobbies is a separate full-width
section beneath the game selection. Rows show game, host, count/capacity, status
and an explicit Join/Resume/Rejoin action. Missing modules, mismatched versions,
full sessions, already-running games and conflicts with a current session show
the actual restriction and disable Join. Advertisements older than the existing
60-second expiry or belonging to hosts outside the current roster are hidden;
click handlers revalidate availability. Refresh uses existing discovery.

## Lobby and navigation

Host Game creates a session through the existing API and switches to the full
available lobby content area. Join uses that same view for the pending request
and acknowledged session. The game library, selected-game details and party
browser are hidden while in the lobby. The same lobby frame serves host and guest.

The header contains game artwork/title, lobby state, host and Back to Games.
Player cards use the registered capacity: two for Chess, five for Blindshot.
Each contains a join-order index, name, host/local role and Ready/Not ready or
Playing state. Empty cards say Open Slot. The grid reflows with available width;
the player area scrolls at narrower sizes rather than shrinking text or
overlapping the footer. Joined/Ready totals, status, countdown and actions remain
outside that scroll area.

The runtime `multiplayerView` is `browser` or `lobby`; it is not a new save schema.
The existing launcher page remains `multiplayer`, and the game container still
owns the In Game state. Session identity changes route a new host/join request to
the lobby; ordinary updates do not override a player's Back to Games choice.

| Action | Result |
| --- | --- |
| Select a multiplayer card | Updates browser details only |
| Host Game / Join | Opens the shared dedicated lobby |
| Back to Games | Shows browser; retains session and exposes Resume Lobby |
| Resume Lobby / global Multiplayer | Returns to the same joined lobby |
| Browse another game's details while joined | Leaves joined game/readiness unchanged; Host is disabled |
| Leave Lobby | Leaves explicitly through the existing API and returns to browser |
| Open game | Reopens the existing active game container |
| Countdown / launch | Uses existing synchronized start and module lifecycle |

There are no new lobby instances, modal lobby windows, transport messages,
protocol versions or SavedVariables migrations. Ready/Unready, minimum-player
validation, membership/readiness cancellation, the three-second host-authoritative
countdown and duplicate-start defenses are unchanged. The redundant disabled
Auto start button is hidden; starting still requires no additional host click.

## Changed files

- `KIC-Games/UI.lua`: discovery rows/eligibility, session-aware view routing,
  shared lobby player cards, counts and layout.
- `KIC-Games/Launcher.lua`: separate browser/lobby presentation, Back/Resume,
  registry-backed selection and responsive full-width content.
- `KIC-Games/Theme.lua`: opt-in artwork-header layout on the existing GameCard;
  normal presentation is restored when switching back to Home/Singleplayer.
- `KIC-Games/Core.lua`, `KIC-Games/KIC-Games.toc`: addon version 0.17.0 only.
- `tests/multiplayer_navigation.lua`: new end-to-end navigation/discovery suite.
- `tests/lobby_slots.lua`: capacity, card bounds, states, leave and grid checks.
- `tests/blindshot_session.lua`: dedicated host/guest lobby assertions alongside
  existing two/five-player start, gameplay, result and recovery coverage.
- `tests/framework.lua`: replaced old side-by-side-layout expectations with the
  new browser layout; retained registry stress and existing framework tests.
- `README.md`, `CHANGELOG.md`, this file: behavior and validation documentation.

Compared with the pre-change local checkpoint, gameplay modules, communication,
lobby/countdown protocol, artwork, shared Options and other game sources are
byte-for-byte unchanged apart from line-ending normalization in the comparison.

## Validation

Run the Lua suites from the repository root, including:

```powershell
lua tests/multiplayer_navigation.lua
lua tests/lobby_slots.lua
lua tests/chess_lobby.lua
lua tests/chess_session.lua
lua tests/chess_recovery.lua
lua tests/chess_practice.lua
lua tests/chess_ui.lua
lua tests/blindshot_session.lua
lua tests/framework.lua
python tests/artwork.py
python tests/options_assets.py
```

The navigation suite exercises real mocked party transport, host/join, pending
join game identity, Back/Resume/global navigation, unchanged session IDs, module
and version eligibility, full/running/rejoin restrictions, stale/outsider discovery,
Ready/Unready countdown cancellation, Chess launch, explicit Leave, future registry
modules and scale/resize bounds. The existing Blindshot suite covers two/five-player
launch, privacy, multiple rounds, results and recovery; all five lobby slots stay
registry-driven. The framework suites retain minimum-player, countdown membership
change/cancellation, duplicate-message and session lifecycle checks.

Offline constructor previews cover the browser, Back/Resume browser, host/guest
Chess lobby, five-player Blindshot lobby, narrow/wide window sizes, and 75%/150%
Interface Scale. These are mock renders, not live WoW screenshots.

All 31 runnable Lua suites passed, including the existing games and multiplayer
suites. Both Python asset/Options checks passed. StyLua verified Lua 5.1 syntax
and formatting for modified Lua; whitespace checks passed. After the final card
presentation adjustment, the navigation/shared-card and shared framework suites
were rerun. The initial new Blindshot UI assertion was corrected to distinguish
a selected lobby view from a deliberately hidden launcher window: that existing
transport test joins through the API with the guest window closed until launch.

## Manual two-client check

1. Install the current inner `KIC-Games` folder on both clients and `/reload`.
   Join an ordinary PARTY. Open `/kicgames` → Multiplayer on both clients.
2. Confirm Chess and Blindshot appear as large cards with correct art, registered
   player limits and descriptions. Select Chess, then Host Game on client A.
3. Confirm A sees the full-width lobby and two slots, with no library alongside it.
   On B, Refresh the Party Lobbies section and Join A's advertised waiting game.
   Confirm B enters the same lobby with the correct two names/roles.
4. On A, Back to Games; select Blindshot's details. Confirm the Chess session ID,
   members and Ready state are unchanged, Host is disabled, and Resume Lobby or
   global Multiplayer returns to the same Chess lobby.
5. Ready only A: no start. Ready B: both should see 3, 2, 1. Unready during the
   countdown and verify cancellation; repeat with B leaving during the countdown.
   Rejoin and Ready both to launch Chess once. Reopen its lobby and Open game.
6. Leave explicitly and confirm the browser returns. Have B host Blindshot and
   A join. Ready both and confirm Blindshot starts through its existing integration.
   Repeat with five clients to check all five cards and multi-player start.
7. Check at 75%, 100% and 150% Interface Scale, then narrow/widen the window.
   Cards/controls must not overlap; the narrow player area can scroll.
8. Close a hosted lobby and verify its advertisement disappears. Confirm stale
   advertisements expire, unavailable modules/versions disable Join with reasons,
   and gameplay/result records persist normally.

Live WoW multiplayer testing has not been performed here. No remote push or
CurseForge release package is part of this change. A separate local Git checkpoint
repository at `D:/WowAddons/backups/KIC-Games-multiplayer-redesign-20261017`
preserves the before/after source trees without changing the main repository's
index or including generated ZIPs.
