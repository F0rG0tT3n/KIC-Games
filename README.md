# KIC-Games

World of Warcraft Retail party-game launcher and multiplayer framework, version
0.2.0. Intended for waiting for the group to fill and the time between dungeons.
No game is bundled in this first version.

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

## Using a lobby

1. Join a WoW group. Every participant must install KIC-Games.
2. Open the launcher and click **Create lobby**.
3. Other group members open the launcher, click **Refresh**, then click your
   lobby. Members join voluntarily; no visible group-chat message is sent.
4. Once game modules exist, the host selects one from **Games**. Every player
   needs the selected module with exactly the same game protocol version.
5. Everyone clicks **Ready**, including the host. The host clicks **Start game**.
6. **Launcher** returns to the library without ending the match. **Open game**
   reopens the match. Every participant can use **Stop match** to interrupt it.

With the framework alone, players can create and join an empty lobby. Game
selection, ready and start become available once an actual game is installed.
Changing the game resets readiness. Starting a new round also requires everyone
to ready again.

## Dungeon group ready: stop immediately

The framework supplies a **Stop match** button above every game's own UI, and
the same action in the lobby and through `/kicgames stop`. Any participant can
use it. There is no confirmation and the local game stops and closes without
waiting for the host. The interrupt travels on a separate, prioritized addon
queue, so it cannot be trapped behind a large module-state transfer or break
its multipart framing. Remote delivery still depends on WoW's communication
limits. A delayed running snapshot cannot reopen an interrupted match.

The lobby stays available for later; everyone must ready again before a new
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
- API/protocol v2 uses separate game and urgent-control prefixes. All participants
  need the updated framework; v1 clients are not compatible with this version.

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
- `UI.lua`: library, lobby browser, participants and minimap launcher.
- `Libs/`: bundled Ace3 libraries; no separate Ace3 addon installation required.

Run the isolated-client integration checks from the repository root:

```powershell
lua tests/framework.lua
```

The checks load the real bundled libraries and addon files with mocked WoW APIs,
including the UI creation paths. They exercise cross-realm sessions, version
checks, game lifecycle, multipart payloads, throttle retries, stale snapshots,
rejoining, departures, scoped messages, result validation/deduplication,
managed timer cleanup and urgent interruption during a large transfer. Real WoW rendering and actual
server delivery still need an in-game check with at least two clients.

## Third-party libraries

LibStub, CallbackHandler-1.0, ChatThrottleLib, AceComm-3.0 and AceSerializer-3.0
are vendored from [WoWUIDev/Ace3](https://github.com/WoWUIDev/Ace3), retrieved
2026-10-14. The original source headers are preserved. See
`KIC-Games/Libs/LICENSE-Ace3.txt`; LibStub/ChatThrottleLib identify their public
domain licenses in their source. Library files are not modified by the framework.
