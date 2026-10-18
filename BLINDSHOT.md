# KIC Blindshot

Blindshot is a multiplayer-only game for 2–5 players in an ordinary WoW PARTY,
bundled with KIC-Games. Each living player secretly chooses a position and
one straight-line shot. Everyone is revealed, then fires in a newly shuffled order.
Players killed before their turn cannot fire. Survivors
move onto a smaller platform for the next round. There are no classes, abilities,
pickups, bots or additional weapons.

## Local UI and gameplay test

After `/reload`, `/kicblindshottest` (alias `/kicblindshot`) opens the real game UI
without a party. The first test has five players: you and four simulated opponents.
They choose random hidden positions/directions and lock automatically; you use
the normal left click/hold movement, right click/hold aiming and Lock In controls. The same phase timings,
hit rules, shrinking platform, elimination and result screen run locally.

- `/kicblindshottest 2` through `5`: start a fresh test with that total player count.
- `/kicblindshottest new`: restart with the last selected player count.
- `/kicblindshottest new 3`: restart with a specific count.
- `/kicblindshottest stop`: exit the test.

Repeating the command without arguments resumes the current test. **New test game**
and **Leave test** are also available in the left panel and result popup; the main
header's Back to Launcher preserves it. Simulated players remain hidden until
reveal and keep playing if you are eliminated. This is a test harness, not a
singleplayer library entry or multiplayer bot feature. It creates no party lobby,
sends no game messages and writes no records, match history or recovery save.
Reload discards it. An existing game, lobby or pending join must be closed first.

## Play with your party

1. Every player installs the updated inner `KIC-Games` addon folder and `/reload`s.
2. Join an ordinary PARTY of 2–5 players. RAID and INSTANCE_CHAT are unsupported.
3. Open `/kicgames`, Multiplayer, then **Host Game** on the Blindshot card.
4. Others click the advertised lobby in the list to join. Everyone clicks **Ready**.
   All ready starts the shared three-second countdown; Not ready cancels it.
5. PREPARE waits for surviving participants' boards before starting the planning
   timer. A missing acknowledgement interrupts the match after 45 seconds.
6. **Left-click / hold** to move immediately or continuously follow the cursor.
   **Right-click / hold** to aim from your token toward the cursor; aiming never
   moves the token. Release retains the latest choice. The full token is clamped
   inside the circular boundary. Click **Lock In** when satisfied. Adjustments
   remain local until locked; the host receives only the final locked choice. You see
   only yourself during PLAN (internally AIM), including when hosting. The right panel shows public
   alive/locked status, not opponents' coordinates or directions.
7. Everyone locking, or the 15-second deadline, freezes the positions/directions.
   The host shuffles the living roster once and sends the complete order and shot
   events. REVEAL displays the order; then living shooters fire 0.6 seconds
   apart. Dead pending turns are skipped without consuming a firing slot.
   ROUND_END lasts two seconds. Colored numbers and player names show the order.
   Unambiguous names omit the realm; duplicate character names retain full identities.
   Long order names wrap into additional rows with independent scrolling.
8. One survivor wins. Zero survivors draws defensively, but a normal sequential
   exchange with this non-self-hitting weapon always leaves at least one survivor.
   A facing duel now has a winner: whichever player fires first. Eliminated
   players remain as spectators until the result.
9. The result popup shows the outcome and your round/elimination totals. The
   lobby remains available for a rematch; everyone must Ready again.

Back to Launcher, closing the window, or reopening through the game card preserves
the match and **does not pause its timers**. Leave Match uses the shared lobby
policy: leaving during a live match interrupts it without awarding a winner.
Leaving while waiting just updates the lobby. The host closing the lobby closes
it for everyone. There is no host transfer.

## Rules and deterministic resolution

The arena uses integer coordinates with initial radius 1000 and a true circular
top-down projection: both axes use exactly the same scale. For 4–5 survivors,
radius is 1000 / 820 / 680 / 560 / 460 for rounds 1–5, then stays 460.
For 3 survivors, multiply that round's base radius by `0.88^(round-1)`, round to
an integer, and clamp to a minimum of 240. For 2 survivors, use `0.68^(round-1)`
and minimum 150: rounds 1–5 are 1000 / 558 / 314 / 176 / 150. Survivor count is
taken at round start; deaths never shrink a volley already in progress.
All players retain hit
radius 36 and minimum center spacing 100. Their full body must fit inside the
platform. Visible token bodies are centered on their simulation coordinates and
drawn with that exact hit radius. Names, order badges, shooter pulses and the
five-pixel halo are decoration; they do not enlarge the weapon hitbox.

As the radius changes, the camera interpolates over 0.45 seconds toward
`basePixelRadius * 1000 / simulationRadius`. The floor retains consistent padding;
positions, physical token bodies, aim arrows and shot endpoints share that scale.
Cursor mapping uses the current interpolated scale and the frame's effective UI
scale. Camera changes never alter simulation positions, hit radii or hit results.
Mouse tracking runs only while a button is held; the arena's temporary update
handler also runs during zoom, and detaches when idle or hidden. Right clicks are
consumed by the arena button. No WoW unit-context action is registered.

At the duel minimum, legal centers occupy a circle of radius 114. This permits a
second center at least 100 units away even when the first request is at the center.
The same deterministic spacing settlement remains in use, including for fallbacks.

The floor uses an existing native circular mask, deterministic beveled masonry,
etched runic rings, a central seal and cyan boundary glow. The former oval
projection and floating side wall are removed. Scenery is cached per
layout/radius; animation reuses its textures. There is no arena texture dependency.

Hidden requests can overlap. At reveal the host settles them to positions at least
100 units apart using a bounded deterministic search, rotating placement priority
by round. Requested positions are used whenever possible; nearby conflicts move
slightly while keeping the chosen aim direction. This happens only after lock-in:
placement validation never discloses whether an opponent occupies a requested point.

The host runs Fisher-Yates once over the living roster, then computes a complete
immutable event plan against the locked positions. Each entry has a shooter and
at most one still-living victim. Apply deaths immediately before considering the
next shooter: someone killed before their turn produces no shot event and adds
no delay. Each living shooter fires at most once. The shared ray test is unchanged:

```text
x*dx + y*dy > 0
(x*dy - y*dx)^2 <= 36^2 * (dx^2 + dy^2)
```

Each ray hits only the nearest living opponent along its path. Distance is
measured to the near surface of the hit circle, with roster order breaking exact
ties. The shot and tracer stop at that surface; players behind it remain alive.
A miss reaches the platform edge. A victim yields one elimination credit only to
the shot that kills them; subsequent rays cannot score that victim again.
Dead bodies do not block later shots.
Positions and directions never change during the sequence. Random order can
change the outcome; network arrival order and rendering order cannot.

Timeout gives players who never locked a deterministic host fallback. Local
unlocked edits are never transmitted and therefore cannot be used by the host.
The fallback position is the player's roster slot
on a ring at 60% of the current radius, aiming toward the center. The same spacing
settlement applies to fallback positions. Last-instant edits must reach the host
before its deadline. Locked actions cannot be changed.

To bound a match in which everyone repeatedly misses, round 12 is the final round.
If multiple players survive it, those survivors draw; previously eliminated
players still lose. The last-survivor and zero-survivor rules take precedence.

## Transport and recovery

The standard framework owns discovery, join approval, Ready, countdown, session
identity, results, leave and stop. `partyOnly` modules cannot create, select, join
or start their game through RAID/INSTANCE_CHAT groups.

Inputs use `SendAction("blindshot_input", ...)`; later-round board readiness uses
`SendAction("blindshot_ready", { id, round })`. Only current participants with a
matching match/round can acknowledge PREPARE. Old sync requests cannot unlock
a new round. Local practice marks simulated boards ready through the same host
phase runner. Public views and private lock
acknowledgements use `SendState("blindshot_view", ...)` and `blindshot_ack`.
There are no whispers, visible party-chat messages, separate communication
libraries or host-election protocols. Player names come from the shared roster;
bounded integer tuples keep state packets compact even with five long names.

The host validates participant identity, living status, match/run, round, action
sequence, deadline, placement, direction and immutable lock state. Clients accept
views only from the current host and reject stale versions or malformed tuples.
Lock retries reuse their sequence. Public PREPARE/AIM views contain no shots or
draft coordinates. All markers other than the local living player's are hidden
during AIM; spectators see no markers until reveal.

Each sequence ID is `matchID:run:round`; event IDs are that sequence ID plus
the event's one-based position. The wire derives these IDs from the validated
session/round, and sends the roster-index order and shooter/victim-mask tuples.
Clients do not shuffle. They validate and present the transmitted plan, using
the host's fractional clock carried as integer milliseconds. REVEAL already
contains the entire plan and its scheduled fire time, so it can start locally
without requiring another phase message. Presentation applies impacts
after 0.28 seconds of each beam and advances living shooters every 0.6 seconds.

Gameplay commits once on the host; rendering derives a fresh player/log copy
from the immutable plan and presentation time, without mutating stats or running
shots again. FIRING and ROUND_END are derived locally from the reveal's clock,
avoiding redundant full-plan broadcasts and a growing addon-message backlog.
The host still advances these phases authoritatively and broadcasts PREPARE,
AIM/REVEAL and end-state snapshots. Surviving boards acknowledge the new PREPARE
before the next planning timer starts. Public sync requests are coalesced into
one shared response rather than one duplicate snapshot per requester. Partial
lock-status changes coalesce for 0.35 seconds; a final reveal is sent immediately.
AIM retains the four-second heartbeat. No per-shot or per-frame network stream
was added. Strictly increasing snapshot
revisions reject duplicates/out-of-order messages. Newer checkpoints cannot
rewind the clock of the same sequence. Obvious transport age is conservatively
bounded using the shared server clock. Network latency can offset clients'
animation timing slightly, while order, hits and final results remain identical.

Saved host state retains the generated order, event plan and committed kills.
Both host and guest save the current presentation clock on logout/reload, so
recovery advances the existing plan instead of generating a new one or crediting
kills twice. Blindshot module protocol is now **5**; version 1/2/3/4 clients/saves are
incompatible and cannot join/resume this version's games. Existing records remain.

The host is trusted. Ordinary PARTY addon messages are recipient-filtered by the
framework; this is cooperative game-state hiding, not cryptographic anti-cheat.

SavedVariables hold the host's authoritative state privately on its client, and
public state plus the local draft on guests. They also preserve lobby identity,
round, revision and join tokens. `/reload` reconstructs the same match and requests
a fresh public view. Host recovery retains existing locks and allows at least
three seconds of remaining AIM time. Missing guest heartbeats disable input after
12 seconds while requesting sync. The shared 90-second host timeout and group
departure policy interrupt the match without inventing a winner.

Completion or an explicit stop/leave clears recovery. WoW flushes SavedVariables
on reload/logout; an abrupt crash can lose changes since the last disk flush.
There is no migration to a different host, and a missing/invalid host save cannot
reconstruct hidden actions from guest public views.

## Records and artwork

Completed results track matches, wins, losses, draws, rounds played while alive,
and eliminations dealt. `entry.stats = { rounds, eliminations }` is validated and
preserved in framework results; score is also the elimination count. Aborted
results carry no gameplay statistics and do not increase completed records.
A bounded counted-result ledger prevents duplicate lifetime increments across
message retries and reloads. Launcher and Results show the real Blindshot record.

Both supplied images are registered and used: the hero on the launcher and left
game panel, and the card in the game library. The installed originals had sizes
1774×887 and 1254×1254. Their exact bytes are preserved under
`KIC-Blindshot-Artwork/Sources/`. The runtime copies were deterministically resized
to WoW-compatible 1024×512 and 256×256 uncompressed RGBA TGAs. No substitute artwork
was generated. `tools/normalize_blindshot_art.py` reproduces this conversion.
Reference previews and test files stay outside the installable addon folder.

Live players use native circular WoW unit portraits when available. Simulated
players and unavailable portraits use masked character crops from the existing
Blindshot card; that illustration is never used as the arena floor. Colored
ground circles, a white local-player ring and `(YOU)` label, dark-backed order
badges, a shooter pulse, three-layer tracer, impact flash and dimmed death cross
provide the gameplay states. Nearby names try alternate positions and stay in
bounds. The right panel fits five compact player entries plus a colored combat
log; each row shows its player index, name, status and revealed firing number.

**Optional artwork:** a dedicated top-down circular stone floor texture (for
example a 1024×1024 WoW-compatible RGBA TGA with a centered circular rim)
would add natural rock detail beyond the current native masonry fallback. A
five-character portrait sheet would give the local demo higher-resolution token
faces. None is required or referenced as a missing runtime dependency.

## Files and verification

Runtime files, in TOC order:

- `Games/Blindshot/Rules.lua`: pure simulation, geometry, collision settlement and outcomes.
- `Games/Blindshot/Protocol.lua`: compact bounded state codec.
- `Games/Blindshot/Session.lua`: host phases, hidden actions, acknowledgements and recovery.
- `Games/Blindshot/UI.lua`: three-column board, input, markers, beams and result popup.
- `Games/Blindshot/Practice.lua`: local-only command, simulated opponents and isolated test lifecycle.
- `Games/Blindshot/Module.lua`: registry, lifecycle, persistence and lifetime statistics.

Earlier integration uses Artwork, Core/TOC, Launcher, UI, Lobby and Results/ResultsUI.
The controls/zoom/endgame update changes only Blindshot's Rules, Protocol, Session,
UI and Module, its tests and documentation; it does not modify shared systems.

Run from the repository root:

```powershell
lua tests/blindshot_rules.lua
lua tests/blindshot_protocol.lua
lua tests/blindshot_sequence.lua
lua tests/blindshot_session.lua
lua tests/blindshot_ui.lua
lua tests/blindshot_practice.lua
lua tests/framework.lua
lua tests/chess_lobby.lua
lua tests/chess_session.lua
lua tests/chess_recovery.lua
lua tests/chess_practice.lua
python tests/artwork.py
python tests/options_assets.py
```

The offline tests exercise 2–5 players, Ready/start, long-name payload sizes,
privacy, shuffled permutations, dead-turn skipping, nearest-target shots, winners,
zero-survivor/round-cap draws, shrink/spacing,
timeouts and fallback, malformed/stale/dead-player actions, a dropped lock retry,
rematches, duplicate/delayed/out-of-order sequence views, same-order client
playback, saved-state validation, host/guest reloads during AIM and FIRING, lobby leave and live-match
interruption. UI checks cover artwork, click/hold movement and aiming, release,
boundary clamping, idle tracking cleanup and cursor mapping at 75%/100%/150% across
radius 1000/558/314/150, animated zoom, full firing-order names, hidden
markers, weapon input, spectator restrictions, texture reuse and
close/reopen. Mock constructor previews of AIM and firing were visually inspected;
they are not WoW screenshots. No live multiplayer validation is claimed.

For live party testing, repeat the play steps with two, three, four and five clients.
Verify that each client sees only its own marker during AIM; lock at different
times and let one round time out. Confirm everyone sees identical numbered order and compact combat log,
0.6-second living-shot intervals, skipped killed players, tracer/impact/death
markers, shrink and final result. In a facing two-player duel, the first shooter
must win. Line up several players: only the nearest living target should die,
and the tracer should stop there. Repeat several rounds with five clients.
Test click/hold movement and aiming, release outside the arena, timeout/resize
cancellation, boundary clamping and mouse input after zoom at different interface scales,
close/reopen during AIM, reload the guest and host separately during AIM and
FIRING (the order and scores must not reset), then Ready for a
rematch in the same lobby. Finally leave a waiting lobby and a running match and
verify that a departure never becomes an automatic win.

See [controls, zoom and endgame validation](design/BLINDSHOT-CONTROLS-ZOOM.md) for
this update's file list, checks and live testing checklist.
