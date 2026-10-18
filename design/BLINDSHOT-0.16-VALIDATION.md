# Blindshot 0.16.0 validation

This change extends the existing Blindshot module. It changes no other game's
rules, shared Options, lobby flow, transport channel, result schema or art files.
The addon version is 0.16.0 and the Blindshot module protocol is 2.

## Changed files

- `KIC-Games/Games/Blindshot/Rules.lua`: host shuffle, immutable shot events with
  sequence/event IDs, sequential piercing deaths, pure timed presentation and
  recovery validation.
- `KIC-Games/Games/Blindshot/Protocol.lua`: compact roster-index order, victim
  masks and integer millisecond clocks; bounded validation and local decoding.
- `KIC-Games/Games/Blindshot/Session.lua`: fractional host clock, local playback,
  stale/duplicate protection, monotonic resynchronization, logout/reload clock save.
- `KIC-Games/Games/Blindshot/UI.lua`: stone platform, portraits/tokens, order
  badges, local/shooter states, arrow/tracer/impact effects and compact player/log UI.
- `KIC-Games/Games/Blindshot/Practice.lua`: same fractional reveal clock in the
  existing isolated local harness.
- `KIC-Games/Games/Blindshot/Module.lua`: protocol version and library description.
- `KIC-Games/Core.lua`, `KIC-Games/KIC-Games.toc`: addon version only.
- `tests/blindshot_rules.lua`, `tests/blindshot_protocol.lua`,
  `tests/blindshot_session.lua`, `tests/blindshot_ui.lua`,
  `tests/blindshot_practice.lua`: updated rules/protocol/UI expectations.
- `tests/blindshot_sequence.lua`: new event timeline, host/client identity,
  skipped turns, malformed plans, duplicate/delayed/stale snapshots and mid-fire
  host/guest recovery coverage.
- `tests/framework.lua`: native texture-mask methods in the offline UI mock.
- `BLINDSHOT.md`, `README.md`, `CHANGELOG.md`, this file: rules and validation docs.

## Automated verification

All 29 runnable Lua suites were exercised successfully, including the six
Blindshot suites, all Chess suites, the shared framework, Bejeweled, KIC Bejeweled,
roguelike regressions, Share Best and Tetris. Fixture/data/helper Lua files are
excluded from that suite count.

The first aggregate run stopped at the existing Chess session assertion
`Intended claim played the move or failed to end match`. Running the unchanged
`tests/chess_session.lua` again passed; it also passed against the pre-change
checkpoint. No Chess source or test was modified. The remaining suites then
passed. This is a retry, not a claim that the aggregate run passed on its first try.

Final Blindshot results:

| Suite | Assertions |
| --- | ---: |
| Practice | 62 |
| Protocol | 84 |
| Rules | 2839 |
| Sequence/recovery | 33 |
| Session/transport | 708 (packet-count dependent) |
| UI | 60 |

`python tests/artwork.py` passed for all 69 runtime TGAs, valid dimensions,
paths/source hashes and exact runtime TOC membership. It also ensures that test
files stay outside the installable addon. `python tests/options_assets.py` passed.
StyLua verified Lua 5.1 syntax and formatting for all modified Blindshot/test Lua.
`git diff --check` passed, with only existing line-ending conversion notices.

Native UI constructor snapshots were rendered outside the addon using the
offline mock at 75%, 100% and 150% window scales, plus reveal/firing examples.
They were visually inspected; they are not live WoW screenshots. Real party
portraits are mocked in tests; the preview shows existing-art fallback tokens.

## Live checks still needed

Use the steps in `BLINDSHOT.md` for ordinary PARTY groups of 2, 3, 4 and 5.
Every participant must install this version and `/reload`. Host Blindshot, join
the listing, Ready, and verify the shared countdown/cancel and rematch controls.
Compare each client's order and combat log, skipped killed turns, piercing kills,
shrink and result. Reload the guest and host separately during AIM and FIRING.
Confirm scores and order do not reset, then test leaving and closing/reopening.

Solo preview: `/kicblindshottest` or `/kicblindshottest 2` through `5`.
It uses the same simulation; `/kicblindshottest new` restarts and `stop` exits.

No new artwork is needed to run the game. A dedicated stone-floor texture and
stone-side/rim art would improve the primitive fallback; a dedicated character
portrait sheet would improve demo token detail. See `BLINDSHOT.md` for suggested
asset formats. No nonexistent asset is referenced, release ZIP created or remote
push performed.

Separate local Git checkpoint repositories preserve the trees at
`D:/WowAddons/backups/KIC-Games-before-Blindshot-overhaul-20261016` (before) and
`D:/WowAddons/backups/KIC-Games-Blindshot-checkpoint-20261016` (completed change).
The main repository's index, branch and existing uncommitted work were left intact.
