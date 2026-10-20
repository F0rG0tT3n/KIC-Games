# KIC-Games

World of Warcraft Retail party-game launcher and multiplayer framework, version
0.17.0. Intended for waiting for the group to fill and the time between dungeons.
Includes **[Minesweeper](MINESWEEPER.md)** with three classic difficulties, safe
first reveals and saved best times. Open it from Singleplayer or `/kicminesweeper`.
Includes **[Tetris](TETRIS.md)** with Original and class/spec graphics and
**[Bejeweled](BEJEWELED.md)** with animated gem swaps and cascades.
Also includes **[KIC Bejeweled](KIC-BEJEWELED.md)**, an independent game with
Bomb, Lightning and Color Orb combinations and separate saved records.
Every new KIC Bejeweled run opens a **Normal / Roguelike** mode picker.
Normal keeps Bombs, Zaps and Orbs with no timer, Energy, levels or cards.
Roguelike uses the existing Arcane Rush survival rules: scoring replenishes Energy,
full Energy offers a power draft or reshuffle, and powers last for the current run.
The two modes keep separate records. Reopening a run preserves its selected mode.
Tetris and both Bejeweled modules have saved high scores, direct group-chat sharing (or /say when solo) and
shared graphics, audio and interface scale settings from **Options**.

**[Chess](CHESS.md)** is a two-player multiplayer game for an ordinary PARTY group
of 2-5 members. Open Multiplayer, select Chess and click **Host game**. Another
player joins from the shared lobby list; both click **Ready** for the three-second
start. All multiplayer games use this same lobby flow. Chess uses the supplied piece/board artwork,
host-authoritative moves, graphical promotion, draw/resign controls, reload
recovery and separate win/loss/draw records. There are no clocks or AI. Closing
the UI preserves the match; disconnects do not award automatic victories.
For a local UI/gameplay test, `/kicchesstest` opens the board with both sides under
your control. Use `/kicchesstest new` to reset or `/kicchesstest stop` to exit.
The board and local result popup also provide **New test game / Leave test** buttons.
It enforces the Chess rules and leaves multiplayer records unchanged.

**[Blindshot](BLINDSHOT.md)** is a PARTY game for 2–5 players: secretly position
your marker, aim and lock in, then fire in a host-shuffled order. Eliminated
players lose their turn. Each shot stops at the first living opponent. Survivors play
on a shrinking platform until one remains or the round limit draws. Host / Join /
Ready uses the same multiplayer lobby flow. Lobby panels show one rectangular
slot per supported player: a joined name or **Open Slot** (two for Chess, five for
Blindshot). While waiting, the host can click **Announce Lobby** to send the game
name and current joined/capacity count to the lobby's group chat. Only this explicit
host action sends an announcement. The top-down arena uses matching circular bounds and hitboxes.
Left-click or hold to move; right-click or hold to aim. Lock In submits the final
choice; adjustments stay local until then. The circular arena smoothly zooms as it
shrinks, with stronger shrinking for three survivors and duels. Firing order uses
colored player names. Records include completed matches,
wins/draws, rounds played and eliminations. Closing the UI preserves the live timer.
Use `/kicblindshottest` after `/reload` for a party-free local test with simulated
opponents. Add `2`–`5` to select the player count, `new` to restart or `stop` to exit.
Local tests use the real UI/rules and do not affect multiplayer records.

The Neon Arcade Launcher has a shared Home / Singleplayer / Multiplayer / Results /
Options content area. Home shows the featured game and up to three recent games,
ordered by successful launch and saved across reloads. The featured panel always
prioritizes the active session with **Continue Game**. Without an active session,
opening Home chooses uniformly from installed solo and multiplayer games; the
choice stays stable during refreshes, score updates and resizing. An idle party
game opens the Multiplayer Browser without automatically hosting.
Removed modules are hidden
without deleting their history. The libraries scroll and reflow as the window
width changes; multiplayer keeps its lobby browser and host/join/ready controls.
Results displays each registered game's real saved best and framework history.
See [launcher checkpoint 2](design/CHECKPOINT_2.md) for validation and live tests,
and [replaceable artwork slots](design/MISSING_ASSETS.md) for remaining art.
The [shared component checkpoint](design/CHECKPOINT_3.md) adds opt-in premium
frames, stateful neon buttons, statistic/status panels, game cards and section
headings. See the [component API](design/COMPONENTS.md) for module reuse.
Both gameplay screens now use the reference three-column composition: artwork or
keycap controls on the left, a framed square-cell board in the center, and real
statistics/previews on the right. See the [gameplay checkpoint](design/CHECKPOINT_4.md)
for changed files, automated validation, artwork substitutions and live WoW tests.
The gameplay header contains **Back to Launcher**, party status and Close.
Back/Close pause and preserve the run; Resume opens it again. Each game's pause
menu supplies **Resume**, **Restart run** and **Stop match**.
The pause menu's **Stop match** ends the run and returns to the Launcher with
the addon window still open.
The Launcher's top **Stop game** button also ends the active game while keeping
the current Launcher page open.

Options is a full Launcher page with **Graphics**, **Audio** and **Window** tabs.
Graphics offers original colored gems/blocks or distinct class/spec spell sets,
side-by-side class/spec dropdowns, **Follow My Character**, and a read-only live
preview, all visible without scrolling. Original Graphics dims and disables the
profile controls while remembering their values. The class/spec catalog comes
from the Retail client APIs; curated artwork
covers 40 specs, including Devourer. Changes preserve the active board and score.

Audio has independent Arcade/Class-Spec themes, an enable toggle, volume and real
event previews on one page. Both tabs offer the same shared Follow/class/spec
controls; Arcade Sounds disables the audio profile controls.
Both preview headers omit game-selection buttons; the piece icons and sound-event
test buttons remain. Follow My Character occupies its own row below the profile
heading, with the class/spec dropdowns underneath. New settings default to Class
Spells, Follow My Character ON and Class & Specialization audio. Existing
saved choices are retained. Arcade SoundKits support independent volume on current
Retail.
All audible effects use volume-controlled SoundKits on WoW's Master channel.
Verified single-file SoundKit adapters retain their spell effects; the 134 spell
files without verified kits use event-matched arcade sounds until mapped. The
slider applies to both themes, with shared 65% headroom. Off or 0% silences all
addon effects. No global audio CVars change.

Window contains only **Interface Scale**, 75%-150% in 5% steps, plus Reset to 100%.
The resize handle and separate size controls are removed. The base canvas is
1120x700; scale and preferences persist, and small screens use an explicitly
reported fit scale. Legacy saved dimensions remain as unused migration data.
Options/Results opened during a game provide **Back to game**, preserving the
active session; solo games stay paused until resumed. See the
[Options 2.0 checkpoint](design/OPTIONS_2.md) for APIs, limitations and live tests.

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
- `/kictetris share`: send your saved best score directly to group chat (/p, /raid or /i).
- `/bejeweled`: start standard Bejeweled, or reopen your active run.
- `/bejeweled share`: send your standard Bejeweled best score directly to group chat.
- `/kicbejeweled`: start or reopen KIC Bejeweled; add `share` to send its best score directly to group chat. Sharing preserves the current pause state.

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
2. Open **Multiplayer** and click **Host Game** on the game card you want to play.
   Any party member can host; party leadership is not required. Creating the
   session opens a dedicated full-width lobby; the browser is hidden.
3. The right-hand **Party lobbies** sidebar shows every discovered host, the selected game,
   current player count/capacity, and whether it is waiting, counting down, or
   running. Click **Join** to enter the same lobby view. **Refresh** discovers
   existing lobbies. Missing modules, version mismatches, full or active sessions
   show their actual Join restriction. Expired/out-of-party listings are hidden.
4. Every participant needs the selected module with matching mode and game
   protocol version. **Back to Games** preserves the joined session and offers
   **Resume Lobby**. Browsing other game cards does not change that session.
   The global **Multiplayer** item also returns to the current lobby. Use
   **Leave Lobby** explicitly before hosting another game.
5. Everyone clicks **Ready**, including the host. As soon as the game's minimum
   player count is met and all joined participants are ready, the framework
   automatically displays **3, 2, 1** and launches the game. No extra host click.
6. The lobby shows the registered number of player cards (two for Chess, five for
   Blindshot), joined/Ready counts and a shared countdown. **Unready** cancels a
   pending start. **Launcher** preserves the match. **Open game**
   reopens the match. Every participant can use **Stop match** to interrupt it.

The game library and lobby sidebar scroll independently. The library uses two
columns at normal/wide sizes and one readable column in narrow windows. Each
installed multiplayer module supplies a card with its own **Host Game** action;
without a party, cards remain visible with a disabled action and an explanation.
The multiplayer library is empty until a multiplayer module is installed. Multiple party members can host
independent lobbies, but a client joins only one session at a time.

Withdrawing readiness, a participant departing, someone joining during the
countdown, selecting another game, or **Stop match** cancels the pending start.
Changing membership or the game resets readiness. Selecting the current game
again leaves readiness and countdown unchanged. A cancelled countdown records
no result because a match has not started yet.

See [the Multiplayer browser v2 redesign](design/MULTIPLAYER-BROWSER-V2.md) for the page
states, validation and a two-client test checklist.

The countdown uses a common server timestamp. Remote visibility and actual module
launch still depend on message delivery; a delayed client waits for the host's
authoritative running state. Countdown tokens reject stale cancellation/start
packets. Join-request IDs ensure an earlier roster cannot acknowledge a new join.

## Dungeon group ready: stop immediately

Use **Stop game** in the Launcher header, **Stop match** in the lobby or bundled
games' pause menu, or `/kicgames stop`. The Launcher header and pause-menu actions
keep the Launcher open after stopping; the urgent-stop command closes the window.
The gameplay header uses **Back to Launcher** to preserve the session. Any
participant can stop a match immediately, without confirmation or waiting for
the host. The interrupt travels on a separate, prioritized addon
queue, so it cannot be trapped behind a large module-state transfer or break
its multipart framing. Remote delivery still depends on WoW's communication
limits. A delayed running snapshot cannot reopen an interrupted match.

The multiplayer lobby stays available for later; everyone must ready again before a new
round. A module's framework-managed timers stop automatically. Each module's
`OnStop` callback also releases its own resources.

## Shared results

Select any installed game on the Results page, then click **Share Best** in the
header to share its displayed personal best or Chess/Blindshot lifetime record.
KIC Bejeweled includes the displayed Normal/Roguelike mode. This sends one message
to instance, raid or party chat, with `/say` as the solo fallback, without launching
the selected game. Games without a saved best have sharing disabled.

Game modules finish a normal match using `context:FinishGame(result)`. The
framework validates and distributes the host's result, displays scores/ranks
and explicit win/loss/draw outcomes. SavedVariables retains the last 20 matches
across your characters; Results filters that history to the current character.
Switching characters does not erase the other characters' retained matches.
Open **Results** or use `/kicgames results`.

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
lua tests/chess_engine.lua
lua tests/chess_session.lua
lua tests/chess_lobby.lua
lua tests/chess_recovery.lua
lua tests/chess_ui.lua
lua tests/chess_practice.lua
lua tests/blindshot_rules.lua
lua tests/blindshot_protocol.lua
lua tests/blindshot_session.lua
lua tests/blindshot_ui.lua
lua tests/blindshot_practice.lua
lua tests/tetris.lua
lua tests/bejeweled.lua
lua tests/kic_bejeweled.lua
lua tests/bejeweled_hints.lua
lua tests/kic_bejeweled_effects.lua
lua tests/kic_bejeweled_migration.lua
lua tests/kic_bejeweled_modes.lua
lua tests/roguelite_integration.lua
Get-ChildItem tests -Filter roguelite_*.lua | Where-Object Name -ne 'roguelite_integration.lua' | ForEach-Object { lua $_.FullName }
lua tests/share_best.lua
lua tests/results_share_best.lua
python tests/artwork.py
python tests/options_assets.py
```

The focused audit regressions can also run with `lua tests/framework.lua --audit`.
They are included in the full framework suite. See
[the code review report](design/CODE_REVIEW_REPORT.md) for findings and release checks.

The checks load the real bundled libraries and addon files with mocked WoW APIs,
including the UI creation paths. They exercise cross-realm sessions, version
checks, game lifecycle, multipart payloads, throttle retries, stale snapshots,
rejoining, departures, scoped messages, result validation/deduplication,
managed timer cleanup, recent history/reload validation, 24 temporary games per mode,
responsive columns, embedded navigation and saved settings, urgent interruption
during a large transfer, independent
hosts, tabs, singleplayer without networking, the displayed 3-2-1 sequence,
countdown cancellation and join acknowledgment. They also check Tetris launching,
presets, saved records, group-chat sharing, focus, pauses and quick stopping. Pure engine
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
