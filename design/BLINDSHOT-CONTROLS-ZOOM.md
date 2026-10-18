# Blindshot controls, auto zoom and endgame validation

Implemented 2026-10-18 against the current working project. Addon version remains
0.17.0; Blindshot module protocol is 5. Everyone in a party must update and reload.
Protocol 4 games/recovery saves cannot resume under the new radius/input policy;
existing lifetime records remain intact.

## Changed files

- `KIC-Games/Games/Blindshot/UI.lua`: immediate click/hold movement and aim, legal
  clamping, temporary mouse/zoom tracking, animated shared camera, colored actual
  names in an adaptive order list, revised instructions and phase hints.
- `KIC-Games/Games/Blindshot/Rules.lua`: survivor-dependent radius, round-start
  survivor reconstruction, cursor clamping and matching state validation.
- `KIC-Games/Games/Blindshot/Protocol.lua`: reconstructs the authoritative radius
  from round plus alive/death-round flags already in the compact public packet.
- `KIC-Games/Games/Blindshot/Session.lua`: rejects unlocked input, removes draft
  streaming, preserves final-choice retry/ack/recovery and resets input/camera.
- `KIC-Games/Games/Blindshot/Module.lua`: protocol 5 and mouse cleanup on stop.
- All six `tests/blindshot_*.lua` suites: controls, camera, names, geometry, codec,
  actual PARTY transport, local test mode and recovery coverage.
- `BLINDSHOT.md`, `README.md`, `CHANGELOG.md` and this validation record.

No Chess, Bejeweled, Tetris, launcher, Options, lobby architecture or artwork was
modified by this update. The project already contained other uncommitted changes;
those were preserved. No remote push or release ZIP was created.

## Behavior and balance

Left mouse press moves immediately; holding follows the cursor. Right mouse
press aims immediately from the token center; holding rotates the aim arrow.
Releasing keeps the latest values. Both are frozen by Lock In, which transmits the
final choice. Mouse input never sends drafts. Only retries of that same locked
packet are permitted. Host-side validation also rejects unlocked submissions.

If the timer expires before a player locks, the host uses the existing deterministic
fallback ring/center-facing aim, then applies normal spacing settlement. It cannot
use local edits that were never transmitted. Choosing a position never reveals
whether an opponent selected the same location; conflicts settle at reveal.

All coordinates, hit radii (36), spacing (100), ray collision and non-piercing
weapon rules remain in simulation units. Radius uses the round's initial survivor
count, so deaths during FIRE cannot shrink the camera or invalidate the current
shot plan. For 4–5 survivors the old radius curve remains unchanged. Three survivors
use the base curve times `0.88^(round-1)`, minimum 240. Two use `0.68^(round-1)`,
minimum 150. Round-one radius remains 1000 for every count. The duel curve reaches
558 / 314 / 176 / 150 in rounds 2–5, then stays at 150. The existing round-12 draw
cap remains.

Minimum duel radius leaves legal token centers up to 114 units from center. Even
a center request leaves room to settle the other token at least 100 units away.
The deterministic bounded placement search was tested with colliding requests
at interior/edge points, every five degrees and both placement priorities.

The rendering scale changes smoothly over 0.45 seconds, keeping the floor's pixel
radius and padding consistent. Tokens grow with physical zoom, including their
visible hit circles. The cursor conversion uses that same current scale. There is
no movement easing/delay. The arena OnUpdate handler is absent while idle; it is
installed only during a held button or camera transition and cleared on hide.

Firing order uses realm-free names when unambiguous and full identities when
character names collide. Internally, networking still uses the full roster. The
header lays names into measured columns/rows and wraps long UTF-8 strings without
ellipsis. Overflow scrolls independently. Token rank badges and current-shooter
highlight remain.

## Automated validation

All 32 runnable Lua suites passed, including all unrelated games/framework/lobby
regressions. The six Blindshot suites passed:

| Suite | Assertions | Coverage |
| --- | ---: | --- |
| Rules | 5751 | circular bounds/rays, non-piercing hits, spacing, stronger shrink, minimum duel legality |
| Protocol | 111 | compact codec, hidden choices, malformed input, current-round casualties and next-round radius |
| Sequence | 41 | authoritative order/events, 0.6-second cadence, dead-turn skipping, duplicates/delay/reload |
| Session | 975 | real PARTY transport, 2–5 players, Host/Join/Ready, lock-only input, retry, timeout, results/recovery/rematch |
| UI | 169 | click/hold/release, clamp, lock/hide/resize cancellation, names, idle updates and camera |
| Practice | 66 | real UI/simulation, 2–5 local players, complete rounds/results, stop/restart and no network/records |

UI checks exercise 75%, 100% and 150% window scales, several window sizes, radii
1000/558/314/150 and interpolation between them. Lua 5.1 syntax and formatting
were checked with StyLua. Runtime artwork/package checks were also run separately.

Offline previews were generated from the actual UI constructor through the existing
mock renderer under `D:/WowAddons/.tools/kic-blindshot-controls-zoom-preview/`.
PLAN, REVEAL, firing, narrow/wide layouts, scales and minimum-radius duel views
were inspected. They are mock previews, not live WoW screenshots.

## Live WoW checks still required

1. `/reload`, then `/kicblindshottest 2`. Single-click and hold each mouse button;
   confirm left follows without delay, right never moves the token, releasing keeps
   the last choice, and aiming does not open WoW context menus. Drag beyond the
   arena and release; verify the token body stays inside and stops following.
2. Adjust repeatedly, Lock In, then try both buttons. Verify position and aim stay
   fixed. Repeat with `/kicblindshottest 3`, `4` and `5`. Let one round expire
   without locking and verify its fallback is identified at reveal.
3. Play missed volleys into later rounds. Check smooth circular zoom, full token
   body bounds and accurate clicking at the tight duel minimum. Change interface
   scale/window size, hide/reopen during zoom, and repeat movement/aiming.
4. With 2–5 updated PARTY clients, Host/Join/Ready through the existing lobby.
   Confirm choices stay hidden, names/colors/order agree everywhere, each beam
   stops at its first living target, dead turns are skipped and the result agrees.
   Test long names and duplicate character names from different realms.
5. Lock at staggered times, let one player time out, and test host/guest reloads
   during PLAN and FIRE. Check no duplicate shots, scores or order reshuffle.
   Hide/reopen, rematch, then leave waiting and running lobbies.
6. `/kicblindshottest stop` must stop local play without PARTY traffic or records.

Native cursor capture, fonts, unit portraits, rendering at actual WoW Interface
Scale, real network latency and subjective duel balance require these live checks.
