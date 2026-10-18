# Blindshot top-down gameplay and UI overhaul

Completed October 18, 2026. Shared addon version remains the existing unreleased
0.17.0; Blindshot's module protocol is **4**. All party members need this update.
Versions 1–3 cannot join or restore version 4 matches; lifetime records remain.

## Changes

- `KIC-Games/Games/Blindshot/UI.lua`: replaced the 0.62 vertical projection with
  equal-scale top-down coordinates and the matching cursor inverse. Replaced the
  perspective floor/side wall with a native circular stone disc, beveled masonry,
  central seal, cyan runes and a glowing boundary. Scenery is cached and pooled.
- Player portrait bodies are centered exactly on simulation coordinates and
  sized to the existing physical hit circle. Halos, labels and order badges do
  not alter hit detection. The same 36-unit hit radius and 100-unit spacing apply
  to everyone. Shooter pulses enlarge a decorative halo rather than the body.
- Left-click places/changes position. Drag from the local token or its five-pixel
  grab halo to show live aim; release confirms direction. Preview changes do not
  overwrite the committed direction until release. Lock In commits the chosen
  position/direction. Right-click has no aiming side effect.
- Invalid placement is rejected. Hidden overlapping requests are resolved by the
  existing deterministic host settlement at reveal, without exposing opponents'
  secret positions. The UI explains adjusted placement when needed. Revealed
  overlap is also rejected by state validation.
- Drag previews cancel on lock, timeout, phase/round changes, hide, resize and
  teardown. Mouse-button polling captures release outside the arena. Portraits,
  labels, readable direction arrows, order numbers, shooter glow, beams, impact
  flashes and elimination crosses use existing artwork/native Theme components.
- `Rules.lua`: shot cadence is now 0.6 seconds. Existing circular bounds, ray vs.
  circle contact, nearest living target, non-piercing shot, dead-turn skipping,
  radius schedule, round cap and results remain. Fisher–Yates runs once per round
  on the authority; clients never shuffle their own order.
- `Session.lua`: retained the immutable host-authored event plan, IDs, fractional
  clock and duplicate/stale rejection. Clients derive presentation from that plan;
  rendering never executes shots or increments records. Partial lock-status
  updates coalesce for 0.35 seconds; the final reveal publishes immediately.
- A faster cadence exposed addon-throttle delays in larger parties. Public sync
  replies now coalesce into one shared snapshot instead of N copies. Each later
  PREPARE broadcasts its new round and waits for matching `blindshot_ready`
  acknowledgements from survivors before starting PLAN. Retries use the same
  existing PARTY action transport. Stale/outsider acknowledgements and generic
  sync requests cannot skip the gate. Missing boards interrupt after 45 seconds.
  Local practice marks simulated boards ready and uses the same phase runner.
- `Module.lua`: protocol 4, round-ready dispatch and drag cleanup on stop.
- Six `tests/blindshot_*.lua` suites: geometry, drag/lifecycle controls, module
  compatibility, synchronized 2–5 player scenarios and scheduling regressions.
- `BLINDSHOT.md`, `README.md`, `CHANGELOG.md`: controls, timings and protocol notes.

No Chess, Bejeweled, KIC Bejeweled, Tetris, Home, Options, shared UI, lobby
protocol or shared communication implementation was changed by this task.

## Validation

All six Blindshot suites pass: rules/geometry 3101 assertions, protocol 84,
sequence/recovery/scheduling 41, 2–5 player sessions 971, UI 107 and local practice
66. Coverage includes:

- Circular bounds at every shrink radius and multiple angles; rotation-invariant
  hit/tangent/miss/contact tests and stopping at the first living target.
- Scale-correct placement and drag preview/release, release outside the arena,
  cancellation, lock immutability, hidden markers and spectator restrictions.
- Window sizes 1000×700, 1120×700 and 1500×900 at scales 0.75/1/1.5, with arena
  bounds, token center/body agreement, header/footer clearance and texture reuse.
- Host-generated random permutations, synchronized event IDs/results, immediate
  death effects on later turns, duplicate/delayed views, shrink and multi-round
  2–5 player party flows. Local tests include all supported player counts.
- Per-round readiness identity/round checks, coalesced public sync/lock updates,
  results, rematches, interruption, same-order host/guest reload recovery.

The full 32-suite Lua run passed 31 suites. `chess_session.lua` intermittently
failed its final intended-threefold-claim assertion; an isolated rerun passed.
With `math.randomseed(1)`, the same assertion fails in both this working tree and
the untouched pre-change checkpoint. This existing Chess test failure was
documented and Chess was left unchanged as requested. All other shared/game
regressions, including framework (3711 assertions), Home, browser and lobby slots,
passed. Runtime artwork validation passed for all 69 TGAs. Changed Lua files pass
StyLua verification/checking with Lua 5.1 syntax.

Follow-up on October 18: the Chess failure was traced to the test's fixed
four-second wait. With seed 1, the host had correctly finalized the claim while
the guest's commit arrived just after the assertion. The test now waits up to
the existing 12-second move-synchronization bound for both clients, explicitly
exercises host and guest claims, and verifies both unchanged seven-move boards,
matching claim journals, drawn results and one completion per client. No Chess
runtime change was necessary. The corrected Chess suite passes with seeds 1–5,
and the subsequent complete run passes all 32 Lua suites.

Offline mock-constructor previews were rendered and reviewed for planning,
dragging, reveal/order, firing/impact, shrinking and narrow/wide/scale layouts:
`D:\WowAddons\.tools\kic-blindshot-topdown-preview`.
These are not live WoW screenshots. No live WoW validation was performed.

## Assets and limits

There is no dedicated top-down arena bitmap in the supplied assets. The clean
native circular masonry fallback requires no new file. An optional centered
1024×1024 top-down stone/rune TGA could add painted surface detail later; avoid
perspective and keep the physical boundary centered/circular. Existing hero/card
art and native unit portraits are reused. Token bodies deliberately retain the
original small hit radius rather than visually enlarging the weapon target.

Network latency can offset animation timing. Late clients advance to the current
point in the same authoritative plan; they do not generate another outcome.
Ordinary PARTY state hiding remains cooperative rather than cryptographic.

## Live WoW checklist

1. Update every party member, `/reload`, and run `/kicblindshottest 2` through `5`.
   Place near cardinal/diagonal edges, drag from the token/ring, release inside
   and outside the arena, adjust again, then Lock In. Resize/hide mid-drag.
2. Inspect portraits, order labels, arrows, beams, flashes, corpse markers and
   circular floor alignment at your normal Interface Scale and a narrow window.
3. Host/join through Multiplayer, Ready and start with 2, 3, 4 and 5 real clients.
   Only the local living token should be visible during PLAN. Try overlapping
   secret requests and verify spacing is settled only at reveal.
4. Confirm the same firing order, about 0.6 seconds between living shooters,
   turn skipping and nearest-target stopping. Check shrink and new-round planning
   after synchronization, including an AFK timeout and an eliminated spectator.
5. Hide/reopen and reload host/guest during PLAN and firing; order, results and
   scores must not reset or duplicate. Finish, Ready for rematch, then leave a
   waiting lobby and a live match without awarding an invented winner.

## Local checkpoint

Pre-change and completed snapshots are in the isolated Git repository
`D:\WowAddons\backups\KIC-Games-Blindshot-topdown-20261017`.
The primary repository's branch/index remain intact. No remote push or release
ZIP was created.
