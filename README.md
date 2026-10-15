# KIC-Games

World of Warcraft Retail party-game launcher and multiplayer framework, version
0.10.0. Intended for waiting for the group to fill and the time between dungeons.
Includes **[Tetris](TETRIS.md)** with 13 class icon presets and
**[Bejeweled](BEJEWELED.md)** with animated gem swaps and cascades.
Both singleplayer modules have saved high scores, editable chat sharing and
shared WoW class icon presets from **Options**.

The Neon Arcade Launcher has a shared Home / Singleplayer / Multiplayer / Results /
Options content area. Home shows the featured game and up to three recent games,
ordered by successful launch and saved across reloads. Removed modules are hidden
without deleting their history. The libraries scroll and reflow as the window
width changes; multiplayer keeps its lobby browser and host/join/ready controls.
Results displays each registered game's real saved best and framework history.
See [launcher checkpoint 2](design/CHECKPOINT_2.md) for validation and live tests,
and [replaceable artwork slots](design/MISSING_ASSETS.md) for remaining art.
Bejeweled and Tetris gameplay UI redesigns remain deferred.

Choose your class once in **Options**; it updates both games immediately without
resetting the board or score. Your previous Tetris class selection migrates on
first load. Drag **Resize** at the bottom-right to adjust the window dimensions
and library columns. Use **Options -> Smaller UI / Larger UI** to scale the whole
UI and game board proportionally. Both dimensions and scale persist and clamp to
the screen; **Reset Size** restores the base 1120x700 window and 100% scale when it
fits. Options/Results opened during a game provide **Back to game**, preserving
the active session; solo games stay paused until resumed.

## Install and open

Copy the inner `KIC-Games` folder into
`World of Warcraft/_retail_/Interface/AddOns`, then restart WoW or reload the UI
if the addon was already known to the client. The packaged ZIP contains this
installable folder at its root.

- `/kicgames` or `/kicgame`: open or close the launcher.
- Click the dice minimap button to open the launcher; drag it to reposition.
- `/kicgames refresh`: discover party lobbies.
- `/kicgames leave`: leave your lobby, or close it if you are the host.
- `/kicgames stop` or `/kicgames abort`: interrupt the current match and close the windows immediately.
- `/kicgames results`: view the shared result history.
- `/kictetris`: start Tetris, or reopen your current Tetris game.
- `/kictetris share`: draft your saved best score in chat; press Enter to send.
- `/kicbejeweled`: start Bejeweled, or reopen your active run.
- `/kicbejeweled share`: draft your best gem-matching score in chat.

## Singleplayer and Multiplayer tabs

The launcher has separate **Singleplayer** and **Multiplayer** tabs, each with
its own filtered game library. The last selected tab is remembered.

Singleplayer modules start using **Play**, without a party, lobby discovery or
network traffic. They still get shared results, timer cleanup and **Stop match**.
Finishing a solo game releases its session so you can immediately host or join
a multiplayer lobby. Modules identify their mode when they register. Select
**Tetris** or **Bejeweled** in **Singleplayer**, then click **Play**.

## Using a multiplayer lobby

1. Join a WoW group. Every participant must install KIC-Games.
2. Open **Multiplayer**, choose an installed game, and click **Host game**.
   Any party member can host; party leadership is not required.
3. The **Party lobbies** list shows every discovered host, the selected game,
   current player count/capacity, and whether it is waiting, counting down, or
   running. Click a waiting lobby to join. **Refresh** discovers existing lobbies.
4. Every participant needs the selected module with matching mode and game
   protocol version. The host may choose another multiplayer game in the library.
5. Everyone clicks **Ready**, including the host. As soon as the game's minimum
   player count is met and all joined participants are ready, the framework
   automatically displays **3, 2, 1** and launches the game. No extra host click.
6. **Launcher** returns to the library without ending the match. **Open game**
   reopens the match. Every participant can use **Stop match** to interrupt it.

The multiplayer library is empty until a multiplayer module is installed;
**Host game** requires a selected multiplayer module. Multiple party members can host
independent lobbies, but a client joins only one session at a time.

Withdrawing readiness, a participant departing, someone joining during the
countdown, selecting another game, or **Stop match** cancels the pending start.
Changing membership or the game resets readiness. Selecting the current game
again leaves readiness and countdown unchanged. A cancelled countdown records
no result because a match has not started yet.

The countdown uses a common server timestamp. Remote visibility and actual module
launch still depend on message delivery; a delayed client waits for the host's
authoritative running state. Countdown tokens reject stale cancellation/start
packets. Join-request IDs ensure an earlier roster cannot acknowledge a new join.

## Dungeon group ready: stop immediately

The framework supplies a **Stop match** button above every game's own UI, and
the same action in the lobby and through `/kicgames stop`. Any participant can
use it. There is no confirmation and the local game stops and closes without
waiting for the host. The interrupt travels on a separate, prioritized addon
queue, so it cannot be trapped behind a large module-state transfer or break
its multipart framing. Remote delivery still depends on WoW's communication
limits. A delayed running snapshot cannot reopen an interrupted match.

The multiplayer lobby stays available for later; everyone must ready again before a new
round. A module's framework-managed timers stop automatically. Each module's
`OnStop` callback also releases its own resources.

## Shared results

Game modules finish a normal match using `context:FinishGame(result)`. The
framework validates and distributes the host's result, displays scores/ranks
and explicit win/loss/draw outcomes, and retains the last 20 matches you played
in SavedVariables. Open **Results** or use `/kicgames results`.

Interrupted matches are labeled **Interrupted**, with no scores, rankings or
win/loss outcomes. They never count as a defeat. If the host cannot respond,
the client retains a provisional interruption entry; a host's final result can
reconcile it later. An already-finalized result is not changed by a late stop.
No result window automatically opens when players need to leave for a dungeon.

## Scope and behavior

- At most five game participants per lobby. Games may choose smaller limits.
- Uses the appropriate PARTY, RAID or INSTANCE_CHAT addon channel. Players from
  different realms in the same group are identified by full character/realm name.
- Multiple group members can host independent lobbies; one client joins at most
  one lobby. Party leadership is not required to host a game.
- Only current group members are accepted. Host messages are bound to the selected
  session; guests cannot publish authoritative game state.
- Lobby snapshots have increasing revisions; game messages include a round number
  so delayed packets cannot mutate a later round.
- Lobby advertisements run every 15 seconds. Discovery entries expire after
  60 seconds, joining expires after 20-35 seconds, and a nonresponsive host expires
  after 90-105 seconds. These timers tolerate ordinary addon throttling.
- Leaving or losing a participant ends an active round and keeps the remaining
  players in the lobby. The host closing the lobby closes it for all participants.
- Guests can rejoin a running match after a reload by refreshing and clicking the
  lobby. The game module must provide state restoration. Host reloads do not
  restore a match; there is no host migration in this version.
- Group/channel changes close the affected local session. No combat hooks or
  combat recovery logic are included. Use this addon during downtime.
- Minimap position and bounded result history are persisted; active sessions are not saved.
- API/protocol v3 uses separate game and urgent-control prefixes. All participants
  need the updated framework; v1/v2 clients are not compatible with this version.

## Developing games

See [GAME-API.md](GAME-API.md). Modules can be additional addons with
`## Dependencies: KIC-Games`, or additional files loaded after the framework's
files in its TOC. They register with the public `KICGames:RegisterGame()` API.
Each game is a separately registered module with its own required UI factory,
rules and message handler. Game messages are scoped to its ID, version and
round. The framework supplies the shared lobby, ready check, results, urgent
stopping, managed timers, sender checks and transport.

## Files and verification

- `Core.lua`: public registry, names, module context and lifecycle.
- `Communication.lua`: bounded serialization, sender/channel validation, AceComm.
- `Lobby.lua`: host/guest session state and game-message routing.
- `Results.lua`: normal completion, quick interruption and bounded shared results.
- `Countdown.lua`: all-ready scheduling, shared countdown and cancellation.
- `UI.lua`: library, lobby browser, participants and minimap launcher.
- `Theme.lua`: shared dark cards, typography, custom buttons and movable layered windows.
- `Artwork.lua`, `Media/KICUI/`: centralized decorative runtime textures and native fallbacks.
- `Launcher.lua`: artwork feature panel, sidebar, registry-driven cards and group status.
- `IconPresets.lua`: shared audited textures and class colors for both games.
- `Settings.lua`, `Options.lua`: recent history, class selection, full-page settings, saved scale and responsive window dimensions.
- `ResultsUI.lua`: embedded game selector, saved bests and scrollable framework match history.
- `Games/Tetris/`: independent rules engine, game UI and module lifecycle.
- `Games/Bejeweled/`: independent match-three rules, animations, gem UI and module lifecycle.
- `Libs/`: bundled Ace3 libraries; no separate Ace3 addon installation required.

Run the isolated-client integration checks from the repository root:

```powershell
lua tests/framework.lua
lua tests/tetris.lua
lua tests/bejeweled.lua
python tests/artwork.py
```

The checks load the real bundled libraries and addon files with mocked WoW APIs,
including the UI creation paths. They exercise cross-realm sessions, version
checks, game lifecycle, multipart payloads, throttle retries, stale snapshots,
rejoining, departures, scoped messages, result validation/deduplication,
managed timer cleanup, recent history/reload validation, 24 temporary games per mode,
responsive columns, embedded navigation and saved settings, urgent interruption
during a large transfer, independent
hosts, tabs, singleplayer without networking, the displayed 3-2-1 sequence,
countdown cancellation and join acknowledgment. They also check Tetris launching,
presets, saved records, chat drafts, focus, pauses and quick stopping. Pure engine
checks cover bags, rotation, bounds, holding, drops, line clearing, scoring,
gravity, locking, top-out and randomized board invariants. Bejeweled checks also
cover legal opening boards, invalid swaps, crossing/long matches, falling-gem order,
hint validity, cascade multipliers and no-moves completion. Real WoW rendering and actual
server delivery still need an in-game check with at least two clients.

## Third-party libraries

LibStub, CallbackHandler-1.0, ChatThrottleLib, AceComm-3.0 and AceSerializer-3.0
are vendored from [WoWUIDev/Ace3](https://github.com/WoWUIDev/Ace3), retrieved
2026-10-14. The original source headers are preserved. See
`KIC-Games/Libs/LICENSE-Ace3.txt`; LibStub/ChatThrottleLib identify their public
domain licenses in their source. Library files are not modified by the framework.
